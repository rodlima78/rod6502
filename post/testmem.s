.include "via.inc"
.include "mem.inc"

.export test_zp
.export test_stack
.export test_ram
.import post_fail
.import after_test_zp
.import after_test_stack
.importzp STATUS_STR

.zeropage
PAGE_ADDR: .res 1

.data
ERROR_ADDR: .res 5
.export ERROR_ADDR

.rodata
HEXDIGITS: .byte "0123456789ABCDEF"

.macro write_addr_error offset
    tax ; can't use stack, let's save A in X
    lsr a  ; shift high nibble into low nibble
    lsr a
    lsr a
    lsr a
    tay
    lda HEXDIGITS,y ; convert to ASCII
    sta ERROR_ADDR+offset
    txa ; restore A
    and #$0F ; select low nibble
    tay
    lda HEXDIGITS,y
    sta ERROR_ADDR+offset+1
    .if offset > 0
        stz ERROR_ADDR+offset+2 ; null terminator
    .endif
.endmacro

.code
 ; Test zero page ----------
.macro test_mem_page page
    .local loop_w_page
    .local loop_r_page
    .local success
    .local fail
    .local continue
    ; write data
    lda #0 ; value to be stored, and index were it'll go
loop_w_page:
    tay
    sta page,y
    ina
    bne loop_w_page

    ; read it back
    lda #0
loop_r_page:
    tay
    cmp page,y
    bne fail
    ina
    bne loop_r_page
    ; A is 0 here; ZF==1
    bra success
fail:
    write_addr_error 2 ; write address LSB
    lda #>page
    write_addr_error 0 ; write address MSB
    lda #<ERROR_ADDR
    sta STATUS_STR
    lda #>ERROR_ADDR
    sta STATUS_STR+1
    lda #1 ; indicate error
success:
.endmacro

test_zp:
    test_mem_page 0
    jmp after_test_zp

test_stack:
    test_mem_page $0100
    jmp after_test_stack

test_ram:
    ; start w/ last page in RAM
    lda #0
    sta PAGE_ADDR
    lda #<(__RAM_SIZE__/256-1)
    sta PAGE_ADDR+1

    ; write data
loop_new_page:
    ; page address is even? turn off leds
    bbr0 PAGE_ADDR+1,leds_off
    ; or else turn them on
    lda #(VIA_LED_GREEN+VIA_LED_RED)
    bra write_led
leds_off:
    lda #0
write_led:
    sta VIA_IO_B

    lda #0
loop_w_ram:
    tay
    sta (PAGE_ADDR),y
    ina
    bne loop_w_ram

    ; read it back
    lda #0
loop_r_ram:
    tay
    cmp (PAGE_ADDR),y
    bne fail
    ina
    bne loop_r_ram

    dec PAGE_ADDR+1
    ; loop till PAGE_ADDR==1 (we don't want to corrupt the stack)
    lda #1
    cmp PAGE_ADDR+1
    bne loop_new_page
    bra success
fail:
    write_addr_error 2
    lda PAGE_ADDR+1
    write_addr_error 0
    lda #<ERROR_ADDR
    sta STATUS_STR
    lda #>ERROR_ADDR
    sta STATUS_STR+1
success:
    rts

