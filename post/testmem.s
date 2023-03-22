.include "via.inc"
.include "mem.inc"

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
    lda #0
    bra success
fail:
    lda #1
success:
    rts

