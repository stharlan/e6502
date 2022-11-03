
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

ADDR8LZ			= $0080	; addr low zero page
ADDR8HZ			= $0081 ; addr high zero page
ADDR8LB			= $0082 ; addr low for print buffer (SEROUT)
ADDR8HB			= $0083 ; addr high for print buffer (SEROUT)

CBUFN			= $1000 ; num chars in cmdbuf
CBUFF			= $1001	; cmd buffer flags
						; bit 0: 1 = unexecuted data in buffer
						; bit 1: 1 = ready to execute
PCS1			= $1002	; parse char temp storage
STP				= $1004 ; the LO byte addr location for serial out
OUTBUFP			= $1006 ; output buffer position

ARG0			= $1010
ARG1			= $1011
ARG2			= $1012
ARG3			= $1013
ARG4			= $1014
ARG5			= $1015
ARG6			= $1016
ARG7			= $1017
ARG8			= $1018
ARG9			= $1019
ARGA			= $101A
ARGB			= $101B
ARGC			= $101C
ARGD			= $101D
ARGE			= $101E
RERR			= $101F

CMDBUF			= $1100	; command buffer, 256 bytes $1100 to $11ff
OUTBUF			= $1200 ; output buffer, 256 bytes $1200 to $12ff
OUTBUFLB		= $00
OUTBUFHB		= $12

CBFUNXFLG		= %00000001		; unexected data flag
CBFUNXFLGB		= %11111110		; inverse of unexected data flag
CBFXEQFLG		= %00000010		; ready to execute flag
CBFXEQFLGB		= %11111101		; inverse of XEQ flag
CR				= $0d
LF				= $0a
LONIBBLE		= %00001111
DOLLAR			= '$'
COLON			= ':'
SPACE			= ' '
XCAP			= 'X'

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

	lda #$55
	sta $0900

	stz CBUFN		; num of chars in cmd buffer
	stz CMDBUF		; first char is zero
	stz CBUFF		; command buffer flags
	stz OUTBUF		; OUTput BUFfer
	stz OUTBUFP		; OUTput BUFfer Position
	stz RERR		; clear error

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
	sta ARG0		; lobyte 
	lda TXTRDYA+1	; the zero page
	sta ARG1		; hibyte
	jsr SEROUT		; to write it to serial	

WAIT3:
	lda CBUFF		; check the execute cmdbuf flag
	and #CBFXEQFLG
	beq CONT1		; if not set, continue

	lda CBUFN		; check if data in cmdbuf
	beq CONT1		; if no, continue

	jsr PARSECMD	; parse the cmd buf
	lda RERR
	beq CONT2		; no error, go on

	; output syntax error

	lda TXTSNTEA	; output syntax error msg
	sta ARG0		; lobyte
	lda TXTSNTEA+1
	sta ARG1		; hibyte
	jsr SEROUT	

CONT2:
	stz CBUFF		; clear all cbuf flags

CONT1:
	jmp WAIT3		; loop forever

; ****************************************
; * parse cmd buf - no args
; * uses CMDBUF and doesn't return anything
; ****************************************
PARSECMD:
	stz RERR		; clear error
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

PRSNEXTCHAR:
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
	sta ADDR8HZ		; store in addr high
	inx				; next buffer char
	lda CMDBUF,X	; get char
	sta PCS1		; store the current char
	ldy #$00		; first digit
	jmp PRSNEXTCHAR

CMDDUMP2:
	iny				; increment digit y
	cpy #$10		; compare to 0x10 (digits 0x00 through 0x0f)
	beq PARSEERR	; if past 0x0f, abort parse
	jmp PRSNEXTCHAR	; go back and compare again

ACASE2:
	cpx #$02
	bne ACASE3

	tya
	clc				; clear carry flag
	adc ADDR8HZ		; add low nibble to ADDRHI
	sta ADDR8HZ		; store back in ADDRHI
	inx				; next buffer char
	lda CMDBUF,X	; get char
	sta PCS1		; store the current char
	ldy #$00		; first digit
	jmp PRSNEXTCHAR

ACASE3:
	cpx #$03
	bne ACASE4

	tya
	asl
	asl
	asl
	asl
	sta ADDR8LZ
	inx
	lda CMDBUF,X	; get char
	sta PCS1		; store the current char
	ldy #$00
	jmp PRSNEXTCHAR

ACASE4:
	cpx #$04
	bne PARSEERR	; greater than 4? error

	tya
	clc				; clear carry flag
	adc ADDR8LZ		; add lo byte to hi byte
	sta ADDR8LZ		; store in ADDR8LZ, used by lda below
	sta ARG1		; also store in ARG1 so we can print the address
					; used by SOBYTEADDR

	lda ADDR8HZ		; used by lda below
	sta ARG0		; also store in ARG0 so we can print the address
					; used by SOBYTEADDR

	; get the value at that address and
	; store in ARG2? so we can output

	ldy #$00		; address is in ADDRHI ADDRLO
	lda (ADDR8LZ),Y	; load value from address at 0080 (ADDR8HZ/ADDR8LZ)
					; with no offset
	sta ARG2		; byte to print

	stz ARG3		; zero out 16 byte flag 
	inx				; look at the next buffer char
					; should be char 5 if we got this far
	lda CMDBUF,X	; get char
	cmp #COLON		; is it a colon
	bne	PRSPRNTRDY	; no? print

	inc ARG3		; set flag to print 16 bytes

PRSPRNTRDY:
	; addr8l and addr8h are already populated
	; so just call SOBYTEADDR to output
	jsr SOBYTEADDR	; print byte with addr
	jmp PARSEDONE	; parse done

PARSEERR:
	inc RERR

PARSEDONE:
	stz CBUFN		; reset cmd buffer
	stz CMDBUF		; first char is zero
	rts

; ****************************************
; * reset output buffer
; * no args, no returns
; ****************************************
RESETOUTB:
	stz OUTBUFP
	stz OUTBUF
	rts

; ****************************************
; * add byte to output buffer 
; * ARG0 the byte to add to the buffer
; ****************************************
ADDOBCHAR:
	lda #$ff
	cmp OUTBUFP		; output buffer should only hold
					; 254 characters because the last
					; should be a null byte (00)
	beq ADDOBCHAR1	; so, if the current position is 0xff
					; ignore this request and return

	lda ARG0		; load the character from memory
	ldx OUTBUFP		; load the next position (0x00-0xfe)
	sta OUTBUF,X	; store the char in buffer
	inc OUTBUFP		; increment position
	ldx OUTBUFP		; load incremented back in x
	lda #$00
	sta OUTBUF,X	; store null byte in next pos
					; this will ensure it always ends
					; with a null byte

ADDOBCHAR1:
	rts

; ****************************************
; * SOBYTEADDR - ads address
; * Output in the format:
; *   $XXXX: XX
; * ARG0 - address high byte
; *      - put in ARG4 so ARG0 can be used
; * ARG1 - address lo byte
; * ARG2 - byte at address
; * ARG3 - show 16 bytes?
; ****************************************
SOBYTEADDR:
	lda ARG0
	sta ARG4
	lda ARG1
	sta ARG5
	lda ARG2
	sta ARG6

	lda #DOLLAR
	sta ARG0
	jsr ADDOBCHAR	; add dollar sign

	; address high
	lda ARG4		; convert high byte address to chars
	sta ARG0
	jsr BYTE2CHAR
	lda ARG1
	sta ARG0
	jsr ADDOBCHAR	; add high nibble
	lda ARG2
	sta ARG0
	jsr ADDOBCHAR	; add lo nibble

	; address low
	lda ARG5		; convert lo byte address to chars
	sta ARG0
	jsr BYTE2CHAR
	lda ARG1
	sta ARG0
	jsr ADDOBCHAR	; add high nibble
	lda ARG2
	sta ARG0
	jsr ADDOBCHAR	; add lo nibble

	lda #COLON
	sta ARG0
	jsr ADDOBCHAR	; add colon

	lda #SPACE
	sta ARG0
	jsr ADDOBCHAR	; add space

	lda ARG6		; convert byte at address to chars
	sta ARG0
	jsr BYTE2CHAR
	lda ARG1
	sta ARG0
	jsr ADDOBCHAR	; add high nibble
	lda ARG2
	sta ARG0
	jsr ADDOBCHAR	; add lo nibble

	cmp ARG3
	beq SBAPRINT	; if no 16 byte flag, just print

	; add 15 more bytes to print buffer
	
	lda ARG4		; store high byte in zero page
	sta ADDR8HB
	lda ARG5		; store low byte in zero page
	sta ADDR8LB
	
	lda #SPACE
	sta ARG0
	jsr ADDOBCHAR	; add space

	ldy #$01		; start with offset 1
SBANEXTB:
	lda (ADDR8LB),Y	; load the character at offset y
	phy				; store y
	sta ARG0
	jsr BYTE2CHAR
	lda ARG1
	sta ARG0
	jsr ADDOBCHAR	; add high nibble
	lda ARG2
	sta ARG0
	jsr ADDOBCHAR	; add lo nibble

	lda #SPACE
	sta ARG0
	jsr ADDOBCHAR	; add space

	ply				; get y back
	iny
	cpy #$08		; if 8, add two spaces
	bne SBANEXTB1

	lda #SPACE
	sta ARG0
	jsr ADDOBCHAR	; add another space

SBANEXTB1:
	cpy #$10
	beq SBAPRINT	; done, go to print
	jmp SBANEXTB

SBAPRINT:
	; print the buffer
	lda #OUTBUFLB	; output OUTBUF low byte
	sta ARG0
	lda #OUTBUFHB	; output OUTBUF high byte
	sta ARG1
	jsr SEROUT

	jsr RESETOUTB	; reset output buffer

	rts

; ****************************************
; * BYTE 2 CHAR
; * ARG0 - the byte to convert
; * ARG1 - the high nibble char to return
; * ARG2 - the low nibble char to return
; ****************************************
BYTE2CHAR:
	; output the high nibble

	lda ARG0
	lsr				; shift bits right 4 times
	lsr
	lsr
	lsr
	and #LONIBBLE	; get lower nibble of a	
	tax				; lower nibble is offset (0-15)
	lda TXTDGTS,X	; get char
	sta ARG1

	; output the lo nibble

	lda ARG0
	and #LONIBBLE	; get lower nibble of a	
	tax				; put nibble in x (0-15)
	lda TXTDGTS,X	; get digit from digit table offset x
	sta ARG2

	rts

; ****************************************
; * serial out byte
; * ARG0 - byte (formerly SOVAL)
; ****************************************
SOBYTE:
	lda ARG0
	pha				; push ARG0 to stack

	lda #DOLLAR		; output a dollar sign
	sta ARG0
	jsr SEROUTCHAR

	pla
	sta ARG0
	jsr BYTE2CHAR

	; output the high nibble
	lda ARG1
	sta ARG0
	jsr SEROUTCHAR	; output next char

	; output the lo nibble
	lda ARG2
	sta ARG0
	jsr SEROUTCHAR	; output the char

	lda #LF
	sta ARG0
	jsr SEROUTCHAR	; output a linefeed

	pla
	sta ARG0
	rts

; ****************************************
; * serial out CMDBUF
; * no args; uses CMDBUF and CMDBUFN
; ****************************************
SOCMDBUF:
	ldx #$00		; start at char 0
SOCMDBUF1:
	lda CBUFN		; check chars in cmdbuf
	beq SOCMDBUF2	; if none, quit

	lda CMDBUF,X	; load next char into a
	sta ARG0		; store into ARG0 memory
	jsr SEROUTCHAR	; send to serial out
	dec CBUFN		; decrement num chars in cmdbuf
	inx				; increment char position
	jmp SOCMDBUF1	; loop again
SOCMDBUF2:
	lda #LF
	sta ARG0
	jsr SEROUTCHAR	; output a linefeed

	rts

; ****************************************
; * serial out
; * location of text is ADDR8LB/ADDR8HB
; * ARG0 - lo byte of addr
; * ARG1 - hi byte of addr
; ****************************************
SEROUT:
	lda ARG0
	sta ADDR8LB
	lda ARG1
	sta ADDR8HB

	ldy #$00		; start at char 0
SEROUT1:
	lda (ADDR8LB),Y	; load next char into a
	beq SEROUT2		; if a = 0 (end of string) -> done
	sta ARG0		; store into ARG0 memory
	jsr SEROUTCHAR	; send to serial out
	iny				; next char
	jmp SEROUT1		; loop again
SEROUT2:
	lda #CR
	sta ARG0
	jsr SEROUTCHAR
	lda #LF
	sta ARG0
	jsr SEROUTCHAR

	rts

; ****************************************
; * serial out char
; * ARG0 - char to serial out is in ARG0
; ****************************************
SEROUTCHAR:
	lda ARG0
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

	cmp #CR
	beq SETEXQ		; set xeq on carriage return

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

	ldx CBUFN		; refresh x from CBUFN after inc
	lda #$00		; load 00 into a
	sta CMDBUF,X	; store in cmdbuf at offset x
					; always make sure last char in cmdbuf is 0x00

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
