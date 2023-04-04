.include "cmd.inc"
.include "acia.inc"
.include "via.inc"
.include "lcd.inc"

LF = $0A
PROMPT = '>'

.feature string_escapes

.code
cmd_loop:
    lda #(VIA_LED_GREEN+VIA_LED_RED)
    tsb VIA_DIR_B

    jsr acia_start

    lda #0
    sta VIA_IO_B

    jsr acia_put_const_string
    .asciiz "Rodolfo Schulz de Lima\r\n"

    lda #VIA_LED_GREEN
    sta VIA_IO_B

    stp

@error:
    pha
    lda #'E'
    jsr lcd_printchar
    pla
    jsr lcd_hex
    jsr acia_stop
    lda #VIA_LED_RED
    sta VIA_IO_B
    stp

.if 0
cmd_loop:
    jsr get_cmd
    tax
    jmp (cmd_jumptable,x)

.rodata
cmd_jumptable:
    .addr cmd_load
    .addr cmd_run

.data
CMD_BUFFER: .res 8

.code
get_cmd:
    jsr acia_start
    lda #1
    jsr acia_enable_echo

    lda #PROMPT
    jsr acia_put_char

@prompt:
    lda #PROMPT
    jsr acia_put_char

    ldx #0 ; points to address to store next char to be read
@get_char:
    jsr acia_get_char
    cmp #LF             ; line feed?
    beq @end            ; yes, command was entered
    sta CMD_BUFFER,x    ; no, append charater to buffer
    inx                 ; bump next address
    cmp #8              ; reached end of buffer space?
    bne @get_char       ; no, get next char
    jsr acia_put_const_string
    .asciiz "command too big\n"

@end:
    stz CMD_BUFFER,x ; NUL marks end of buffer
    jsr acia_stop
    rts
.endif
