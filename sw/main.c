#include "cli.h"
#include "dds.h"
#include "uart.h"

int main(void)
{
    unsigned errors;

    dds_init();
    errors = dds_self_test();

    uart_puts("\n8-channel DDS sine synthesizer\n");
    uart_puts(errors ? "self-test: FAIL\n" : "self-test: PASS\n");

    cli_run();
    return 0;
}
