#include <string.h>
#include <time.h>

#include "borneo/common.h"
#include "borneo/cron.h"
#include "borneo/utils/bit-utils.h"

void cron_init(struct cron* self) { memset(self, 0, sizeof(struct cron)); }

bool cron_is_valid(const struct cron* self, const struct tm* rtc)
{
    bool months_matched = get_bit_u16(self->months, rtc->tm_mon);
    bool dom_matched = get_bit_u32(self->dom, rtc->tm_mday);
    bool dow_matched = get_bit_u8(self->dow, rtc->tm_wday);
    bool hour_matched = get_bit_u32(self->hours, rtc->tm_hour);
    bool minute_matched = get_bit_u64(self->minutes, rtc->tm_min);
    return months_matched && dom_matched && minute_matched && hour_matched && dow_matched;
}