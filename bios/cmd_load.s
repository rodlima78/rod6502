.include "cmd.inc"
.include "lcd.inc"

.rodata
STR_LOAD: .asciiz "LOAD"

.code
cmd_load:
    lcd_print STR_LOAD
    jmp cmd_loop
