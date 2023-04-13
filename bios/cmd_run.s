.include "cmd.inc"
.import __RAM_USER_START__

.code
cmd_run:
    jmp __RAM_USER_START__
