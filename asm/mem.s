
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
BLKB2C          = $1003     ; [0] = input byte
                            ; [1] = output lo nibble char
                            ; [2] = output hi nibble char
BLKHC2B         = $1006     ; [0] - the input char
                            ; [1] - output lo nibble char
CMDSTATE        = $1008     ; command state
CMDCHAR         = $1009     ; command char
CMDADDR1H       = $100a     ; command addr 1 hi byte
CMDADDR1L       = $100b     ; command addr 1 lo byte
CMDADDR2H       = $100c     ; command addr 2 hi byte
CMDADDR2L       = $100d     ; command addr 2 lo byte
PCMDINPUT       = $100e     ; parse command char input
CMDID           = $100f     ; command id
ACTIVITYFLAG    = $1010     ; activity flag

    ; Memory map:
    ; $0000 - $7fff = RAM
    ; $8000 - $9fff = 65C22 I/O
    ; $a000 - $ffff = ROM

    ; The image starts at $8000 so it's 32K.

    .org $8000
    .byte $00

    ; code starts at a000
    .org $a000

TXTREADY    .db     "BREADBOARD COMPUTER READY...",$0D,$0A,$00
TXTREADYA   .word   TXTREADY
TXTDGTS     .db     "0123456789ABCDEF"
SNTXERR     .db     "SYNTAX ERROR!",$0d,$0a,$00
SNTXERRA    .word   SNTXERR

; ****************************************
; * main loop (RESET vector)
; ****************************************
RESET:

    ; SETUP
    stz CMDSTATE
    stz CMDID
    stz ACTIVITYFLAG

    lda #%11110111      ; bottom 3 bits are output
                        ; and top 4 bits
    sta VIADDRA         ; these are 0=RS, 1=CE and 2=RW, 3=OUTR (input)
    lda #%11111111      ; port b is all output (initially)
    sta VIADDRB
    lda #%10000010      ; Arduino read/ce disable/instr
    sta VIAPORTA        ; reset port a
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
    stz ACTIVITYFLAG
    lda VIAPORTA
    and #%11011111      ; clear bit 2
    sta VIAPORTA

MAIN_LOOP:

    ; CHECK FOR AVAILABLE BYTE

    jsr SERINBYTE       ; get a character
    lda BLKSERINBYTE    ; load result flag; char available?
    bne ECHOCHAR        ; yes? echo it
    jmp MAIN_LOOP       ; no? loop again

ECHOCHAR:

    lda #%00100000
    sta ACTIVITYFLAG
    lda VIAPORTA
    ora #%00100000      ; set bit 2
    sta VIAPORTA

    lda #%11111111      ; port b is all output
    sta VIADDRB

    ; ECHO THE INPUT CHAR

    lda BLKSERINBYTE+1
    ;sta BLKSEROUTBYTE
    ;jsr SEROUTBYTE

    cmp #$0a
    beq XEQCMD

    lda BLKSERINBYTE+1
    sta PCMDINPUT
    jsr PARSECMD

    lda CMDSTATE
    cmp #$ff
    beq SYNTAX_ERR

    jmp MAIN_LOOP_SETUP

XEQCMD:
    ; EXECUTE COMMAND

    ldx CMDID
    jmp (CMD0A,X)       ; jump to the state routine

RETURN_FROM_COMMAND:

    ; DEBUG: ECHO the command char

    stz CMDSTATE
    stz CMDID

    ; DEBUG
    ;lda CMDCHAR         ; print the command char
    ;sta BLKSEROUTBYTE
    ;jsr SEROUTBYTE
    ;jsr SEROUTCRLF

    ; DEBUG
    ;lda #'$'
    ;sta BLKSEROUTBYTE
    ;jsr SEROUTBYTE
    ;lda CMDADDR1H
    ;sta BLKB2C
    ;jsr B2C
    ;lda BLKB2C+2
    ;sta BLKSEROUTBYTE
    ;jsr SEROUTBYTE
    ;lda BLKB2C+1
    ;sta BLKSEROUTBYTE
    ;jsr SEROUTBYTE
    ;lda CMDADDR1L
    ;sta BLKB2C
    ;jsr B2C
    ;lda BLKB2C+2
    ;sta BLKSEROUTBYTE
    ;jsr SEROUTBYTE
    ;lda BLKB2C+1
    ;sta BLKSEROUTBYTE
    ;jsr SEROUTBYTE
    ;jsr SEROUTCRLF

    jmp MAIN_LOOP_SETUP

SYNTAX_ERR:
    stz CMDSTATE
    stz CMDID

    lda SNTXERRA
    sta ZP1L
    lda SNTXERRA+1
    sta ZP1H
    ldy #$00
SYNTAX_ERR1:
    lda (ZP1L),Y
    beq SYNTAXERR_END
    sta BLKSEROUTBYTE
    jsr SEROUTBYTE
    iny
    jmp SYNTAX_ERR1     ; END output a ready message
SYNTAXERR_END:
    jmp MAIN_LOOP_SETUP

; **************************************************
; * COMMAND TABLE
; **************************************************
CMDID_NULL          = $00
CMDID_OUTBYTE       = $02
CMDID_OUTBYTE16     = $04
CMDID_OUTBYTE256    = $06
CMDID_XEQADDR       = $08
CMDID_SETBYTE       = $0A

CMD0A       .word   CMDNULL             ; [0] null
CMD1A       .word   CMDOUTBYTE          ; [2] out byte 1
CMD2A       .word   CMDOUTBYTE16        ; [4] out byte 16
CMD3A       .word   CMDOUTBYTE256       ; [6] out byte 256
CMD4A       .word   CMDXEQADDR          ; [8] execute address       
CMD5A       .word   CMDSETBYTE          ; [A] set byte

; **************************************************
; * CMDNULL
; **************************************************
CMDNULL:
    jmp RETURN_FROM_COMMAND

; **************************************************
; * CMDOUTADDR
; **************************************************
CMDOUTADDR:
    lda #'$'
    sta BLKSEROUTBYTE
    jsr SEROUTBYTE

    ; OUTPUT ADDRESS

    lda CMDADDR1H
    sta BLKB2C
    jsr B2C
    lda BLKB2C+2
    sta BLKSEROUTBYTE
    jsr SEROUTBYTE
    lda BLKB2C+1
    sta BLKSEROUTBYTE
    jsr SEROUTBYTE
    lda CMDADDR1L
    sta BLKB2C
    jsr B2C
    lda BLKB2C+2
    sta BLKSEROUTBYTE
    jsr SEROUTBYTE
    lda BLKB2C+1
    sta BLKSEROUTBYTE
    jsr SEROUTBYTE

    lda #':'
    sta BLKSEROUTBYTE
    jsr SEROUTBYTE

    lda #' '
    sta BLKSEROUTBYTE
    jsr SEROUTBYTE
    rts

; **************************************************
; * CMDOUTBYTE
; **************************************************
CMDOUTBYTE:
    jsr CMDOUTADDR

    lda CMDADDR1L       ; transfer the address to zero page
    sta ZP1L
    lda CMDADDR1H
    sta ZP1H
    ldy #$0             ; offset 0

    lda (ZP1L),Y        ; load the byte
    sta BLKB2C          ; store input byte
    jsr B2C
    lda BLKB2C+2
    sta BLKSEROUTBYTE
    jsr SEROUTBYTE
    lda BLKB2C+1
    sta BLKSEROUTBYTE
    jsr SEROUTBYTE
    jsr SEROUTCRLF

    jmp RETURN_FROM_COMMAND

; **************************************************
; * CMDOUTBYTE16
; **************************************************
CMDOUTBYTE16:
    jsr CMDOUTADDR

    lda CMDADDR1L       ; transfer the address to zero page
    sta ZP1L
    lda CMDADDR1H
    sta ZP1H
    ldy #$0             ; offset 0

  CMDOUTBYTE16A:  
    lda (ZP1L),Y        ; load the byte
    sta BLKB2C          ; store input byte
    jsr B2C
    lda BLKB2C+2
    sta BLKSEROUTBYTE
    jsr SEROUTBYTE
    lda BLKB2C+1
    sta BLKSEROUTBYTE
    jsr SEROUTBYTE

    lda #' '
    sta BLKSEROUTBYTE
    jsr SEROUTBYTE

    iny
    cpy #$10
    beq CMDOUTBYTE16B
    jmp CMDOUTBYTE16A

CMDOUTBYTE16B:
    jsr SEROUTCRLF
    jmp RETURN_FROM_COMMAND

; **************************************************
; * CMDOUTBYTE256
; **************************************************
CMDOUTBYTE256:
    lda CMDADDR1L
    and #%11110000      ; truncate to 0x0f
    sta CMDADDR1L
    ldx #$10

CMDOUTBYTE256A:
    phx
    jsr CMDOUTADDR      ; output the address

    ; BEGIN OUTPUT 16 BYTES HERE
    lda CMDADDR1L       ; transfer the address to zero page
    sta ZP1L
    lda CMDADDR1H
    sta ZP1H
    ldy #$0             ; offset 0

 CMDOUTBYTE256C:
    lda (ZP1L),Y        ; load the byte
    sta BLKB2C          ; store input byte
    jsr B2C
    lda BLKB2C+2
    sta BLKSEROUTBYTE
    jsr SEROUTBYTE
    lda BLKB2C+1
    sta BLKSEROUTBYTE
    jsr SEROUTBYTE

    lda #' '
    sta BLKSEROUTBYTE
    jsr SEROUTBYTE

    iny
    cpy #$10
    beq CMDOUTBYTE256D
    jmp CMDOUTBYTE256C
    ; END   OUTPUT 16 BYTES HERE

CMDOUTBYTE256D:
    jsr SEROUTCRLF

    lda #$10
    clc
    adc CMDADDR1L
    sta CMDADDR1L       ; store lo byte
    lda CMDADDR1H       ; load hi byte
    adc #$00            ; add 0 plus carry
    sta CMDADDR1H

    plx
    dex
    beq CMDOUTBYTE256B
    jmp CMDOUTBYTE256A

CMDOUTBYTE256B:
    jmp RETURN_FROM_COMMAND

; **************************************************
; * CMDXEQADDR
; **************************************************
CMDXEQADDR:
    lda CMDADDR1L       ; transfer the address to zero page
    sta ZP1L
    lda CMDADDR1H
    sta ZP1H
    jmp (ZP1L)

; **************************************************
; * CMDSETBYTE
; **************************************************
CMDSETBYTE:
    lda CMDADDR1L       ; transfer the address to zero page
    sta ZP1L
    lda CMDADDR1H
    sta ZP1H
    lda CMDADDR2L
    ldy #$00
    sta (ZP1L),Y
    jmp RETURN_FROM_COMMAND

; **************************************************
; * STATE TABLE
; **************************************************
STATE0A     .word   STATE0      ; offset 0
STATE1A     .word   STATE1      ; offset 2
STATE2A     .word   STATE2      ; offset 4
STATE3A     .word   STATE3      ; offset i*2
STATE4A     .word   STATE4
STATE5A     .word   STATE5
STATE6A     .word   STATE6
STATE7A     .word   STATE7
STATE8A     .word   STATE8
STATE9A     .word   STATE9
STATEAA     .word   STATEA
STATEBA     .word   STATEB

; **************************************************
; * PARSECMD
; * PCMDINPUT - input char to parse
; **************************************************
PARSECMD:
    lda CMDSTATE
    asl                 ; left shift 1 to get offset
    tax
    jmp (STATE0A,X)     ; jump to the state routine

PARSECMDERR:
    lda #$ff
    sta CMDSTATE
    stz CMDID
    rts

STATE0:
    ; COMMAND CHAR
    lda PCMDINPUT
    sta CMDCHAR
    inc CMDSTATE        ; state1
    rts

STATE1:
STATE2:
STATE3:
STATE4:
    ; 1st char of address $Xxxx
    ; or 3rd char of address $xxXx
    lda PCMDINPUT
    sta BLKHC2B
    jsr HC2B
    lda BLKHC2B+1
    cmp #$10            ; illegal char, must be hex
    beq PARSECMDERR
    lda CMDSTATE
    cmp #$01
    beq STATE1_3
    cmp #$02
    beq STATE2_4
    cmp #$03
    beq STATE1_3
    cmp #$04
    beq STATE2_4
    jmp PARSECMDERR
    
STATE1_3:
    lda CMDSTATE        ; 1 or 3
    dec                 ; decrement cmdstate, now 0 or 2
    lsr                 ; now 0 or 1
    tax
    lda BLKHC2B+1       ; load the returned byte 0-f
    asl                 ; shift it left four times
    asl                 ; to make it the high byte
    asl
    asl
    sta CMDADDR1H,X     ; store byte in command addr offset x
                        ; offset 0; STATE1 = H
                        ; offset 1; STATE2 = L
    inc CMDSTATE
    rts

STATE2_4:
    lda CMDSTATE        ; 2 or 4
    lsr                 ; div by 2; 1 or 2
    dec                 ; decrement to 0 or 1
    tax                 ; transfer index to x
    lda BLKHC2B+1       ; load the byte
    clc                 ; clear carry flag
    adc CMDADDR1H,X     ; add the byte (in a) to 
                        ; CMDADDR1H or CMDADDR1L (based on x)
    sta CMDADDR1H,X     ; store a back into CMDADDR1H (or CMDADDR1L)

    lda CMDSTATE            ; 2 or 4
    cmp #$04                ; if state is 4
    beq STATE2_4_SETCMDID   ; yes? set cmd id

    inc CMDSTATE
    rts                     ; no? return

STATE2_4_SETCMDID:
    lda CMDCHAR
    cmp #'d'                ; dump
    beq STATE2_4_SETCMDID_D
    cmp #'x'                ; execute
    beq STATE2_4_SETCMDID_X
    cmp #'s'
    beq STATE2_4_SETCMDID_S
    jmp PARSECMDERR         ; niether? error

STATE2_4_SETCMDID_S:
    lda #CMDID_NULL         ; load out byte command
    sta CMDID               ; store in command id
    inc CMDSTATE
    rts                     ; return

STATE2_4_SETCMDID_D:
    lda #CMDID_OUTBYTE      ; load out byte command
    sta CMDID               ; store in command id
    inc CMDSTATE
    rts                     ; return

STATE2_4_SETCMDID_X:
    lda #CMDID_XEQADDR      ; load out byte command
    sta CMDID               ; store in command id
    inc CMDSTATE
    rts                     ; return

STATE5:
    lda PCMDINPUT
    cmp #':'
    beq STATE5_SETCMDID
    jmp PARSECMDERR

STATE5_SETCMDID:
    lda CMDCHAR
    cmp #'d'
    beq STATE5_SETCMDID_D    
    cmp #'s'
    beq STATE5_SETCMDID_S
    jmp PARSECMDERR

STATE5_SETCMDID_S:
    lda #CMDID_NULL
    sta CMDID
    inc CMDSTATE
    rts

STATE5_SETCMDID_D:
    lda #CMDID_OUTBYTE16
    sta CMDID
    inc CMDSTATE
    rts

STATE6:
    lda PCMDINPUT
    cmp #':'
    beq STATE6_SETCMDID
    jmp PARSECMDERR

STATE6_SETCMDID:
    lda CMDCHAR
    cmp #'d'
    beq STATE6_SETCMDID_D
    cmp #'s'
    beq STATE6_SETCMDID_S
    jmp PARSECMDERR

STATE6_SETCMDID_S:
    lda #CMDID_NULL         ; load null command
    sta CMDID
    inc CMDSTATE
    rts

STATE6_SETCMDID_D:
    lda #CMDID_OUTBYTE256
    sta CMDID
    inc CMDSTATE
    rts

PARSECMDERR1:
    jmp PARSECMDERR

STATE7:
STATE8:
STATE9:
STATEA:
    ; 1st char of address $Xxxx
    ; or 3rd char of address $xxXx
    lda PCMDINPUT
    sta BLKHC2B
    jsr HC2B
    lda BLKHC2B+1
    cmp #$10            ; illegal char, must be hex
    beq PARSECMDERR1
    lda CMDSTATE
    cmp #$07
    beq STATE7_9
    cmp #$08
    beq STATE8_A
    cmp #$09
    beq STATE7_9
    cmp #$0a
    beq STATE8_A
    jmp PARSECMDERR

STATE7_9:
    lda CMDSTATE        ; 7 or 9
    sec
    sbc #$07            ; 0 or 2
    lsr                 ; 0 or 1
    tax
    lda BLKHC2B+1       ; load the returned byte 0-f
    asl                 ; shift it left four times
    asl                 ; to make it the high byte
    asl
    asl
    sta CMDADDR2H,X     ; store byte in command addr offset x
                        ; offset 0; STATE1 = H
                        ; offset 1; STATE2 = L
    inc CMDSTATE
    rts

STATE8_A:
    lda CMDSTATE        ; 8 or A
    sec
    sbc #$08            ; 0 or 2
    lsr                 ; 0 or 1
    tax                 ; transfer index to x
    lda BLKHC2B+1       ; load the byte
    clc                 ; clear carry flag
    adc CMDADDR2H,X     ; add the byte (in a) to 
                        ; CMDADDR1H or CMDADDR1L (based on x)
    sta CMDADDR2H,X     ; store a back into CMDADDR1H (or CMDADDR1L)

    lda CMDSTATE            ; 8 or A
    cmp #$0A                ; if state is A
    beq STATE8_A_SETCMDID   ; yes? set cmd id

    inc CMDSTATE
    rts                     ; no? return

STATE8_A_SETCMDID:
    lda CMDCHAR
    cmp #'s'
    beq STATE8_A_SETCMDID_S
    jmp PARSECMDERR

STATE8_A_SETCMDID_S:
    lda #CMDID_SETBYTE
    sta CMDID
    inc CMDSTATE
    rts

STATEB:
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
    lda #%10000101      ; Arduino write/chip enable/data
    ora ACTIVITYFLAG    ; set activity flag as necessary
    sta VIAPORTA
    wai                 ; wait for interrupt

    lda VIAPORTA
    and #%00001000      ; check OUTR1 set
    beq SERINBYTE2      ; no?

    lda VIAPORTB        ; load byte from port b
    sta BLKSERINBYTE+1  ; store the byte
    inc BLKSERINBYTE    ; set flag (> 0)

SERINBYTE2:
    lda #%10000010      ; reset CE
    ora ACTIVITYFLAG
    sta VIAPORTA
    rts

; ****************************************
; * SEROUTBYTE
; ****************************************
SEROUTBYTE:
    ; write a byte to Arduino: SUCCESS
    lda BLKSEROUTBYTE   ; get char
    sta VIAPORTB        ; put a value on port B
    lda #%11000001      ; Arduino read/chip enable/data
    ora ACTIVITYFLAG
    sta VIAPORTA        ; trigger arduino interrupt
    wai                 ; wait for 6502 interrupt
                        ; will be triggered by Arduino
    lda #%10000010      ; reset CE
    ora ACTIVITYFLAG
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
