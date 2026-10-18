#ifndef DDS_H
#define DDS_H

#include <stdint.h>

#define DDS_CHANNELS   8u
#define DDS_CLK_HZ     100000000u
#define DDS_AMP_FULL   0x8000u

void     dds_init(void);
void     dds_configure(unsigned ch, uint32_t ftw, uint32_t phase, uint32_t amp);
void     dds_enable(uint32_t channel_mask);
void     dds_sync(void);
int16_t  dds_sample(unsigned ch);
unsigned dds_self_test(void);

#endif
