.include "via.inc"

.export test_zp
.export test_stack
.export test_ram
.import post_fail
.import after_test_zp
.import after_test_stack

.zeropage
PAGE_ADDR: .res 1

.code

 ; Test zero page ----------
.macro test_mem_page page
    .local loop_w_page
    .local loop_r_page
    .local success
    .local fail
    ; write data
    lda #0 ; value to be stored, and index were it'll go
loop_w_page:
    tay
    sta page,y
    inc a
    bne loop_w_page

    ; read it back
    lda #0
loop_r_page:
    tay
    cmp page,y
    bne fail
    inc a
    bne loop_r_page
    ; A is 0 here
    bra success
fail:
    lda #1
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
    lda #(48*1024/256-1)
    sta PAGE_ADDR+1

    ; write data
loop_new_page:
    ; page address is even? turn off leds
    bbr0 PAGE_ADDR+1,leds_off
    ; or else turn them on
    lda #(VIA_LED_GREEN+VIA_LED_RED)
    jmp write_led
leds_off:
    lda #0
write_led:
    sta VIA_IO_B

    lda #0
loop_w_ram:
    tay
    sta (PAGE_ADDR),y
    inc a
    bne loop_w_ram

    ; read it back
    lda #0
loop_r_ram:
    tay
    cmp (PAGE_ADDR),y
    bne fail
    inc a
    bne loop_r_ram

    dec PAGE_ADDR+1
    bne loop_new_page
    ; A is zero here
    bra success
fail:
    lda #1
success:
    rts

