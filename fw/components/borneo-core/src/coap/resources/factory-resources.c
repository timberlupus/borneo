#include <esp_system.h>
#include <esp_event.h>
#include <esp_log.h>
#include <esp_mac.h>
#include <nvs_flash.h>
#include <sys/socket.h>

#include "coap3/coap.h"
#include <cbor.h>

#include <borneo/rtc.h>
#include <borneo/ntc.h>
#include <borneo/common.h>
#include <borneo/coap.h>
#include <borneo/wifi.h>
#include <borneo/system.h>
#include <borneo/power.h>
#include <borneo/nvs.h>

#define TAG "borneo-core-coap"

static void coap_hnd_borneo_factory_reset_post(coap_resource_t* resource, coap_session_t* session,
                                               const coap_pdu_t* request, const coap_string_t* query,
                                               coap_pdu_t* response)
{
    BO_COAP_TRY(bo_power_shutdown(0), response);
    BO_COAP_TRY(bo_wifi_forget(), response);

    BO_COAP_TRY(bo_system_factory_reset(), response);

    // First, return the result, wait for three seconds, and then restart.
    bo_system_reboot_later(5000);

    coap_pdu_set_code(response, COAP_RESPONSE_CODE(204));
}

COAP_RESOURCE_DEFINE("borneo/factory/reset", false, NULL, coap_hnd_borneo_factory_reset_post, NULL, NULL);