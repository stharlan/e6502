
    ; Toolchain:
    ; Compile:
    ;   vasm6502_oldstyle.exe -Fbin -dotdir -c02 -o prog1.bin prog1.s
    ; Deploy:
    ;   sercon.py
    ;     u0800
    ;     local upload proj1.bin 0000
    ;     x0800
    ;
    ; u0800 - upload 256 bytes to memory address $0800
    ; local upload proj1.bin 0000 - send 256 bytes
    ;   from file 'proj1.bin' starting at offset 0000
    ;   in file
    ; x0800 - begin executing code at memory address $0800
    ;

    .org $0800

START:
    lda #'H'
    sta ARG0
    jsr SEROUTCHAR

    lda #'I'
    sta ARG0
    jsr SEROUTCHAR

    lda #'!'
    sta ARG0
    jsr SEROUTCHAR

    lda #$0d
    sta ARG0
    jsr SEROUTCHAR

    lda #$0a
    sta ARG0
    jsr SEROUTCHAR

    jmp $A069

; ****************************************
; * serial out char
; * ARG0 - char to serial out is in ARG0
; ****************************************
SEROUTCHAR:
	lda ARG0
	sta $8000   	; store in b

WAITIFR:			; wait for data taken signal on INT CB1
	lda $800d		; check IFR bit 1 to go high
	and #%00010000	; zf set if a = 0 (not bit 4)
					; if bit 1 set a will be > 0
					; if bit 1 not set (0) a = 0 and loop again
	beq WAITIFR		; branch if zf set (a = 0)
	lda #$ff
	sta $800d		; clear all IFR flags
	rts

ARG0:
    .byte   00

   	.org $08ff      ; round out the file to 256 bytes
    .byte 00        ; just to make things easy
