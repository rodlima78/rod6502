.include "cmd.inc"
.include "acia.inc"
.include "mem.inc"
.include "xmodem.inc"

.importzp app_loaded

SOH = $01
EOT = $04
ACK = $06
NAK = $15
CAN = $18

.zeropage
next_block: .res 1
next_data_in_block: .res 1 ; index of next data to be read in block

checksum: .res 1
retries: .res 1

.data
fnerror: .res 2

; ref: http://moscova.inria.fr/~doligez/zmodem/ymodem.txt pg. 20

.code
; y,x: ptr to error function in zero page
xmodem_init:
    ; store error function
    stx fnerror
    sty fnerror+1

    ; Start with block==1
    lda #1
    sta next_block

    ; 10 retries
    lda #10
    sta retries

    ; signal sender to start transfer
    lda #NAK
    jsr acia_put_char

start_block:
    ; start receiving block
    lda #10           ; 10s timeout
    jsr acia_get_char ; get start-of-header or end-of-transfer
    bne xmodem_error
    cmp #EOT            ; end of transfer?
    beq @file_received  ; yes, we're good
    cmp #SOH            ; no, is it start of header?
    bne xmodem_error    ; no? error

    lda #1             ; 1s timeout
    jsr acia_get_char ; block number
    bne xmodem_error
    cmp next_block    ; not what we expect?
    bne xmodem_error

    lda #1             ; 1s timeout
    jsr acia_get_char ; 255 - block number
    bne xmodem_error
    clc
    adc next_block    ; (block_number + (255-block_number))%256 == 255
    cmp #255
    bne xmodem_error

    lda #0 ; for updating checksum, start with 0
    sta checksum

    stz next_data_in_block ; next byte read will have index 0

    ; from now on there are no more retries
    stz retries

    ; return when caller is ready to read data
    ; Z==1, A==0
    rts

@file_received:
    ; acknowledge that we have received the file
    lda #ACK
    jsr acia_put_char

    ; indicate transfer has finished
    lda #$ff
    sta retries
    
    ; Z==0 and A==0: end of file
    lda #1
    php
    lda #0
    plp

    rts

xmodem_error:
    lda retries         ; still more retries?
    beq @bail           ; no, give up

    dea                 ; yes, decrement retries
    sta retries        

    lda #NAK            ; indicate sender to resend block
    jsr acia_put_char

    bra start_block     ; receive start of block
@bail:
    ; Cancel transfer, must send 2 CANs
    lda #CAN
    jsr acia_put_char
    jsr acia_put_char

    jsr acia_purge
    jsr acia_put_const_string
    .asciiz " FAILED"

    ; indicate transfer has finished
    lda #$ff
    sta retries

    pla ; remove caller's return address from stack
    pla

    lda #1  ; signal error
    jmp (fnerror)

end_block:
    lda #1            ; 1s timeout
    jsr acia_get_char ; yes, get checksum
    bne xmodem_error
    cmp checksum
    bne xmodem_error

    ; acknowledge that we have received the block
    lda #ACK
    jsr acia_put_char

    inc next_block

    jmp start_block

; return a: byte read
xmodem_read_byte:
    lda next_data_in_block
    cmp #128        ; no more data in this block?
    bne @has_more_data   ; process end of block
    jsr end_block

@has_more_data:
    lda #1             ; 1s timeout
    jsr acia_get_char
    bne xmodem_error

    inc next_data_in_block

    ; update checksum
    pha 
    clc
    adc checksum
    sta checksum
    pla

    rts

xmodem_skip_block:
    lda retries
    cmp #$ff    ; transfer is finished
    beq @eof   ; yes, nothing else to do

    lda #128
    sec
    sbc next_data_in_block
    tax
@loop:
    beq @end ; reached end of block? return
    jsr acia_get_char
    bne xmodem_error

    ; update the checksum
    clc
    adc checksum
    sta checksum

    dex
    bra @loop
@end: 
    jmp end_block ; tail optimization, will set Z==1 at the end

@eof:
    lda #1 ; Z==0, EOF
    rts

xmodem_deinit:
    lda retries
    cmp #$ff    ; transfer is finished
    beq @done   ; yes, nothing else to do
    lda #CAN    ; no, cancel transfer
    jsr acia_put_char
    jsr acia_put_char
    jsr acia_purge
@done:
    rts