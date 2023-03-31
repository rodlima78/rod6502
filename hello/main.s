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

my_lcd_init:
    lda #%00111000   ; set 8-bit operation, 2 lines, 5x7
    ; call it 3 times for proper set up while powering up
    sta LCD_INSTR
    jsr my_lcd_wait
    sta LCD_INSTR
    jsr my_lcd_wait
    sta LCD_INSTR
    jsr my_lcd_wait
    lda #%110     ; entry mode set: increment, do not shift
    sta LCD_INSTR
    jsr my_lcd_wait
    lda #%1110   ; display on, cursor on, blink off
    sta LCD_INSTR
    jsr my_lcd_wait
    lda #$80     ; set cursor to start of first line
    sta LCD_INSTR
    jsr my_lcd_wait
    lda #1        ; clear display
    sta LCD_INSTR
    jsr my_lcd_wait
    rts

