#include <esp_system.h>
#include <esp_event.h>
#include <esp_log.h>
#include <esp_ota_ops.h>
#include <esp_mac.h>
#include <nvs_flash.h>
#include <sys/socket.h>

#include "coap3/coap.h"
#include <cbor.h>

#include <borneo/rtc.h>
#include <borneo/common.h>
#include <borneo/coap.h>
#include <borneo/wifi.h>
#include <borneo/system.h>
#include <borneo/power.h>
#include <borneo/nvs.h>
#include "../power-meas.h"

#define TAG "lyfi-power-coap"

#if CONFIG_BORNEO_MEAS_VOLTAGE_SUPPORT && CONFIG_LYFI_MEAS_CURRENT_SUPPORT
static void coap_hnd_power_meas_power_get(coap_resource_t* resource, coap_session_t* session, const coap_pdu_t* request,
                                          const coap_string_t* query, coap_pdu_t* response)
{
    CborEncoder encoder;
    size_t encoded_size = 0;
    uint8_t buf[32] = { 0 };
    int32_t power_mw;
    cbor_encoder_init(&encoder, buf, sizeof(buf), 0);
    BO_COAP_TRY(lyfi_power_read(&power_mw), response);
    BO_COAP_TRY(cbor_encode_uint(&encoder, power_mw), response);
    encoded_size = cbor_encoder_get_buffer_size(&encoder, buf);

    coap_add_data_blocked_response(request, response, COAP_MEDIATYPE_APPLICATION_CBOR, 0, encoded_size, buf);

    coap_pdu_set_code(response, COAP_RESPONSE_CODE_CONTENT);
    return;
}
#endif // CONFIG_BORNEO_MEAS_VOLTAGE_SUPPORT && CONFIG_LYFI_MEAS_CURRENT_SUPPORT

#if CONFIG_BORNEO_MEAS_VOLTAGE_SUPPORT && CONFIG_LYFI_MEAS_CURRENT_SUPPORT
COAP_RESOURCE_DEFINE("lyfi/power/meas/power", false, coap_hnd_power_meas_power_get, NULL, NULL, NULL);
#endif // CONFIG_BORNEO_MEAS_VOLTAGE_SUPPORT && CONFIG_LYFI_MEAS_CURRENT_SUPPORT