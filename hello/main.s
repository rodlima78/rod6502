.include "sys.inc"
.include "lcd.inc"

.rodata
HELLO: .asciiz "Hello, world!"

.macro my_lcd_print str
    .local loop
    .local end
    ldy #0
loop:
    lda str, y
    beq end
    sta LCD_DATA
    jsr my_lcd_wait
    iny
    bne loop
end:
.endmacro

.code
main:
    my_lcd_print HELLO
    stp

my_lcd_wait:
    bit LCD_INSTR
    bmi my_lcd_wait ; bit 7 is one (busy)? continue waiting
    rts

.interruptor irq0_handler, 1

irq0_handler:
    rti

