.include "sys.inc"

.import cmd_loop
.export import_table

sys_exit:
    jmp cmd_loop

.rodata
.macro defsymbol sym
    .byte 1+.strlen(.string(sym))+1+2
    .asciiz .string(sym)
    .addr sym
.endmacro

import_table:
    ; must be sorted in ascii order
    defsymbol sys_exit
    .byte 0 ; end-of-table
