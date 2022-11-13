
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

                        ; SETUP

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
    jsr SERINBYTE       ; get a character
    lda BLKSERINBYTE    ; load result flag
    beq MAIN_LOOP       ; none available

    lda #%11111111      ; port b output
    sta VIADDRB

    lda BLKSERINBYTE+1  ; get char
    sta BLKSEROUTBYTE   ; store in arg0
    jsr SEROUTBYTE      ; echo back
    jsr SEROUTCRLF

    lda BLKSERINBYTE+1  ; get char
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
    ;lda VIAPORTA
    ;and #%00000010      ; bit 1 set?
    ;bne IRQDONE         ; yes? ok - nothing to do
    ;lda #%00000010      ; no? reset (set to 1)
    ;sta VIAPORTA        ; zero out PORTA
;IRQDONE:
    rti

    ; NMI, reset and IRQ vectors

    .org $fffa
    .word ON_NMI
    .word RESET
    .word ON_IRQ
