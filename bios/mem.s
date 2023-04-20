.include "lcd.inc"
.include "mem.inc"

.export init_mem

.data
heap_next: .res 2   ; next address available
heap_size: .res 2   ; free heap memory

.segment "HEAP"
heap_base: .res 1

.code
; X: zp pointer to word w/ allocation size
; Y: zp pointer to word where address will be written to
; ret A: status 0->ok, 1->nomem
sys_malloc:
    ; save allocated address to the output
    lda heap_next
    sta 0,y
    lda heap_next+1
    sta 1,y

    ; make heap_next point to the next available address
    lda heap_next
    clc
    adc 0,x
    sta heap_next
    lda heap_next+1
    adc 1,x
    sta heap_next+1

    ; update free heap size and check for nomem
    lda heap_size
    sec
    sbc 0,x
    sta heap_size
    lda heap_size+1
    sbc 1,x
    sta heap_size+1
    bcc @error
    lda #0
    rts
@error:
.rodata
@nomem_str: .asciiz   "NOMEM"
.code
    lcd_print @nomem_str
    lda #1
    rts

init_mem:
    pha

    lda #<heap_base
    sta heap_next
    lda #>heap_base
    sta heap_next+1

    lda #<(__RAM_START__+__RAM_SIZE__-__HEAP_RUN__)
    sta heap_size
    lda #>(__RAM_START__+__RAM_SIZE__-__HEAP_RUN__)
    sta heap_size+1

    pla
    rts

