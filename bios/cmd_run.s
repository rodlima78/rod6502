.include "cmd.inc"
.include "lcd.inc"

.rodata
STR_RUN: .asciiz "RUN"

.code
cmd_run:
    lcd_print STR_RUN
    jmp cmd_loop
