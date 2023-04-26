#ifndef PIGPIO_H
#define PIGPIO_H

#if defined(__cplusplus)
extern "C" {
#endif

#define PI_OUTPUT 0

#define PI_LOW 0
#define PI_HIGH 1

int gpioInitialise();
int gpioWrite(unsigned char line, unsigned char value);
int gpioSetMode(unsigned char line, unsigned char mode);
int gpioTerminate();

#if defined(__cplusplus)
}
#endif

#endif
