#include "uart.h"
#include "xil_io.h"

#define UART_BASE       0x40600000u
#define UART_RX_FIFO    (UART_BASE + 0x0u)
#define UART_TX_FIFO    (UART_BASE + 0x4u)
#define UART_STATUS     (UART_BASE + 0x8u)
#define STATUS_RX_VALID 0x01u
#define STATUS_TX_FULL  0x08u

char uart_getc(void)
{
    while (!(Xil_In32(UART_STATUS) & STATUS_RX_VALID))
        ;
    return (char)Xil_In32(UART_RX_FIFO);
}

void uart_putc(char c)
{
    if (c == '\n')
        uart_putc('\r');
    while (Xil_In32(UART_STATUS) & STATUS_TX_FULL)
        ;
    Xil_Out32(UART_TX_FIFO, (uint32_t)(unsigned char)c);
}

void uart_puts(const char *s)
{
    while (*s)
        uart_putc(*s++);
}

void uart_put_uint(uint64_t value)
{
    char digits[21];
    unsigned n = 0;

    do {
        digits[n++] = (char)('0' + value % 10);
        value /= 10;
    } while (value);
    while (n)
        uart_putc(digits[--n]);
}

void uart_put_fixed(uint64_t value, unsigned decimals)
{
    uint64_t scale = 1;

    for (unsigned i = 0; i < decimals; i++)
        scale *= 10;
    uart_put_uint(value / scale);
    if (!decimals)
        return;
    uart_putc('.');
    for (uint64_t div = scale / 10; div; div /= 10)
        uart_putc((char)('0' + (value / div) % 10));
}
