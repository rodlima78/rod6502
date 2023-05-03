.import LCD_INSTR
.import LCD_DATA

.globalzp LCD_MSGBASE

.global lcd_init
.global lcd_wait
.global lcd_clear
.global lcd_put_char
.global lcd_hex
.global lcd_string

.macro lcd_print strz
    pha
    lda #<strz
    sta LCD_MSGBASE
    lda #>strz
    sta LCD_MSGBASE+1
    jsr lcd_string
    pla
.endmacro

