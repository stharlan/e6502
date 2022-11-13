
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

ARG0            = $1000
ARG1            = $1001

    ; Memory map:
    ; $0000 - $7fff = RAM
    ; $8000 - $9fff = 65C22 I/O
    ; $a000 - $ffff = ROM

    ; The image starts at $8000 so it's 32K.

    .org $8000
    .byte $00

    ; code starts at a000
    .org $a000

; ****************************************
; * main loop (RESET vector)
; ****************************************
RESET:

                        ; SETUP

    lda #%00000011      ; ACR enable latching on PA and PB
    sta VIAACR          ; store value into ACR
    lda #%00000111      ; bottom 3 bits are output
    sta VIADDRA         ; these are 0=RS, 1=CE and 2=RW, 3=OUTR (input)
    lda #%11111111      ; port b is all output (initially)
    sta VIADDRB
    lda #%00000010      ; Arduino read/ce disable/instr
    sta VIAPORTA        ; zero out PORTA
    stz VIAPORTB        ; set port b to zero's
    lda #$ff
    sta VIAIFR          ; clear the IFR

    cli                 ; clear interrupt disable flag
                        ; READY

RESET2:
    lda #'R'
    sta ARG0
    jsr SEROUTBYTE

    lda #'E'
    sta ARG0
    jsr SEROUTBYTE

    lda #'A'
    sta ARG0
    jsr SEROUTBYTE

    lda #'D'
    sta ARG0
    jsr SEROUTBYTE

    lda #'Y'
    sta ARG0
    jsr SEROUTBYTE

INFINITE_LOOP:

    jsr SERINBYTE       ; get a character
    lda ARG0            ; load result flag
    beq INFINITE_LOOP   ; none available

    lda ARG1            ; get char
    sta ARG0            ; store in arg0
    jsr SEROUTBYTE      ; echo back

    jmp INFINITE_LOOP

; ****************************************
; * SERINBYTE
; * ARG0 - 0 if no data; > 0 otherwise
; * ARG1 - the byte of data
; ****************************************
SERINBYTE:

    lda #$00
    sta ARG0
    sta ARG1

    ; read a byte from Arduino
    stz VIADDRB         ; port b all input

    lda #%00000101      ; Arduino write/chip enable/data
    sta VIAPORTA
    wai                 ; wait for interrupt

    lda VIAPORTA
    and #%00001000      ; check OUTR1 set
    beq SERINBYTE2      ; no?

    lda VIAPORTB        ; load byte from port b
    sta ARG1            ; store the byte
    lda #$01            ; indicate data was read
    sta ARG0            ; store the flag

SERINBYTE2:
    lda #%00000010      ; reset CE
    sta VIAPORTA
    lda #$ff
    sta VIAIFR          ; clear the IFR
    rts

; ****************************************
; * SEROUTBYTE
; ****************************************
SEROUTBYTE:
    ; write a byte to Arduino: SUCCESS
    lda #%11111111      ; port b is all output
    sta VIADDRB

    lda ARG0            ; get char
    sta VIAPORTB        ; put a value on port B

    lda #%00000001      ; Arduino read/chip enable/data
    sta VIAPORTA        ; trigger arduino interrupt
    wai                 ; wait for 6502 interrupt
                        ; will be triggered by Arduino

    lda #%00000010      ; reset CE
    sta VIAPORTA
    lda #$ff            ; clear the IFR
    sta VIAIFR          
    rts

ON_NMI:
ON_IRQ:
    lda VIAPORTA
    and #%00000010      ; bit 1 set?
    bne IRQDONE         ; yes? ok - nothing to do
    lda #%00000010      ; no? reset (set to 1)
    sta VIAPORTA        ; zero out PORTA
IRQDONE:
    rti

    ; NMI, reset and IRQ vectors

    .org $fffa
    .word ON_NMI
    .word RESET
    .word ON_IRQ
