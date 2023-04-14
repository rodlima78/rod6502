.include "acia.inc"
.include "cmd.inc"

.import __RAM_USER_START__
.importzp app_loaded

.code
cmd_run:
    bit app_loaded  ; app is loaded?
    bpl @error      ; no, error out
    jmp __RAM_USER_START__
@error:
    jsr acia_put_const_string
    .asciiz "No application loaded"
    jmp cmd_loop
