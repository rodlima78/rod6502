.include "io.inc"

.data
io_cb_put_byte: .res 2
io_cb_get_byte: .res 2

.rodata
IO_HEXASCII: .byte "0123456789ABCDEF"

.zeropage
ptr: .res 2

STACK_SEG = $0100

.code

.macro io_push_cb cb
    ;                         0   1  2
    ; stack:                 <S> Rl Rh
    phx
    pha               
    ;                   0  1  2   3  4
    ; stack:           <S> A  X  Rl Rh
    phx
    pha
    ;              0  1 2  3  4   5  6
    ; stack:      <S> A X  A  X  Rl Rh 
    
    tsx

    lda STACK_SEG+5,x ; copy Rl
    sta ptr
    clc
    adc #2            ; must return right after the addr parameter
    sta STACK_SEG+3,x
    lda STACK_SEG+6,x ; copy Rh
    sta ptr+1
    adc #0            ; propagate carry from Rl+2
    sta STACK_SEG+4,x
    ;              0  1 2  3  4   5  6
    ; stack:      <S> A X Rl Rh  Rl Rh 

    lda cb
    sta STACK_SEG+5,x
    lda cb+1
    sta STACK_SEG+6,x
    ;              0  1 2  3  4   5  6
    ; stack:      <S> A X Rl Rh  Cl Ch 
    
    ; Set the current callback function
    phy
    ldy #1
    lda (ptr),y 
    sta cb 
    iny
    lda (ptr),y
    sta cb+1
    ply

    pla
    plx
    ;                  0   1  2   3  4
    ; stack:          <S> Rl Rh  Cl Ch 
.endmacro

.macro io_pop_cb cb
    ;                  0   1  2   3  4
    ; stack:          <S> Rl Rh  Cl Ch 
    phx
    pha               
    ;              0  1 2  3  4   5  6
    ; stack:      <S> A X Rl Rh  Cl Ch 
    tsx

    lda STACK_SEG+5,x ; copy Cl
    sta cb
    lda STACK_SEG+6,x ; copy Ch
    sta cb+1

    lda STACK_SEG+3,x ; copy Rl
    sta STACK_SEG+5,x
    lda STACK_SEG+4,x ; copy Rh
    sta STACK_SEG+6,x
    ;              0  1 2  3  4   5  6
    ; stack:      <S> A X Rl Rh  Rl Rh 
    lda STACK_SEG+1,x ; copy A
    sta STACK_SEG+3,x
    lda STACK_SEG+2,x ; copy X
    sta STACK_SEG+4,x
    ;              0  1 2  3  4   5  6
    ; stack:      <S> A X  A  X  Rl Rh 
    pla
    plx
    pla
    plx
    ;                         0   1  2
    ; stack:                 <S> Rl Rh
.endmacro

; =============================================
io_push_put_byte:
    io_push_cb io_cb_put_byte
    rts

; =============================================
io_pop_put_byte:
    io_pop_cb io_cb_put_byte
    rts

; =============================================
io_push_get_byte:
    io_push_cb io_cb_get_byte
    rts

; =============================================
io_pop_get_byte:
    io_pop_cb io_cb_get_byte
    rts

; =============================================
; input: A = byte to be output as hex string
io_put_hex:
    php
    phy
    pha
    lsr a  ; shift high nibble into low nibble
    lsr a
    lsr a
    lsr a
    jsr io_nibble
    pla
    pha
    and #$0F ; select low nibble
    jsr io_nibble
    pla
    ply
    plp
    rts

; input: A=nibble to output (ignores most significant nibble)
; garbles Y and A
io_nibble:
    tay
    lda IO_HEXASCII,y
io_put_byte:
    jmp (io_cb_put_byte) ; tail-call optimization

; =============================================
; input: string comes right after jsr
io_put_const_string:
    phx
    ; stack: X Rl Rh
    tsx
    pha
    lda STACK_SEG+2,x
    sta ptr 
    lda STACK_SEG+3,x
    sta ptr+1

    phy
    ldy #1                      ; ADDR_BUFFER points to 1 byte before the start of string,
                                ; so we start our loop with index == 1
@send_char:
    lda (ptr),y
    beq @end                    ; end of string (A==0)? go to end
    jsr io_put_byte             ; send character
    iny
    bne @send_char              ; string not too long (y didn't wrap around)? continue
    bra @error                  ; or else go to error

@loop_find_null:
    iny
@error: 
    lda (ptr),y                 ; Y points to character that wasn't tested for \0 yet
    bne @loop_find_null         ; no \0 yet? keep looking for it

@end:
    ; Y points to null terminator
    ; S:(X+2) still points to the buffer address
    tya
    ; Adds Y to return address stored by jsr,
    ; to make it point to the null terminator, which is
    ; one byte before the actual return address, as expected by rts.
    clc
    adc STACK_SEG+2,x
    sta STACK_SEG+2,x
    bcc @skip_high
    inc STACK_SEG+3,x
@skip_high:
    ply
    pla
    plx
    rts

; =============================================
io_get_byte:
    jmp (io_cb_get_byte)

; =============================================
; output: A: parsed byte
; success: C==0, error: C==1
io_get_hex:
    phx
    jsr io_get_byte
    bcs @end
    jsr parse_hex_nibble    ; parse most significant nibble
    bcs @end
    asl                     ; shift nibble low to high
    asl
    asl
    asl
    pha                     ; save it
    jsr io_get_byte
    bcs @end_pop            ; return in case of errors in get_byte
    jsr parse_hex_nibble    ; parse the least significant nibble
    bcs @end_pop
    tsx
    ora $0100+1,x   ; 'or' with the high nibble on stack
@end_pop:
    plx             ; pop the high nibble from the stack
@end:
    plx
    rts

; input: A: 4-bit hex
; output: A: 0 to 15
; success: C==0, error: C==1
parse_hex_nibble:
    sec
    sbc #'0'    ; A = A-'0'
    bcc @bad    ; A < 0  -> bad
    cmp #10     ; A < 10 -> ok
    bcc @ok
    sbc #('A'-'0'-10) ; A = (A-'0')+'0'-'A'+10 == A-'A'+10
    cmp #10
    bcc @bad    ; A < 10 -> bad
    cmp #16     ; A < 16 -> ok
    bcc @ok
    sbc #('a'-'A') ; A = ((A-'0')+'0'-'A'+10)+'A'-'a' == A-'a'+10
    cmp #10
    bcc @bad    ; A < 0 -> bad
    cmp #16     ; A < 16 -> ok
    bcc @ok
@bad:
    sec         ; indicate failure
@ok:
    rts
