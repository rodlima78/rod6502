.include "lcd.inc"

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

lcd_printchar:
    sta LCD_DATA
    jsr lcd_wait
    rts

lcd_hex:
    php
    phy
    pha
    lsr a  ; shift high nibble into low nibble
    lsr a
    lsr a
    lsr a
    tay
    lda LCD_HEXASCII,y ; convert to ASCII
    jsr lcd_printchar
    pla
    pha
    and #$0F ; select low nibble
    tay
    lda LCD_HEXASCII,y
    jsr lcd_printchar
    pla
    ply
    plp
    rts

lcd_string:
    pha
    phy
    ldy #0
lcd_str0:
    lda (LCD_MSGBASE), y
    beq lcd_str1
    jsr lcd_printchar
    iny
    bne lcd_str0
lcd_str1:
    ply
    pla
    rts

.rodata
LCD_HEXASCII: .byte "0123456789ABCDEF"

.zeropage
LCD_MSGBASE: .res 2
