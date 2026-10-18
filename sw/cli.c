#include <stdbool.h>
#include <stdint.h>
#include "cli.h"
#include "dds.h"
#include "uart.h"

#define LINE_MAX            128u

#define FREQ_DECIMALS       6u
#define FREQ_PRINT_DECIMALS 3u
#define AMP_DECIMALS        6u
#define PHASE_DECIMALS      3u

#define FREQ_MAX_MILLIHZ        ((uint64_t)DDS_CLK_HZ / 2u * 1000u)
#define AMP_FULL_SCALE_UV   1650000u
#define AMP_CHANNEL_MAX_UV  1000000u
#define AMP_SUM_MAX_UV      AMP_FULL_SCALE_UV
#define PHASE_FULL_MDEG     360000u

#define FTW_PER_MILLIHZ_E9      42949673ull

typedef struct {
    uint64_t freq_millihz;
    uint32_t amp_uv;
    uint32_t phase_mdeg;
} tone_t;

static uint32_t freq_to_ftw(uint64_t freq_millihz)
{
    return (uint32_t)((freq_millihz * FTW_PER_MILLIHZ_E9 + 500000000ull) / 1000000000ull);
}

static uint32_t amp_to_code(uint32_t amp_uv)
{
    return (uint32_t)(((uint64_t)amp_uv * DDS_AMP_FULL + AMP_FULL_SCALE_UV / 2) / AMP_FULL_SCALE_UV);
}

static uint32_t phase_to_word(uint32_t phase_mdeg)
{
    return (uint32_t)(((uint64_t)phase_mdeg << 32) / PHASE_FULL_MDEG);
}

static bool is_digit(char c)
{
    return c >= '0' && c <= '9';
}

static bool is_decimal_separator(char c)
{
    return c == '.' || c == ',';
}

static bool parse_fixed(const char **cursor, unsigned decimals, uint64_t *value)
{
    const char *s = *cursor;
    uint64_t result = 0;
    unsigned fraction = 0;
    bool any = false;

    while (is_digit(*s)) {
        result = result * 10 + (uint64_t)(*s++ - '0');
        any = true;
    }
    if (is_decimal_separator(*s)) {
        s++;
        while (is_digit(*s)) {
            if (fraction < decimals) {
                result = result * 10 + (uint64_t)(*s - '0');
                fraction++;
            }
            s++;
            any = true;
        }
    }
    while (fraction++ < decimals)
        result *= 10;

    *cursor = s;
    *value = result;
    return any;
}

static bool parse_tone(const char **cursor, tone_t *tone)
{
    uint64_t freq, amp, phase = 0;

    if (!parse_fixed(cursor, FREQ_DECIMALS, &freq) || **cursor != ':')
        return false;
    (*cursor)++;
    if (!parse_fixed(cursor, AMP_DECIMALS, &amp))
        return false;
    if (**cursor == ':') {
        (*cursor)++;
        if (!parse_fixed(cursor, PHASE_DECIMALS, &phase))
            return false;
    }
    if (**cursor != ' ' && **cursor != '\0')
        return false;

    tone->freq_millihz = freq;
    tone->amp_uv = (uint32_t)(amp > UINT32_MAX ? UINT32_MAX : amp);
    tone->phase_mdeg = (uint32_t)(phase > UINT32_MAX ? UINT32_MAX : phase);
    return true;
}

static const char *skip_spaces(const char *s)
{
    while (*s == ' ')
        s++;
    return s;
}

static bool streq(const char *a, const char *b)
{
    while (*a && *a == *b) {
        a++;
        b++;
    }
    return *a == *b;
}

static void print_volts(uint64_t uv)
{
    uart_put_fixed((uv + 500) / 1000, 3);
    uart_puts(" V");
}

static void print_tones(const tone_t *tones, unsigned count)
{
    for (unsigned ch = 0; ch < count; ch++) {
        uart_puts("  ch");
        uart_put_uint(ch);
        uart_puts("  ");
        uart_put_fixed(tones[ch].freq_millihz / 1000u, FREQ_PRINT_DECIMALS);
        uart_puts(" kHz  ");
        print_volts(tones[ch].amp_uv);
        uart_puts("  ");
        uart_put_fixed(tones[ch].phase_mdeg, PHASE_DECIMALS);
        uart_puts(" deg\n");
    }
    if (!count)
        uart_puts("  all channels off\n");
}

static void apply_tones(const tone_t *tones, unsigned count)
{
    uint32_t mask = 0;

    dds_enable(0);
    for (unsigned ch = 0; ch < DDS_CHANNELS; ch++) {
        if (ch < count) {
            dds_configure(ch, freq_to_ftw(tones[ch].freq_millihz),
                          phase_to_word(tones[ch].phase_mdeg), amp_to_code(tones[ch].amp_uv));
            mask |= 1u << ch;
        } else {
            dds_configure(ch, 0, 0, 0);
        }
    }
    dds_enable(mask);
    dds_sync();
}

static void print_help(void)
{
    uart_puts("usage: <freq_kHz>:<amp_V>[:<phase_deg>] ...   up to 8 tones, one per channel\n"
              "       decimal separator '.' or ',', e.g. 1,5 kHz = 1500 Hz\n"
              "       e.g. 1:0.8 3:0.267 5:0.16\n"
              "       off    all channels off\n"
              "       help   this text\n"
              "limits: amplitude <= 1.000 V per channel, sum <= 1.650 V, frequency < 50000 kHz\n");
}

static void error_at_tone(unsigned index, const char *message)
{
    uart_puts("error: tone ");
    uart_put_uint(index + 1);
    uart_puts(": ");
    uart_puts(message);
    uart_puts(", line ignored\n");
}

static void handle_line(const char *line)
{
    tone_t tones[DDS_CHANNELS];
    unsigned count = 0;
    uint64_t amp_sum_uv = 0;
    const char *s = skip_spaces(line);

    if (*s == '\0')
        return;
    if (streq(s, "help")) {
        print_help();
        return;
    }
    if (streq(s, "off")) {
        apply_tones(tones, 0);
        print_tones(tones, 0);
        return;
    }

    while (*s) {
        if (count == DDS_CHANNELS) {
            uart_puts("error: more than 8 tones, line ignored\n");
            return;
        }
        if (!parse_tone(&s, &tones[count])) {
            error_at_tone(count, "expected <freq_kHz>:<amp_V>[:<phase_deg>]");
            return;
        }
        if (tones[count].freq_millihz >= FREQ_MAX_MILLIHZ) {
            error_at_tone(count, "frequency must be below 50000 kHz");
            return;
        }
        if (tones[count].amp_uv > AMP_CHANNEL_MAX_UV) {
            error_at_tone(count, "amplitude above 1.000 V");
            return;
        }
        tones[count].phase_mdeg %= PHASE_FULL_MDEG;
        amp_sum_uv += tones[count].amp_uv;
        count++;
        s = skip_spaces(s);
    }

    if (amp_sum_uv > AMP_SUM_MAX_UV) {
        uart_puts("warning: amplitude sum ");
        print_volts(amp_sum_uv);
        uart_puts(" exceeds 1.650 V full scale, output would clip, line ignored\n");
        return;
    }

    apply_tones(tones, count);
    print_tones(tones, count);
}

static unsigned read_line(char *line, unsigned size)
{
    unsigned length = 0;

    for (;;) {
        char c = uart_getc();

        if (c == '\r' || c == '\n') {
            uart_putc('\n');
            line[length] = '\0';
            return length;
        }
        if ((c == '\b' || c == 0x7f) && length) {
            length--;
            uart_puts("\b \b");
        } else if (c >= ' ' && c < 0x7f && length < size - 1) {
            line[length++] = c;
            uart_putc(c);
        }
    }
}

void cli_run(void)
{
    char line[LINE_MAX];

    uart_puts("type 'help' for usage\n");
    for (;;) {
        uart_puts("dds> ");
        read_line(line, sizeof line);
        handle_line(line);
    }
}
