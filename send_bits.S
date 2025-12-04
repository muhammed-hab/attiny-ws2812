; send_bits.S
; void send_bits(uint16_t len, uint8_t *data)
; Arguments:
;   r24:r25 = length in bytes (first bc r24:r25 is valid for sbiw, r22:r23 is not)
;   r22:r23 = pointer to data

    .global send_bits
    .text

send_bits:
    ; r24:r25 = len
    ; r22:r23 = ptr
    movw r30, r22          ; 1 clock, Z = r31:30

    ; check for 0 len
    sbiw r24, 0
    brne load_first_byte
    ret

load_first_byte:
    ld   r20, Z+           ; load first byte - *data++, Z = r31:r30   2 clock
    
output_byte:

; CHANGE PIN NUMBER HERE
.equ pin_num, 4

; bit 7
    sbi 0x18, pin_num ; on, 2 clocks
    sbrs r20, 7 ; skip if on
    cbi 0x18, pin_num ; off, 2 clocks
    nop
    sbrc r20, 7 ; skip if off
    cbi 0x18, pin_num ; off, 2 clocks        
    nop
    nop

; bit 6
    sbi 0x18, pin_num ; on, 2 clocks
    sbrs r20, 6 ; skip if on
    cbi 0x18, pin_num ; off, 2 clocks
    nop
    sbrc r20, 6 ; skip if off
    cbi 0x18, pin_num ; off, 2 clocks        
    nop
    nop

; bit 5
    sbi 0x18, pin_num ; on, 2 clocks
    sbrs r20, 5 ; skip if on
    cbi 0x18, pin_num ; off, 2 clocks
    nop
    sbrc r20, 5 ; skip if off
    cbi 0x18, pin_num ; off, 2 clocks        
    nop
    nop

; bit 4
    sbi 0x18, pin_num ; on, 2 clocks
    sbrs r20, 4 ; skip if on
    cbi 0x18, pin_num ; off, 2 clocks
    nop
    sbrc r20, 4 ; skip if off
    cbi 0x18, pin_num ; off, 2 clocks        
    nop
    nop

; bit 3
    sbi 0x18, pin_num ; on, 2 clocks
    sbrs r20, 3 ; skip if on
    cbi 0x18, pin_num ; off, 2 clocks
    nop
    sbrc r20, 3 ; skip if off
    cbi 0x18, pin_num ; off, 2 clocks        
    sbiw r24, 1 ; decr len, 2 clocks

; bit 2
    sbi 0x18, pin_num ; on, 2 clocks
    sbrs r20, 2 ; skip if on
    cbi 0x18, pin_num ; off, 2 clocks
    nop
    sbrc r20, 2 ; skip if off
    cbi 0x18, pin_num ; off, 2 clocks        
    ; branch here so next byte is not loaded at end
    breq finish_and_end ; 1 clock if not jump, 2 if jump
    nop ; extra clock if not jump

; bit 1
    sbi 0x18, pin_num ; on, 2 clocks
    sbrs r20, 1 ; skip if on
    cbi 0x18, pin_num ; off, 2 clocks
    mov r19, r20 ; back up current byte
    sbrc r20, 1 ; skip if off
    cbi 0x18, pin_num ; off, 2 clocks        
    ld   r20, Z+ ; load next byte - *data++, Z = r30:r31   2 clock

; bit 0
    sbi 0x18, pin_num ; on, 2 clocks
    sbrs r19, 0 ; skip if on
    cbi 0x18, pin_num ; off, 2 clocks
    nop
    sbrc r19, 0 ; skip if off
    cbi 0x18, pin_num ; off, 2 clocks        
    rjmp output_byte ; 2 clocks, cont loop

finish_and_end:
; 2 bits remaining after length check and jump
; bit 1
    sbi 0x18, pin_num ; on, 2 clocks
    sbrs r20, 1 ; skip if on
    cbi 0x18, pin_num ; off, 2 clocks
    nop
    sbrc r20, 1 ; skip if off
    cbi 0x18, pin_num ; off, 2 clocks        
    nop
    nop

; bit 0
    sbi 0x18, pin_num ; on, 2 clocks
    sbrs r20, 0 ; skip if on
    cbi 0x18, pin_num ; off, 2 clocks
    nop
    sbrc r20, 0 ; skip if off
    cbi 0x18, pin_num ; off, 2 clocks        
    nop
    nop

    ret