.include "lcd.inc"
.include "io.inc"

.code

lcd_init:
    pha

    ; It's highly recommended that we call the function set 3 times
    ; for proper power-up
    lda #%00111000   ; set 8-bit operation, 2 lines, 5x7
    sta LCD_INSTR
    jsr lcd_wait
    sta LCD_INSTR
    jsr lcd_wait
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

    lda #$80      ; set cursor to 1st line
    sta LCD_INSTR
    jsr lcd_wait

    pla
    rts

lcd_wait:
    bit LCD_INSTR
    bmi lcd_wait ; bit 7 is one (busy)? continue waiting
    rts

lcd_clear:
    pha
    lda #1
    sta LCD_INSTR
    jsr lcd_wait
    pla
    rts

lcd_put_byte:
    sta LCD_DATA
    jsr lcd_wait
    rts

lcd_put_hex:
    php

    jsr io_push_put_byte
    .addr lcd_put_byte
    jsr io_put_hex
    jsr io_pop_put_byte

    plp
    rts
