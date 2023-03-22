.include "export.inc" 

.import LCD_INSTR
.import LCD_DATA

RT6502_PUBLIC_ZP LCD_MSGBASE

RT6502_PUBLIC lcd_init
RT6502_PUBLIC lcd_wait
RT6502_PUBLIC lcd_clear
RT6502_PUBLIC lcd_printchar
RT6502_PUBLIC lcd_hex
RT6502_PUBLIC lcd_string

.macro lcd_print strz
    pha
    lda #<strz
    sta LCD_MSGBASE
    lda #>strz
    sta LCD_MSGBASE+1
    jsr lcd_string
    pla
.endmacro

