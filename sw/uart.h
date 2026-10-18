#ifndef UART_H
#define UART_H

#include <stdint.h>

char uart_getc(void);
void uart_putc(char c);
void uart_puts(const char *s);
void uart_put_uint(uint64_t value);
void uart_put_fixed(uint64_t value, unsigned decimals);

#endif
