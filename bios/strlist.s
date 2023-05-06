.include "strlist.inc"

.segment "ZPTMP": zeropage
strlist_ptr: .res 2
strlist_len: .res 2
strlist_cb_found: .res 2
strlist_cb_not_found: .res 2
strlist_cb_get_byte: .res 2
strlist: .res 2

.code
; =============================================
; strlist_len: zp ptr to number of elements to process
; strlist: zp ptr to string list
; strlist_cb_found: called for each string found, ptr points to matched list item,
;                   Y points to the first byte after end of item string, if returns C==1, abort processing
; strlist_cb_not_found: called for each string not found, if returns C==1, abort processing
; strlist_cb_get_byte: called when a byte is needed, returned in A, if C==1, abort processing
; C==1, error
process_strlist:
    clc

@next_item:
    bcs @end

    ; early if len==0
    lda strlist_len
    bne @skip_msb3
    lda strlist_len+1
    beq @end
    ; or when the list is empty
    lda (strlist)
    beq @end

    ; decrement number of items to be processed
    dec strlist_len+1
@skip_msb3:
    dec strlist_len

    ; start search from first list item
    lda strlist
    sta strlist_ptr 
    lda strlist+1
    sta strlist_ptr+1

    ldy #1  ; point to first character
@find_newchar:
    ; emulate 'jsr (strlist_cb_get_byte)', but returning to next_item
    lda #>(@after_read-1)
    pha
    lda #<(@after_read-1)
    pha
    jmp (strlist_cb_get_byte)
@after_read:
    bcs @end             ; read byte has errors? bail
@find_char:
    cmp (strlist_ptr),y
    bcc @not_found       ; query < string ? not found
    bne @try_next_string ; query > string ? try next
    cmp #0               ; query == string, end of string? 
    beq @found           ; yes, found it!
    iny                  ; no, compare next char
    bra @find_newchar

@try_next_string:
    pha                  ; save query char
    lda (strlist_ptr)    ; load stride
    bne @has_next_string ; end of strlist (stride==0)?
    pla                  ; yes, restore stack
    bra @not_found       ; signal that it wasn't found
@has_next_string:        ; no, go to next string
    clc
    adc strlist_ptr   ; make ptr point to next string
    sta strlist_ptr 
    bcc @skip_msb
    inc strlist_ptr+1
@skip_msb:
    pla             ; restore query char
    bra @find_char

@found:
    ; simulate indirect jsr, but process next item on return
    lda #>(@next_item-1)
    pha
    lda #<(@next_item-1)
    pha
    iny ; Y points to the first byte after item key
    jmp (strlist_cb_found)

@not_found:
    ; simulate indirect jsr, but process next item on return
    lda #>(@next_item-1)
    pha
    lda #<(@next_item-1)
    pha
    jmp (strlist_cb_not_found)

@end:
    rts
