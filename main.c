#include <avr/io.h>

/*
 * Sends an array of colors to a pin which is connected to the data line of a WS2812 processor.
 *
 * len must divisible by 3, or unexpected behaviour may occur. This is not checked.
 *
 * data must be an array with the following format, where i is the LED #, and the color is expressed in GRB 0-255:
 * <pre>
 * data[i] = G
 * data[i + 1] = R
 * data[i + 2] = B
 * </pre>
 *
 * The WS2812 protocol requires a 300 us delay between sending out a data buffer to allow for reset.
 * This method does NOT include that delay.
 */
extern void send_bits(uint16_t len, uint8_t *data);

// IMPORTANT - NEED TO CHANGE IN ASSEMBLY FILE AS WELL
#define PIN_NUMBER PB4

#define NUM_LEDS 10
#define LEN (NUM_LEDS * 3)

int main(void) {
    DDRB |= (1 << PB4);   // make pin output

    uint8_t leds[LEN] = {0};

    // make led 0 green
    leds[0] = 255;

    // make led 1 red
    leds[1*3 + 1] = 255;

    // make led 2 blue
    leds[2*3 + 2] = 255;

    // make led 9 white
    leds[9*3] = 255;
    leds[9*3 + 1] = 255;
    leds[9*3 + 2] = 255;

    // write it out (must wait 300 us between calls to this method as part of WS2812 protocol)
    send_bits(LEN, leds);

    return 0;
}
