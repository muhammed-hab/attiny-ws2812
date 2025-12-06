# WS2812 Control Using an Attiny85

*This project demonstrates how to drive WS2812 / WS2812B addressable LEDs using an ATtiny85.  
The same approach should work on other ATtiny/ATmega MCUs (including Arduino-class chips),  
but timing is extremely sensitive, so adjustments may be required depending on clock speed.*

This project was used to build my EKG Halloween costume: [http://youtu.be/Ntg1BN4ZSDc](http://youtu.be/Ntg1BN4ZSDc)

---

## Running the Code

To compile and flash the assembly/C code using Clang and avrdude:

```
clang -mmcu=attiny85 -Os -c send_bits.S -o send_bits.o
clang -mmcu=attiny85 -Os -c main.c -o main.o
avr-ld -mmcu=attiny85 send_bits.o main.o -o main.elf
avr-objcopy -O ihex main.elf main.hex
avrdude -c linuxspi -p t85 -U flash:w:main.hex
```

If you are flashing via a USB programmer such as USBtinyISP, replace `linuxspi` with `usbtiny`.

Modify `-mmcu=` and the programmer option as needed.

---

## Verifying MCU Clock Speed

The WS2812 timing depends on an **8 MHz system clock**.  
On a new ATtiny85, you must burn the fuse to disable the divide-by-8 prescaler:

Set fuse (change programmer if needed):

```
avrdude -c linuxspi -p t85 -U lfuse:w:0xE2:m
```

Verify fuse:

```
avrdude -c linuxspi -p t85 -U lfuse:r:-:h
```

You should see **0xE2** for an 8 MHz configuration.

---

## Simple Timing-Check Program

Use this small assembly snippet to confirm the ATtiny really runs at ~8 MHz.
It toggles a pin HIGH for ~1 second by executing a loop containing ~8 million cycles.

This code is untested, so minor adjustments may be needed:

```
.equ pin_num, 4
sbi 0x17, pin_num   ; DDRB |= (1<<pin)

ldi r18, 0
ldi r19, 0
ldi r20, 25         ; 256 * 256 * 5 * 25 ≈ 8,000,000 cycles

sbi 0x18, pin_num   ; PORTB |= (1<<pin)

loop:
subi r18, 1     ; 1 cycle
sbci r19, 0     ; 1 cycle
sbci r20, 0     ; 1 cycle
brne loop       ; 2 cycles when branching
; total: 5 cycles per loop
cbi 0x18, pin_num   ; PORTB &= ~(1<<pin)
```

If the clock is correct, an LED on the pin will turn on, stay lit for ~1 second, then turn off.

---

## WS2812 Protocol Overview

Each WS2812 LED expects **24 bits** in order:  
**Green -> Red -> Blue**, MSB first.

LEDs aren’t individually addressed. Instead, each LED consumes the first 24 bits it receives and passes the rest down the chain:

`Data In -> LED1 -> LED2 -> LED3`


To control 3 LEDs you transmit:

- 24 bits for LED3
- 24 bits for LED2
- 24 bits for LED1
- then a reset pulse (LOW for ≥ 300 µs)

---

## Bit Timing Requirements

Each bit is always 1.25 µs long:

| Bit | High Time | Low Time |
|-----|-----------|----------|
| 1   | ~0.8 µs   | ~0.45 µs |
| 0   | ~0.4 µs   | ~0.85 µs |

At 8 MHz, each instruction cycle = 0.125 µs, so timing must be exact.  
This is why the code is written in raw AVR assembly.

*Note: WS2812 allows for ~10% variation in these timings. However, the internal oscillator in an Attiny varies by +- 10% from the factory, so the code tries to get timings as exact as possible despite it being less convenient.*

---

## Implementing the Bit Timing

The essential idea:

- Test whether a bit is set using `sbrs/sbrc` (skip \[next instruction\] if bit in register is set/cleared)
- Set output high using `sbi`
- Insert a precise number of `nop` instructions
- Set output low using `cbi`
- Add padding NOPs so each bit lasts exactly 1.25 µs

Here is an example of writing a single bit:

```
    sbi 0x18, pin_num ; on, 2 clocks
    sbrs r20, bit_num ; skip if on
    cbi 0x18, pin_num ; off, 2 clocks
    nop
    sbrc r20, bit_num ; skip if off
    cbi 0x18, pin_num ; off, 2 clocks        
    nop
    nop
```

Because the sbrs/sbrc instruction uses 1 or 2 clock cycles depending on if it skips, let's run through both scenarios:

| instruction       | clock cycles consumed if bit set | cumulative clocks if bit set | clock cycles consumed if bit unset | cumulative clocks if bit unset |
|-------------------|----------------------------------|------------------------------|------------------------------------|--------------------------------|
|                   |                                  | 0                            |                                    | 0                              |
| sbi 0x18, pin_num | 2                                |                              | 2                                  |                                |
|                   |                                  | 2 (0.25 us)                  |                                    | 2 (0.25 us)                    |
| sbrs r20, bit_num | 2                                |                              | 1                                  |                                |
|                   |                                  | 4 (0.5 us)                   |                                    | 3 (0.375 us)                   |
| cbi 0x18, pin_num | 0 (skipped)                      |                              | 2                                  |                                |
|                   |                                  | 4 (0.5 us)                   |                                    | 5 (0.625 us)                   |
| nop               | 1                                |                              | 1                                  |                                |
|                   |                                  | 5 (0.625 us)                 |                                    | 6 (0.75 us)                    |
| sbrc r20, bit_num | 1                                |                              | 2                                  |                                |
|                   |                                  | 6 (0.75 us)                  |                                    | (8 (1 us)                      |
| cbi 0x18, pin_num | 2                                |                              | 0 (skipped)                        |                                |
|                   |                                  | 8 (1 us)                     |                                    | 8 (1us)                        |
| nop               | 1                                |                              | 1                                  |                                |
|                   |                                  | 9 (1.125 us)                 |                                    | 9 (1.125 us)                   |
| nop               | 1                                |                              | 1                                  |                                |
|                   |                                  | 10 (1.25 us)                 |                                    | 10 (1.25 us)                   |

We can see that if the bit is set, we set pin to HIGH at 0 us and LOW at 0.75 us, and if the bit is not set, HIGH at 0 and LOW at 0.375 us, 
and both scenarios take 1.25 us, complying with the above specification.

---

## Loop Unrolling

A major challenge is that WS2812 timing leaves only **3 spare cycles** per bit for overhead.  
This is not enough to:

- Shift to the next bit
- Detect if all bits in the byte have been written
    - Need to decrement counter & branch
- Detect the end of the byte array
    - Need to decrement counter & branch
- Load the next byte

**Solution: unroll the loop for all 8 bits.**

This eliminates shifting and looping within a byte.  
Each unrolled bit slot has 3 spare cycles that can be used to help load the next byte.

## Loading the Next Byte

Loading the next byte requires several instructions that manage the loop state and byte pointer:

Use `sbiw` to decrement the remaining byte count (2 cycles).

Use `breq` to exit the loop when the count reaches zero (1–2 cycles).

Use `ld` to load the next byte from memory and auto-increment the pointer (2 cycles).

Use `rjmp` to jump back to the beginning of the loop (2 cycles).

These instructions can be distributed across multiple unrolled loop segments. The `breq` instruction does not need to appear immediately after `sbiw`, as long as no instructions in between modify the zero flag.

The code also backs up the register containing the current byte as some bits still have not been written when the next byte is loaded.

---

# References

[https://ww1.microchip.com/downloads/en/devicedoc/atmel-2586-avr-8-bit-microcontroller-attiny25-attiny45-attiny85_datasheet.pdf](https://ww1.microchip.com/downloads/en/devicedoc/atmel-2586-avr-8-bit-microcontroller-attiny25-attiny45-attiny85_datasheet.pdf)

[https://ww1.microchip.com/downloads/en/DeviceDoc/AVR-InstructionSet-Manual-DS40002198.pdf](https://ww1.microchip.com/downloads/en/DeviceDoc/AVR-InstructionSet-Manual-DS40002198.pdf)

[https://www.arrow.com/en/research-and-events/articles/protocol-for-the-ws2812b-programmable-led](https://www.arrow.com/en/research-and-events/articles/protocol-for-the-ws2812b-programmable-led)

[https://gcc.gnu.org/wiki/avr-gcc](https://gcc.gnu.org/wiki/avr-gcc)
