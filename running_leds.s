START_ROM = $8000
DIR_B = $6002
STORE_B = $6000

 .org START_ROM

reset:
 lda #$ff
 sta DIR_B

 lda #$01
begin:
 sta STORE_B
 jsr rotate
 jmp begin

rotate:
 rol
 rts

 .org $fffc
 .word reset
 .word $0000

