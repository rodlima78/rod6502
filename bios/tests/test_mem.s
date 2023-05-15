.include "sys.inc"
.include "mem.inc"
.include "io.inc"

.export main

.feature string_escapes

.zeropage
ptr1: .res 2
ptrtmp: .res 2
ptr2: .res 2
len:  .res 2

.code
.macro test_realloc name,size1,size2
    ; allocate memory with size1
    lda #<size1
    sta len
    lda #>size1
    sta len+1
    ldx #ptr1
    ldy #len
    jsr sys_malloc

    lda #1
    sta len
    stz len+1
    ldx #ptrtmp
    ldy #len
    jsr sys_malloc

    ; save pointer to allocated memory
    lda ptr1
    pha
    lda ptr1+1
    pha

    ; free memory
    ldx #ptr1
    jsr sys_free

    ; restore pointer to allocated memory
    pla
    sta ptr1+1
    pla
    sta ptr1

    ; allocate memory w/ size2
    ldx #ptr2
    lda #<size2
    sta len
    lda #>size2
    sta len+1
    ldy #len
    jsr sys_malloc
.endmacro

; ==============================================
; x,y: pointer to 16-bit pts to compare
compare_ptrs_equal:
    ; compare pointers  
    lda 0,x
    cmp 0,y
    bne @end
    lda 1,x
    cmp 1,y
@end:
    rts

report_result_equal:
    bne @fail
    jsr io_put_const_string
    .asciiz "OK"
    bra @end
@fail:
    jsr io_put_const_string
    .asciiz "FAIL "
    lda 0,x
    jsr io_put_hex
    lda 1,x
    jsr io_put_hex
    jsr io_put_const_string
    .asciiz "!="
    lda 0,y
    jsr io_put_hex
    lda 1,y
    jsr io_put_hex
@end:
    jsr io_put_const_string
    .asciiz " - "
    tsx
    inx
    jsr io_put_const_string_stack
    jsr io_put_const_string
    .asciiz "\r\n"
    rts

report_result_different:
    beq @fail
    jsr io_put_const_string
    .asciiz "OK"
    bra @end
@fail:
    jsr io_put_const_string
    .asciiz "FAIL "
    lda 0,x
    jsr io_put_hex
    lda 1,x
    jsr io_put_hex
    jsr io_put_const_string
    .asciiz "=="
    lda 0,y
    jsr io_put_hex
    lda 1,y
    jsr io_put_hex
@end:
    jsr io_put_const_string
    .asciiz " - "
    tsx
    inx
    jsr io_put_const_string_stack
    jsr io_put_const_string
    .asciiz "\r\n"
    rts

; ==============================================
test_realloc_same_size_even_small:
    test_realloc test_realloc_same_size_even_small, 18, 18
    ldx #ptr1
    ldy #ptr2
    jsr compare_ptrs_equal
    jsr report_result_equal
    .asciiz "test_realloc_same_size_even_small"
    ldx #ptr2
    jsr sys_free
    ldx #ptrtmp
    jsr sys_free
    rts

; ==============================================
test_realloc_same_size_odd_small:
    test_realloc test_realloc_same_size_odd_small, 19, 19
    ldx #ptr1
    ldy #ptr2
    jsr compare_ptrs_equal
    jsr report_result_equal
    .asciiz "test_realloc_same_size_odd_small"
    ldx #ptr2
    jsr sys_free
    ldx #ptrtmp
    jsr sys_free
    rts

; ==============================================
test_realloc_same_size_even_large:
    test_realloc test_realloc_same_size_even_large, 1718, 1718
    ldx #ptr1
    ldy #ptr2
    jsr compare_ptrs_equal
    jsr report_result_equal
    .asciiz "test_realloc_same_size_even_large"
    ldx #ptr2
    jsr sys_free
    ldx #ptrtmp
    jsr sys_free
    rts

; ==============================================
test_realloc_same_size_odd_large:
    test_realloc test_realloc_same_size_odd_large, 1719,1719
    ldx #ptr1
    ldy #ptr2
    jsr compare_ptrs_equal
    jsr report_result_equal
    .asciiz "test_realloc_same_size_odd_large"
    ldx #ptr2
    jsr sys_free
    ldx #ptrtmp
    jsr sys_free
    rts

; ==============================================
test_realloc_diff_size_large_small:
    test_realloc test_realloc_same_size_odd_large, 1719,1701
    ldx #ptr1
    ldy #ptr2
    jsr compare_ptrs_equal
    jsr report_result_equal
    .asciiz "test_realloc_diff_size_large_small"
    ldx #ptr2
    jsr sys_free
    ldx #ptrtmp
    jsr sys_free
    rts

; ==============================================
test_realloc_diff_size_small_large:
    test_realloc test_realloc_same_size_odd_large, 1701,1719
    ldx #ptr1
    ldy #ptr2
    jsr compare_ptrs_equal
    jsr report_result_different
    .asciiz "test_realloc_diff_size_small_large"
    ldx #ptr2
    jsr sys_free
    ldx #ptrtmp
    jsr sys_free
    rts

.code
main:
    jsr test_realloc_same_size_even_small
    jsr test_realloc_same_size_odd_small
    jsr test_realloc_same_size_even_large
    jsr test_realloc_same_size_odd_large
    jsr test_realloc_diff_size_large_small
    jsr test_realloc_diff_size_small_large

    jmp sys_exit
