
; ****************************************
; * 6502 ROM Image
; * by Stuart Harlan 2022
; *
; * The intent of this ROM is to establish
; * a bi-directional serial connection
; * using a 65C22 to commuinicate with an
; * Arduino MEGA. Commands can be send to
; * the 6502 and responses will be sent
; * back.
; ****************************************

; variables
VIAPORTB		= $8000
VIAPORTA		= $8001
VIADDRB			= $8002
VIADDRA 		= $8003
VIAT1C_L		= $8004
VIAT1C_H		= $8005
VIAT1L_L		= $8006
VIAT1L_H		= $8007
VIAT2C_L		= $8008
VIAT2C_H		= $8009
VIASR			= $800a
VIAACR			= $800b
VIAPCR			= $800c
VIAIFR			= $800d
VIAIER			= $800e
VIAPORTA_NOH	= $800f

VIAIFRCA1		= %00000010
VIAIFRCB1		= %00010000
PRSFLGERR		= %00000001

CTP				= $1000	; char to print
CBUFN			= $1001 ; num chars in cmdbuf
CBUFF			= $1002	; cmd buffer flags
						; bit 0: 1 = unexecuted data in buffer
						; bit 1: 1 = ready to execute
PCS1			= $1003	; parse char temp storage
SOVAL			= $1004 ; the byte value to output to serial
STP				= $1005 ; the LO byte addr location for serial out
PRSFLG			= $1006 ; cmd parse flags
						; bit 0: 1 error; 0 no error
ADDR8L			= $0080	; addr low
ADDR8H			= $0081 ; addr high
CMDBUF			= $1100	; command buffer, 256 bytes $1100 to $11ff

CBFUNXFLG		= %00000001		; unexected data flag
CBFUNXFLGB		= %11111110		; inverse of unexected data flag
CBFXEQFLG		= %00000010		; ready to execute flag
CBFXEQFLGB		= %11111101		; inverse of XEQ flag
LF				= $0a
LONIBBLE		= %00001111
DOLLAR			= '$'

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
; * constants
; ****************************************

TXTRDY:
	db	'e6502 is ready...',$00
TXTSNTE:
	db 	'SYNTAX ERROR!',$00
TXTDGTS:
	db '0123456789ABCDEF'
TXTRDYA		.word TXTRDY
TXTSNTEA	.word TXTSNTE

; ****************************************
; * main loop (RESET vector)
; ****************************************
RESET:

	; for debugging only
	;lda #$64
	;sta CMDBUF
	;lda #$30
	;sta CMDBUF+1
	;sta CMDBUF+2
	;sta CMDBUF+3
	;sta CMDBUF+4
	;lda #$05
	;sta CBUFN
	;lda #%00000011
	;sta CBUFF
	lda #$55
	sta $0900

	stz CTP			; memory initialization
	stz CBUFN
	stz CBUFF
	stz SOVAL

	lda #%10101010	; setup pcr for serial out on a and b
					; pulse output (101) bits 3,2,1
					; negative active edge (0) bit 0
	sta VIAPCR		; store the value in PCR

	lda #%10000010	; enable CA1 interrupts
	sta VIAIER

	lda #$ff		; set all b pins to output
	sta VIADDRB		; this is where the 6522 sends
					; data to the arduino

	stz VIADDRA		; set all a pins to input
					; this is where the arduino
					; sends data to the 6522

	cli				; tell processor to respond to interrupts

	lda TXTRDYA		; output ready msg on serial
	sta ADDR8L		; load the address of the text to ram in 
	lda TXTRDYA+1	; the zero page
	sta ADDR8H		; and call SEROUT
	jsr SEROUT		; to write it to serial

WAIT3:
	lda CBUFF		; check the execute cmdbuf flag
	and #CBFXEQFLG
	beq CONT1		; if not set, continue

	lda CBUFN		; check if data in cmdbuf
	beq CONT1		; if no, continue

	;jsr SOCMDBUF	; serial out cmd buf

	jsr PARSECMD	; parse the cmd buf
	lda PRSFLG
	and PRSFLGERR	; check for parse error
	beq CONT2		; no error, go on

	; output syntax error

	lda TXTSNTEA	; output syntax error msg
	sta ADDR8L
	lda TXTSNTEA+1
	sta ADDR8H
	jsr SEROUT	

CONT2:
	stz CBUFF		; clear all cbuf flags

CONT1:
	jmp WAIT3		; loop forever

; ****************************************
; * parse cmd buf
; ****************************************
PARSECMD:
	stz PRSFLG		; clear parse flags
	ldx #$00		; start at cmdbuf zero
	lda CMDBUF,X	; load character
	cmp #$64		; d = dump memory
	beq CMDDUMP
	jmp PARSEERR

CMDDUMP:
	inx				; increase char pos
	ldy #$00		; first digit
	lda CMDBUF,X	; load next char in buffer
	sta PCS1		; store in PCS1

CMDDUMP1:
	lda TXTDGTS,Y	; get the digit char at index y
	cmp PCS1		; compare digit char to current char
	bne CMDDUMP2	; not equal, next one
					; y contains the position of the char 0-f
					; if this is high nibble, left shift 4 times

	cpx #$01		; are we on digit 1?
	bne ACASE2		; if not digit one, move on
					; digit 1 is high byte
	tya				; transfer y to a (y is 0-f)
	asl
	asl
	asl
	asl				; left shift a four times to make it hi nibble
	sta ADDR8H		; store in addr high
	inx				; next buffer char
	lda CMDBUF,X	; get char
	sta PCS1		; store the current char
	ldy #$00		; first digit
	jmp CMDDUMP1

CMDDUMP2:
	iny				; increment digit y
	cpy #$10		; compare to 0x10 (digits 0x00 through 0x0f)
	beq PARSEERR	; if past 0x0f, abort parse
	jmp CMDDUMP1	; go back and compare again

ACASE2:
	cpx #$02
	bne ACASE3

	tya
	clc				; clear carry flag
	adc ADDR8H		; add low nibble to ADDRHI
	sta ADDR8H		; store back in ADDRHI
	inx				; next buffer char
	lda CMDBUF,X	; get char
	sta PCS1		; store the current char
	ldy #$00		; first digit
	jmp CMDDUMP1

ACASE3:
	cpx #$03
	bne ACASE4

	tya
	asl
	asl
	asl
	asl
	sta ADDR8L
	inx
	lda CMDBUF,X	; get char
	sta PCS1		; store the current char
	ldy #$00
	jmp CMDDUMP1

ACASE4:
	cpx #$04
	bne PARSEERR	; greater than 4? error

	tya
	clc				; clear carry flag
	adc ADDR8L
	sta ADDR8L
					
	; for debugging
	; output low byte and hi byte
	lda ADDR8L
	sta SOVAL
	jsr SOBYTE	

	lda ADDR8H
	sta SOVAL
	jsr SOBYTE	

	ldy #$00		; address is in ADDRHI ADDRLO
	lda ($80),Y		; load value from address at 0080 (ADDR8H/ADDR8L)
					; with no offset
	sta SOVAL
	jsr SOBYTE
	
	jmp PARSEDONE

PARSEERR:
	inc PRSFLG		; an error has occurred

PARSEDONE:
	stz CBUFN		; reset cmd buffer
	rts

; ****************************************
; * serial out byte
; * byte is in SOVAL
; ****************************************
SOBYTE:
	lda #DOLLAR		; output a dollar sign
	sta CTP
	jsr SEROUTCHAR

	; output the high nibble

	lda SOVAL
	lsr				; shift bits right 4 times
	lsr
	lsr
	lsr
	and #LONIBBLE	; get lower nibble of a	
	tax				; lower nibble is offset (0-15)
	lda TXTDGTS,X	; get char
	sta CTP
	jsr SEROUTCHAR	; output next char

	; output the lo nibble

	lda SOVAL
	and #LONIBBLE	; get lower nibble of a	
	tax				; put nibble in x (0-15)
	lda TXTDGTS,X	; get digit from digit table offset x
	sta CTP
	jsr SEROUTCHAR	; output the char

	lda #LF
	sta CTP
	jsr SEROUTCHAR	; output a linefeed

	rts

; ****************************************
; * serial out CMDBUF
; ****************************************
SOCMDBUF:
	ldx #$00		; start at char 0
SOCMDBUF1:
	lda CBUFN		; check chars in cmdbuf
	beq SOCMDBUF2	; if none, quit

	lda CMDBUF,X	; load next char into a
	sta CTP			; store into CTP memory
	jsr SEROUTCHAR	; send to serial out
	dec CBUFN		; decrement num chars in cmdbuf
	inx				; increment char position
	jmp SOCMDBUF1	; loop again
SOCMDBUF2:
	lda #LF
	sta CTP
	jsr SEROUTCHAR	; output a linefeed
	rts

; ****************************************
; * serial out
; * location of text is ADDR8L/ADDR8H
; ****************************************
SEROUT:
	ldy #$00		; start at char 0
SEROUT1:
	lda (ADDR8L),Y	; load next char into a
	beq SEROUT2		; if a = 0 (end of string) -> done
	sta CTP			; store into CTP memory
	jsr SEROUTCHAR	; send to serial out
	iny				; next char
	jmp SEROUT1		; loop again
SEROUT2:
	lda #LF
	sta CTP
	jsr SEROUTCHAR	; output a linefeed
	rts

; ****************************************
; * serial out char
; ****************************************
SEROUTCHAR:
	lda CTP
	sta VIAPORTB	; store in b

WAITIFR:			; wait for data taken signal on INT CB1
	lda VIAIFR		; check IFR bit 1 to go high
	and #VIAIFRCB1	; zf set if a = 0 (not bit 4)
					; if bit 1 set a will be > 0
					; if bit 1 not set (0) a = 0 and loop again
	beq WAITIFR		; branch if zf set (a = 0)
	lda #$ff
	sta VIAIFR		; clear all IFR flags
	rts

; ****************************************
; * irq handler
; ****************************************
ON_NMI:
ON_IRQ:
	pha				; push A to stack
	phx				; push X to stack

	lda VIAIFR		; check if CA1 INT has been hit
	and #VIAIFRCA1	; if so, bit 1 will be set and result will be 1
	beq IRQDONE		; if not set, and will be zero, go to done

	lda VIAPORTA	; ARDUINO has a char ready to transmit
					; load it from VIA into a
	pha				; push it to the stack

	cmp #LF			; compare to 0x0a
	beq SETEXQ		; if so, go to set the execute flag

	lda CBUFN		; check chars in cmd buffer
	cmp #$ff
	beq CBUFFULL	; if 255 chars
					; ignore the input and return

	ldx CBUFN		; get the current position (< 256)
	pla				; get the char from the stack
	sta CMDBUF,X	; store the char in the cmd buf
	inc CBUFN		; increment num chars in cmd buf

	lda CBUFF		; set the un-executed data bit in cmd buffer flags
	ora #CBFUNXFLG
	sta CBUFF

	jmp IRQDONE

SETEXQ:
	pla				; get the loaded char off the stack
					; and discard
	lda CBUFN		; check chars in cmd buffer
	beq IRQDONE		; if no chars, done

	lda CBUFF		; set the execute bit in cmd buffer flags
	ora #CBFXEQFLG
	sta CBUFF

	jmp IRQDONE

CBUFFULL:
	pla

IRQDONE:
	plx				; retrieve X from stack
	pla				; retrieve A from stack
	rti

	; NMI, reset and IRQ vectors

	.org $fffa
	.word ON_NMI
	.word RESET
	.word ON_IRQ
