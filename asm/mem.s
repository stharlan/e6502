
; ************************************************************
; * 6502 ROM Image
; * by Stuart Harlan 2022
; *
; * The intent of this ROM is to establish
; * a bi-directional serial connection
; * using a 65C22 to commuinicate with an
; * Arduino MEGA. Commands can be send to
; * the 6502 and responses will be sent
; * back.
; ************************************************************
; Commands (all numbers in hex, 4 digits):
;   d####       - dump one byte of memory
;   d####:      - dump 16 bytes of memory
;   d####::     - dump 256 bytes of memory
;   sXXXX:YYYY  - store byte (lo byte of YYYY)
;                 into address XXXX
;   x####       - execute code at address
; Future
;   cXXXX:YYYY  - compute checksum of YYYY bytes at address
;                 XXXX
; ************************************************************

; constants
VIAPORTB        = $8000
VIAPORTA        = $8001
VIADDRB         = $8002
VIADDRA         = $8003
VIAT1C_L        = $8004
VIAT1C_H        = $8005
VIAT1L_L        = $8006
VIAT1L_H        = $8007
VIAT2C_L        = $8008
VIAT2C_H        = $8009
VIASR           = $800a
VIAACR          = $800b
VIAPCR          = $800c
VIAIFR          = $800d
VIAIER          = $800e
VIAPORTA_NOH    = $800f

ZP1L            = $0000
ZP1H            = $0001

    ; control blocks

BLKSEROUTBYTE   = $1000     ; [0] = char to output
BLKSERINBYTE    = $1001     ; [0] = (return) 0 if no data; > 0 otherwise
                            ; [1] = (return) the byte read
CMDBUFN         = $1003     ; num of chars in cmd buf
BLKB2C          = $1004     ; [0] = input byte
                            ; [1] = output lo nibble char
                            ; [2] = output hi nibble char
CMDBUFX         = $1007     ; cmd buffer execute = 1
BLKPARSEADDR    = $1008     ; [0] = hi byte; hi nibble
                            ; [1] = hi byte; lo nibble
                            ; [2] = lo byte; hi nibble
                            ; [3] = lo byte; lo nibble
                            ; [4] = addr lo byte
                            ; [5] = addr hi byte
                            ; [6] = err code (0 if success)
BLKHC2B         = $100f     ; [0] - the input char
                            ; [1] - output lo nibble char
BLKPARSECMD     = $1011     ; [0] - command char
                            ; [1] - addr lo/lo byte
                            ; [2] - addr lo/hi byte
                            ; [3] - addr hi/lo byte
                            ; [4] - addr hi/hi byte
                            ; [5] - bytes to report: 0x00 (256), 0x01 (1) or 0x10 (16)
                            ; [6] - error code: 0 = success

CMDBUF          = $1F00     ; $1F00 - $1FFF (256 bytes)

    ; Memory map:
    ; $0000 - $7fff = RAM
    ; $8000 - $9fff = 65C22 I/O
    ; $a000 - $ffff = ROM

    ; The image starts at $8000 so it's 32K.

    .org $8000
    .byte $00

    ; code starts at a000
    .org $a000

TXTREADY    .db     "8BOB ready",$0d,$0a,$00
TXTREADYA   .word   TXTREADY
TXTDGTS     .db     "0123456789ABCDEF"

; ****************************************
; * main loop (RESET vector)
; ****************************************
RESET:

    ; DEBUG TESTING
    lda #'d'
    sta CMDBUF
    lda #'2'
    sta CMDBUF+1
    lda #'A'
    sta CMDBUF+2
    lda #'5'
    sta CMDBUF+3
    lda #'0'
    sta CMDBUF+4
    lda #$00
    sta CMDBUF+5
    lda #$05
    sta CMDBUFN
    jsr PARSECMD

    ; TODO test d2000:
    ; TODO test d2000::

    ; SETUP

    stz CMDBUFN
    stz CMDBUF
    stz CMDBUFX

    lda #%00000111      ; bottom 3 bits are output
    sta VIADDRA         ; these are 0=RS, 1=CE and 2=RW, 3=OUTR (input)
    lda #%11111111      ; port b is all output (initially)
    sta VIADDRB
    lda #%00000010      ; Arduino read/ce disable/instr
    sta VIAPORTA        ; zero out PORTA
    stz VIAPORTB        ; set port b to zero's

    cli                 ; clear interrupt disable flag
                        ; READY

RESET2:
    lda TXTREADYA       ; BEGIN output a ready message
    sta ZP1L
    lda TXTREADYA+1
    sta ZP1H
    ldy #$00

RESET3:
    lda (ZP1L),Y
    beq MAIN_LOOP_SETUP
    sta BLKSEROUTBYTE
    jsr SEROUTBYTE
    iny
    jmp RESET3          ; END output a ready message

MAIN_LOOP_SETUP:
    stz VIADDRB         ; port b input

MAIN_LOOP:

    ; CHECK FOR AVAILABLE BYTE

    jsr SERINBYTE       ; get a character
    lda BLKSERINBYTE    ; load result flag
    beq MAIN_LOOP       ; none available
    lda CMDBUFX         ; check execute flag
                        ; TODO next line is parse and execute
                        ; but, for now, just re-loop
    bne MAIN_LOOP       ; if > 0, parse and execute

    ; STORE IN COMMAND BUFFER

    ldy CMDBUFN         ; get num chars in cmdbuf
    cpy #$ff            ; see if it's 255
    beq MAIN_LOOP       ; nothing to get, main loop

    lda BLKSERINBYTE+1  ; get byte
    cmp #$0a            ; compare to 0x0a
    beq CMDBUFSETX      ; yes? process crlf
    cmp #$0d            ; compare to 0x0d
    beq CMDBUFSETX      ; yes? process crlf
    jmp MAIN_LOOP1      ; no? keep going

CMDBUFSETX:
    inc CMDBUFX         ; set execute flag
    bne MAIN_LOOP       ; if > 0, parse and execute

MAIN_LOOP1:
    lda BLKSERINBYTE+1  ; get byte
    sta CMDBUF,Y        ; store in cmd buf at current pos
    inc CMDBUFN         ; increment command buffer nchars
    lda #$00
    sta CMDBUF,Y        ; store zero at next pos (cmdbuf always ends with zero)

    ; OUTPUT SOME DEBUG INFO

    lda #%11111111      ; port b output
    sta VIADDRB

    lda BLKSERINBYTE+1  ; get char
    sta BLKSEROUTBYTE   ; store in arg0
    jsr SEROUTBYTE      ; echo back
    jsr SEROUTCRLF

    lda BLKSERINBYTE+1  ; convert char to byte
    sta BLKB2C
    jsr B2C
    lda BLKB2C+2
    sta BLKSEROUTBYTE
    jsr SEROUTBYTE
    lda BLKB2C+1
    sta BLKSEROUTBYTE
    jsr SEROUTBYTE
    jsr SEROUTCRLF

    lda CMDBUFN
    sta BLKB2C
    jsr B2C
    lda BLKB2C+2
    sta BLKSEROUTBYTE
    jsr SEROUTBYTE
    lda BLKB2C+1
    sta BLKSEROUTBYTE
    jsr SEROUTBYTE
    jsr SEROUTCRLF
    
    jmp MAIN_LOOP_SETUP

; **************************************************
; * PARSECMD
; * [0] - command char
; * [1] - addr lo/lo byte
; * [2] - addr lo/hi byte
; * [3] - addr hi/lo byte
; * [4] - addr hi/hi byte
; * [5] - bytes to report: 0x00 (256), 0x01 (1) or 0x10 (16)
; * [6] - err code: 0 = success
; **************************************************
PARSECMD:
    stz BLKPARSECMD         ; initialize return values
    stz BLKPARSECMD+1
    stz BLKPARSECMD+2
    stz BLKPARSECMD+3
    stz BLKPARSECMD+4
    lda #$01                ; default is one byte
    sta BLKPARSECMD+5
    stz BLKPARSECMD+6

    lda CMDBUFN             ; check n chars in cmd buf
    beq PARSEERR            ; if none, error

    ldx #$00
    lda CMDBUF,X            ; load first char
    sta BLKPARSECMD         ; the command char

    lda CMDBUFN             ; check n chars in cmd buf
    sec
    sbc #$05
    bmi PARSEERR            ; not enough chars

    inx                     ; load 4 chars to parse an address
    lda CMDBUF,X
    sta BLKPARSEADDR
    inx
    lda CMDBUF,X
    sta BLKPARSEADDR+1
    inx
    lda CMDBUF,X
    sta BLKPARSEADDR+2
    inx
    lda CMDBUF,X
    sta BLKPARSEADDR+3
    jsr PARSEADDR
    lda BLKPARSEADDR+6
    bne PARSEERR            ; parse address error
    lda BLKPARSEADDR+4
    sta BLKPARSECMD+1
    lda BLKPARSEADDR+5
    sta BLKPARSECMD+2

    inx
    lda CMDBUF,X
    cmp #':'
    bne PARSEDONE
    lda #$10                ; 16 bytes
    sta BLKPARSECMD+5

    inx
    lda CMDBUF,X
    cmp #':'
    bne PARSEDONE
    stz BLKPARSECMD+5       ; 256 bytes    

PARSEERR:
    inc BLKPARSECMD+6

PARSEDONE:
    rts

; **************************************************
; * PARSEADDR
; * Parses 4 chars and turns them into a 2 byte
; * address.
; * [0] = hi byte; hi nibble
; * [1] = hi byte; lo nibble
; * [2] = lo byte; hi nibble
; * [3] = lo byte; lo nibble
; * [4] = addr lo byte
; * [5] = addr hi byte
; * [6] = err code (0 if success)
; **************************************************
PARSEADDR:
    stz BLKPARSEADDR+4
    stz BLKPARSEADDR+5
    stz BLKPARSEADDR+6      ; reset error

    ldx #$00

PARSEADDRA:
    lda BLKPARSEADDR,X      ; load char at offset x (0-3)
    sta BLKHC2B
    jsr HC2B                ; call hex char to byte
    lda BLKHC2B+1           ; check result
    cmp #$10
    beq PARSEADDRERR        ; yes? error
    cpx #$00
    bne PARSEADDR1
    asl                     ; shift left 4x
    asl                     ; to high nibble
    asl
    asl
    sta BLKPARSEADDR+5      ; store hi nibble in hi byte
    inx
    jmp PARSEADDRA

PARSEADDR1:
    cpx #$01
    bne PARSEADDR2
    clc
    adc BLKPARSEADDR+5
    sta BLKPARSEADDR+5      ; store hi+lo nibble in hi byte
    inx
    jmp PARSEADDRA

PARSEADDR2:
    cpx #$02
    bne PARSEADDR3
    asl                     ; shift left 4x
    asl                     ; to high nibble
    asl
    asl
    sta BLKPARSEADDR+4      ; store hi nibble in lo byte
    inx
    jmp PARSEADDRA

PARSEADDR3:
    cpx #$03
    bne PARSEADDRERR
    clc
    adc BLKPARSEADDR+4
    sta BLKPARSEADDR+4      ; store hi+lo nibble in lo byte
    jmp PARSEADDRDONE

PARSEADDRERR:
    inc BLKPARSEADDR+6      ; set error

PARSEADDRDONE:
    rts

; **************************************************
; * SEROUTCRLF
; **************************************************
SEROUTCRLF:
    lda #$0d            ; get char
    sta BLKSEROUTBYTE   ; store in arg0
    jsr SEROUTBYTE      ; echo back
    lda #$0a            ; get char
    sta BLKSEROUTBYTE   ; store in arg0
    jsr SEROUTBYTE      ; echo back
    rts

; **************************************************
; * HC2B - hex char to byte
; * BLKHC2B[0] - the input char
; * BLKHC2B[1] - output lo nibble char ($10 is err)
; **************************************************
HC2B:
    lda BLKHC2B
    sec
    sbc #'0'
    bmi HC2BERR         ; < '0', error

    lda #'9'
    sec
    sbc BLKHC2B
    bmi HC2BAFC         ; > '9', try A-F

    ; the char is 0-9
    lda BLKHC2B
    sec
    sbc #'0'            ; a is now 0-9
    sta BLKHC2B+1       ; store the value
    jmp HC2BDONE        ; done

HC2BAFC:
    lda BLKHC2B
    sec
    sbc #'A'
    bmi HC2BERR         ; < 'A', error

    lda #'F'
    sec
    sbc BLKHC2B
    bmi HC2BAFL         ; > 'F', try A-F

    ; the char is A-F
    lda BLKHC2B
    sec
    sbc #$37            ; is now A-F
    sta BLKHC2B+1       ; store the value
    jmp HC2BDONE        ; done

HC2BAFL:
    lda BLKHC2B
    sec
    sbc #'a'
    bmi HC2BERR         ; < 'A', error

    lda #'f'
    sec
    sbc BLKHC2B
    bmi HC2BERR         ; > 'F', try A-F

    ; the char is A-F
    lda BLKHC2B
    sec
    sbc #$57            ; is now A-F
    sta BLKHC2B+1       ; store the value
    jmp HC2BDONE        ; done

HC2BERR:
    lda #$10            ; err > 0x0f (#$10 is error)
    sta BLKHC2B+1       ; store the value

HC2BDONE:
    rts

; **************************************************
; * B2C
; * BLKB2C[0] - the input byte
; * BLKB2C[1] - output lo nibble char
; * BLKB2C[2] - output hi nibble char
; **************************************************
B2C:
    lda BLKB2C      ; get input byte
    lsr             ; shift bits right 4 times
    lsr
    lsr
    lsr
    and #%00001111  ; get lower nibble of a    
    tax             ; lower nibble is offset (0-15)
    lda TXTDGTS,X   ; get char
    sta BLKB2C+2    ; store hi nibble char
    lda BLKB2C
    and #%00001111  ; get lower nibble of a    
    tax             ; put nibble in x (0-15)
    lda TXTDGTS,X   ; get digit from digit table offset x
    sta BLKB2C+1    ; store lo nibble char
    rts

; ****************************************
; * SERINBYTE
; * BLKSERINBYTE[0] - 0 if no data; > 0 otherwise
; * BLKSERINBYTE[1] - the byte of data
; ****************************************
SERINBYTE:

    lda #$00
    sta BLKSERINBYTE
    sta BLKSERINBYTE+1

    ; read a byte from Arduino
    lda #%00000101      ; Arduino write/chip enable/data
    sta VIAPORTA
    wai                 ; wait for interrupt

    lda VIAPORTA
    and #%00001000      ; check OUTR1 set
    beq SERINBYTE2      ; no?

    lda VIAPORTB        ; load byte from port b
    sta BLKSERINBYTE+1  ; store the byte
    inc BLKSERINBYTE    ; set flag (> 0)

SERINBYTE2:
    lda #%00000010      ; reset CE
    sta VIAPORTA
    rts

; ****************************************
; * SEROUTBYTE
; ****************************************
SEROUTBYTE:
    ; write a byte to Arduino: SUCCESS
    lda BLKSEROUTBYTE   ; get char
    sta VIAPORTB        ; put a value on port B
    lda #%00000001      ; Arduino read/chip enable/data
    sta VIAPORTA        ; trigger arduino interrupt
    wai                 ; wait for 6502 interrupt
                        ; will be triggered by Arduino
    lda #%00000010      ; reset CE
    sta VIAPORTA
    rts

ON_NMI:
ON_IRQ:
    rti

    ; NMI, reset and IRQ vectors

    .org $fffa
    .word ON_NMI
    .word RESET
    .word ON_IRQ
