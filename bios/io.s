.include "io.inc"

.data
io_cb_put_char: .res 2

.rodata
IO_HEXASCII: .byte "0123456789ABCDEF"

.zeropage
ptr: .res 2

STACK_SEG = $0100

.code
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
io_put_char:
    jmp (io_cb_put_char) ; tail-call optimization

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
    jsr io_put_char             ; send character
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
