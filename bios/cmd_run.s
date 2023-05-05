.include "acia.inc"
.include "cmd.inc"
.include "mem.inc"
.include "io.inc"

.importzp app_loaded
.import ptr_app_entrypoint

.code
cmd_run:
    bit app_loaded          ; app is loaded?
    bpl @error_not_loaded   ; no, error out

    ; check if app defined an entry point
    lda ptr_app_entrypoint
    bne @has_entry_point
    lda ptr_app_entrypoint+1
    beq @error_no_main        ; no, error
@has_entry_point:
    jmp (ptr_app_entrypoint)  ; yes, jump to app's entry point

@error_not_loaded:
    jsr io_put_const_string
    .asciiz "No application loaded"
    jmp cmd_loop

@error_no_main:
    jsr io_put_const_string
    .asciiz "Application doesn't define a 'main' entry point"
    jmp cmd_loop
