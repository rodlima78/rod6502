.include "acia.inc"
.include "irq.inc"
.include "lcd.inc"
.include "via.inc"

.export test_acia

.code
test_acia:
    ; PB6 is input
    lda #$40
    tsb VIA_DIR_B

    ; echo(b3), no interrupt (b2-1), data terminal ready (b0)
    lda #%10011
    sta ACIA_CMD
    ; 0 stop bit (b7), 8 data bits (b6-5), baud rate (b4), 115.2K bauds (b3-0)
    lda #%00010000
    sta ACIA_CTRL

recv:
    lda ACIA_STATUS
    bit #%1000 ; receiver data register full?
    beq recv
    lda ACIA_DATA
    sta LCD_DATA
    jsr lcd_wait
    jmp recv

