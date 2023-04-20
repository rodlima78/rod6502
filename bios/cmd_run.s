.include "acia.inc"
.include "cmd.inc"
.include "mem.inc"

.import __RAM_START__
.importzp app_loaded

.code
cmd_run:
    bit app_loaded  ; app is loaded?
    bpl @error      ; no, error out
    jmp __DATA_RUN__+__DATA_SIZE__ ; program is loaded at the end of bios' data segment
@error:
    jsr acia_put_const_string
    .asciiz "No application loaded"
    jmp cmd_loop
