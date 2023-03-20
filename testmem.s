START_ROM = $C800
CPU_VECTORS = $FFFA

VIA_DIR_B = $C002
VIA_STORE_B = $C000
VIA_ACR = $C00D
VIA_T1CL = $C004
VIA_T1CH = $C005
VIA_T1LL = $C006
VIA_T1LH = $C007

LCD_INSTR = $C300
LCD_DATA = $C301
IRQ_CTRL = $C100

POST_STATE_ZP = 0
POST_STATE_STACK = 1
POST_STATE_VIA_WAIT = 2
POST_STATE_VIA_OK = 3
POST_STATE_RAM = 4
POST_STATE = $0000

RED_LED = 32
GREEN_LED = 128
PAGE_ADDR = $0001

MSGBASE = $0003

 .org $8000
 .org START_ROM

MSG_POST_START .asciiz "P"
MSG_POST_BAD .asciiz "HW ERROR"
MSG_POST_OK .asciiz "OK"

reset:
 ; initialize stack pointer
 ldx #$ff
 txs

 ; disable interrupts
 sei

 ; allow all irq lines
 lda #$FF
 sta IRQ_CTRL

 ; Set VIA_PB to output
 lda #$FF
 sta VIA_DIR_B

 ; Turn on red and green leds
 lda #(GREEN_LED+RED_LED)
 sta VIA_STORE_B

 ; initialize lcd display
 jsr lcd_init

 ; Write message indicating POST start
 lda #(MSG_POST_START & $FF)
 sta MSGBASE
 lda #(MSG_POST_START >> 8)
 sta MSGBASE+1
 jsr lcd_string

 lda #0
 sta VIA_STORE_B
 lda #(GREEN_LED+RED_LED)
 sta VIA_STORE_B

 ; Test zero page ----------
test_zp:
 lda #POST_STATE_ZP
 sta POST_STATE
 ; write data
 ldx #0 ; value to be stored
 ldy #0 ; index within page
loop_w_zp:
 stx 0,y
 inx
 iny
 bne loop_w_zp

 ; read it back
 ldx #0
 ldy #0
loop_r_zp:
 txa
 cmp 0,y
 bne post_zp_fail
 inx
 iny
 bne loop_r_zp

 jmp post_success

post_zp_fail:
 jmp post_fail

 ; From now on we can reliably use the zero-page variables

 ; Test stack ----------
test_stack:
 lda #POST_STATE_STACK
 sta POST_STATE
 ; write data
 ldx #0 ; value to be stored
 ldy #0 ; index within page
loop_w_stack:
 txa
 sta $0100,y
 inx
 iny
 bne loop_w_stack

 ; read it back
 ldx #0
 ldy #0
loop_r_stack:
 txa
 cmp $0100,y
 bne post_fail
 inx
 iny
 bne loop_r_stack

 jmp post_success

 ; From now on we can reliably use the stack (and subroutines)

 ; Test VIA -----------------
test_via:
 lda #POST_STATE_VIA_WAIT
 sta POST_STATE

 ; Set VIA_PB to output
 lda #$FF
 sta VIA_DIR_B

 lda #$C0  ; enable timer1 in one-shot mode
 trb VIA_ACR
 ; one-shot after 256 cycles
 lda #$FF
 sta VIA_T1CL
 stz VIA_T1CH
 ; wait for irq to uddate state
 ldx #$FF
wait_via_irq:
 lda #POST_STATE_VIA_OK
 cmp POST_STATE
 beq test_ram
 dex
 beq post_fail
 bra wait_via_irq

test_ram:
 lda #POST_STATE_RAM
 sta POST_STATE

 ; start w/ last page in RAM
 lda #0
 sta PAGE_ADDR
 lda #(48*1024/256-1)
 sta PAGE_ADDR+1

 ; write data
loop_new_page:
 ; page address is even? turn off leds
 bbr0 PAGE_ADDR+1,leds_off
 ; or else turn them on
 lda #(GREEN_LED+RED_LED)
 jmp write_led
leds_off:
 lda #0
write_led:
 sta VIA_STORE_B

 ldx #0
 ldy #0
loop_w_ram:
 txa
 sta (PAGE_ADDR),y
 inx
 iny
 bne loop_w_ram

 ; read it back
 ldx #0
 ldy #0
loop_r_ram:
 txa
 cmp (PAGE_ADDR),y
 bne post_fail
 inx
 iny
 bne loop_r_ram

 dec PAGE_ADDR+1
 bne loop_new_page

 jmp post_success

post_fail:
 lda #RED_LED
 sta VIA_STORE_B

 lda #(MSG_POST_BAD & $FF)
 sta MSGBASE
 lda #(MSG_POST_BAD >> 8)
 sta MSGBASE+1
 jsr lcd_string

 jmp end

post_success:
 lda #GREEN_LED
 sta VIA_STORE_B

 lda #(MSG_POST_OK & $FF)
 sta MSGBASE
 lda #(MSG_POST_OK >> 8)
 sta MSGBASE+1
 jsr lcd_string

end:
 bra end

lcd_init:
 lda #%00111000   ; set 8-bit operation, 2 lines, 5x7
 sta LCD_INSTR
 jsr lcd_wait
 lda #%110     ; entry mode set: increment, do not shift
 sta LCD_INSTR
 jsr lcd_wait
 lda #%1110   ; display on, cursor on, blink off
 sta LCD_INSTR
 jsr lcd_wait
 lda #1        ; clear display
 sta LCD_INSTR
 jsr lcd_wait
 rts

lcd_wait:
 bit LCD_INSTR
 bmi lcd_wait ; bit 7 is one (busy)? continue waiting
 rts

lcd_clear:
 pha
 lda #1
 sta LCD_INSTR
 lsr lcd_wait
 pla
 rts

lcd_print:
 pha
 sta LCD_DATA
 jsr lcd_wait
 lda LCD_INSTR
 and #$7F
 cmp #$14
 bne lcd_print0
 lda #$C0
 sta LCD_INSTR
 jsr lcd_wait
lcd_print0:
 pla
 rts

lcd_hex:
 pha
 lsr a  ; shift high nibble into low nibble
 lsr a
 lsr a
 lsr a
 tay
 lda HEXASCII,y ; convert to ASCII
 jsr lcd_print
 pla
 pha
 and #$0F ; select low nibble
 tay
 lda HEXASCII,y
 jsr lcd_print
 pla
 rts
 
lcd_string:
 pha
 phy
 ldy #0
lcd_str0:
 lda (MSGBASE), y
 beq lcd_str1
 jsr lcd_print
 iny
 bne lcd_str0
lcd_str1:
 ply
 pla
 rts

HEXASCII .byte "0123456789ABCDEF"

RODLIMA .asciiz "RODLIMA"

irq:
 pha

 lda #(RODLIMA & $FF)
 sta MSGBASE
 lda #(RODLIMA >> 8)
 sta MSGBASE+1
 jsr lcd_string
 bra end_irq

 lda #POST_STATE_VIA_WAIT
 cmp POST_STATE
 bne irq_not_post
 lda #POST_STATE_VIA_OK
 sta POST_STATE
 bra end_irq
irq_not_post:
 jsr lcd_clear
 lda IRQ_CTRL
 clc
 ror
 jsr lcd_hex

end_irq:
 pla
 rti

nmi:
 rti

 .org CPU_VECTORS
 .word nmi
 .word reset
 .word irq

