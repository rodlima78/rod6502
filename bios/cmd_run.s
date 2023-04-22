.include "acia.inc"
.include "cmd.inc"
.include "mem.inc"

.importzp app_loaded

.code
cmd_run:
    bit app_loaded  ; app is loaded?
    bpl @error      ; no, error out

    jmp __HEAP_RUN__ ; program is loaded in the beginning of heap memory
@error:
    jsr acia_put_const_string
    .asciiz "No application loaded"
    jmp cmd_loop
