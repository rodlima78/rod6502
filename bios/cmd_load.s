.include "cmd.inc"
.include "lcd.inc"
.include "acia.inc"

.import __RAM_USER_START__

SOH = $01
EOT = $04
ACK = $06
NAK = $15
CAN = $18

.zeropage
next_block: .res 1
checksum: .res 1
dest_addr: .res 2

; ref: http://moscova.inria.fr/~doligez/zmodem/ymodem.txt pg. 20

.code
cmd_load:
    jsr acia_put_const_string
    .asciiz "Please initiate transfer..."

    ; signal sender to start transfer
    lda #NAK
    jsr acia_put_char

    lda #1 ; next block number == 1
    sta next_block

    ; start writing at where user code should be
    lda #<__RAM_USER_START__
    sta dest_addr
    lda #>__RAM_USER_START__
    sta dest_addr+1

@start_block:
    ; start receiving block
    lda #10           ; 10s timeout
    jsr acia_get_char ; get start-of-header or end-of-transfer
    bne @error
    cmp #EOT            ; end of transfer?
    beq @file_received  ; yes, we're good
    cmp #SOH            ; no, is it start of header?
    bne @error           ; no? error

    lda #1             ; 1s timeout
    jsr acia_get_char ; block number
    bne @error
    cmp next_block    ; not what we expect?
    bne @error

    lda #1             ; 1s timeout
    jsr acia_get_char ; 255 - block number
    bne @error
    clc
    adc next_block    ; (block_number + (255-block_number))%256 == 255
    cmp #255
    bne @error

    lda #0 ; for updating checksum, start with 0
    sta checksum

    ldy #0
@loop:
    lda #1             ; 1s timeout
    jsr acia_get_char
    bne @error
    sta (dest_addr),y

    ; update checksum
    clc
    adc checksum
    sta checksum

    iny
    cpy #128    ; end of data?
    bne @loop   ; no, recv more

    lda #1             ; 1s timeout
    jsr acia_get_char ; yes, get checksum
    bne @error
    cmp checksum
    bne @error

    ; acknowledge that we have received the block
    lda #ACK
    jsr acia_put_char

    inc next_block

    ; dest_addr points to where next block will be written to
    lda #128
    clc 
    adc dest_addr
    sta dest_addr
    bcc @skip_high
    inc dest_addr+1
@skip_high:
    bra @start_block

@error:
    lda #NAK
    jsr acia_put_char
    jmp @start_block

@file_received:
    ; acknowledge that we have received the file
    lda #ACK
    jsr acia_put_char

    jsr acia_put_const_string
    .asciiz " OK\r\n"

    jmp cmd_loop
