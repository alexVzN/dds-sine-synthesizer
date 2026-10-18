#include "dds.h"
#include "xil_io.h"

#define DDS_BASE        0x44A00000u
#define DDS_STRIDE      0x00010000u

#define REG_FTW         0x00u
#define REG_PHASE       0x04u
#define REG_AMP         0x08u
#define REG_CTRL        0x0Cu
#define REG_SAMPLE      0x10u

#define CTRL_OFF        0x0u
#define CTRL_ENABLE     0x1u
#define CTRL_STEP       0x2u
#define CTRL_LOAD       0x4u

#define SYNC_GPIO_DATA  0x40000000u
#define SYNC_GPIO_TRI   0x40000004u

static uint32_t reg_addr(unsigned ch, uint32_t reg)
{
    return DDS_BASE + ch * DDS_STRIDE + reg;
}

static void reg_write(unsigned ch, uint32_t reg, uint32_t value)
{
    Xil_Out32(reg_addr(ch, reg), value);
}

void dds_init(void)
{
    Xil_Out32(SYNC_GPIO_TRI, 0);
    Xil_Out32(SYNC_GPIO_DATA, 0);
    for (unsigned ch = 0; ch < DDS_CHANNELS; ch++)
        dds_configure(ch, 0, 0, 0);
}

void dds_configure(unsigned ch, uint32_t ftw, uint32_t phase, uint32_t amp)
{
    reg_write(ch, REG_CTRL, CTRL_OFF);
    reg_write(ch, REG_FTW, ftw);
    reg_write(ch, REG_PHASE, phase);
    reg_write(ch, REG_AMP, amp);
}

void dds_enable(uint32_t channel_mask)
{
    for (unsigned ch = 0; ch < DDS_CHANNELS; ch++)
        reg_write(ch, REG_CTRL, (channel_mask >> ch) & 1u ? CTRL_ENABLE : CTRL_OFF);
}

void dds_sync(void)
{
    Xil_Out32(SYNC_GPIO_DATA, 1);
    Xil_Out32(SYNC_GPIO_DATA, 0);
}

int16_t dds_sample(unsigned ch)
{
    (void)Xil_In32(reg_addr(ch, REG_CTRL));
    return (int16_t)Xil_In32(reg_addr(ch, REG_SAMPLE));
}

static unsigned check_steps(unsigned ch, uint32_t ftw, uint32_t phase, uint32_t amp,
                            const int16_t *expected, unsigned count)
{
    unsigned errors = 0;

    dds_configure(ch, ftw, phase, amp);
    reg_write(ch, REG_CTRL, CTRL_LOAD);
    for (unsigned i = 0; i < count; i++) {
        if (i > 0)
            reg_write(ch, REG_CTRL, CTRL_STEP);
        if (dds_sample(ch) != expected[i])
            errors++;
    }
    dds_configure(ch, 0, 0, 0);
    return errors;
}

unsigned dds_self_test(void)
{
    static const int16_t quarter_period[8] = { 0, 32767, 0, -32767, 0, 32767, 0, -32767 };
    static const int16_t half_cosine[8]    = { 16383, 11585, 0, -11585, -16384, -11585, 0, 11585 };

    return check_steps(0, 0x40000000u, 0x00000000u, DDS_AMP_FULL, quarter_period, 8)
         + check_steps(1, 0x20000000u, 0x40000000u, DDS_AMP_FULL / 2, half_cosine, 8);
}
