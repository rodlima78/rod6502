.include "io.inc"

.data
io_cb_put_char: .res 2

.rodata
IO_HEXASCII: .byte "0123456789ABCDEF"

; =============================================
; input: A = byte to be output as hex string
io_hex:
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
