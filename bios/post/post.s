.include "via.inc"
.include "irq.inc"
.include "lcd.inc"

POST_STAGE_ZP = 0
POST_STAGE_STACK = 1
POST_STAGE_IRQ = 2
POST_STAGE_RAM = 3

.import test_zp
.import test_stack
.import test_ram
.import test_irq
.import test_irq_handler

.export after_test_zp
.export after_test_stack
.exportzp STATUS_STR

.export post
.import after_post

.rodata
STR_TEST_ZP:   .asciiz "Z"
STR_TEST_STACK:.asciiz "S"
STR_TEST_RAM:  .asciiz "R"
STR_TEST_IRQ:  .asciiz "I"
STR_TEST_OK:   .asciiz "OK"
STR_TEST_FAIL: .asciiz "FAIL"

.segment "ZPTMP": zeropage
; these must be on zero page to avoid being garbled by memory tests
; we take care of them when testing zp
POST_STAGE: .res 1
STATUS_STR: .res 2

.macro my_lcd_wait
    .local lcd_wait
lcd_wait:
    bit LCD_INSTR
    bmi lcd_wait ; bit 7 is one (busy)? continue waiting
.endmacro

.macro my_lcd_print str
    .local loop
    .local end
    ldy #0
loop:
    lda str, y
    beq end
    sta LCD_DATA
    my_lcd_wait
    iny
    bne loop
end:
.endmacro

.macro my_lcd_init
    lda #%00111000   ; set 8-bit operation, 2 lines, 5x7
    ; call it 3 times for proper set up while powering up
    sta LCD_INSTR
    my_lcd_wait
    sta LCD_INSTR
    my_lcd_wait
    sta LCD_INSTR
    my_lcd_wait
    lda #%110     ; entry mode set: increment, do not shift
    sta LCD_INSTR
    my_lcd_wait
    lda #%1110   ; display on, cursor on, blink off
    sta LCD_INSTR
    my_lcd_wait
    lda #$80     ; set cursor to start of first line
    sta LCD_INSTR
    my_lcd_wait
    lda #1        ; clear display
    sta LCD_INSTR
    my_lcd_wait
.endmacro

.code
post:
    ; indicate no error
    stz STATUS_STR

    ; disable interrupts
    sei

    ; Set led pins to output (hopefully it works!)
    lda #(VIA_LED_GREEN+VIA_LED_RED)
    tsb VIA_DIR_B

    ; Turn on red and green leds
    lda #(VIA_LED_GREEN+VIA_LED_RED)
    sta VIA_IO_B

    my_lcd_init

    ; ---------------------------------------------------------------------------
    ; Test zeropage 
    ; ---------------------------------------------------------------------------
    lda #POST_STAGE_ZP
    sta POST_STAGE
    my_lcd_print STR_TEST_ZP
    jmp test_zp
after_test_zp:
    ; STATUS_STR might be garbled, use A to check if failed
    cmp #0
    bne post_failure

    ; from now on we can use zeropage
    stz STATUS_STR ; might have been garbled, redefine it

    ; ---------------------------------------------------------------------------
    ; Test stack 
    ; ---------------------------------------------------------------------------
    lda #POST_STAGE_STACK
    sta POST_STAGE
    my_lcd_print STR_TEST_STACK
    jmp test_stack
after_test_stack:
    cmp #0
    bne post_failure

    ; ---------------------------------------------------------------------------
    ; Test ram
    ; ---------------------------------------------------------------------------
    lda #POST_STAGE_RAM
    sta POST_STAGE
    my_lcd_print STR_TEST_RAM
    jsr test_ram
    lda (STATUS_STR) ; any error?
    bne post_failure     ; yes, go to end

    ; ---------------------------------------------------------------------------
    ; Test IRQ
    ; ---------------------------------------------------------------------------
    lda #POST_STAGE_IRQ
    sta POST_STAGE
    my_lcd_print STR_TEST_IRQ
    jsr test_irq
    lda (STATUS_STR) ; any error?
    bne post_failure     ; yes, go to end

    ; ---------------------------------------------------------------------------
    ; Wrap up 
    ; ---------------------------------------------------------------------------

post_success:
    lda #($80+$40) ; cursor to 2nd line
    sta LCD_INSTR
    jsr lcd_wait
    lcd_print STR_TEST_OK

    lda #VIA_LED_GREEN
    sta VIA_IO_B

    lda #0 ; indicate success
    jmp after_post

post_failure:
    lda #($80+$40) ; cursor to 2nd line
    sta LCD_INSTR
    my_lcd_wait
    my_lcd_print (STATUS_STR)

    lda #VIA_LED_RED
    sta VIA_IO_B

    lda #1 ; indicate failure
    jmp after_post
