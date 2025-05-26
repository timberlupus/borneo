#include <esp_system.h>
#include <esp_event.h>
#include <esp_log.h>
#include <esp_ota_ops.h>
#include <esp_mac.h>
#include <esp_timer.h>
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
#include <borneo/power-meas.h>

#define TAG "borneo-core-coap"

static void coap_hnd_borneo_info_get(coap_resource_t* resource, coap_session_t* session, const coap_pdu_t* request,
                                     const coap_string_t* query, coap_pdu_t* response)
{

    uint8_t buf[1024];
    size_t encoded_size = 0;

    CborEncoder encoder;
    cbor_encoder_init(&encoder, buf, sizeof(buf), 0);

    const struct system_info* sysinfo = bo_system_get_info();

    CborEncoder root_map;
    BO_COAP_TRY(cbor_encoder_create_map(&encoder, &root_map, CborIndefiniteLength), response);

    {
        BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "id"), response);
        BO_COAP_TRY(cbor_encode_text_stringz(&root_map, sysinfo->hex_id), response);
    }

    {
        BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "compatible"), response);
        BO_COAP_TRY(cbor_encode_text_stringz(&root_map, CONFIG_BORNEO_DEVICE_COMPATIBLE), response);
    }

    {
        BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "name"), response);
        BO_COAP_TRY(cbor_encode_text_stringz(&root_map, sysinfo->name), response);
    }

    {
        BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "serno"), response);
        BO_COAP_TRY(cbor_encode_text_stringz(&root_map, sysinfo->hex_id), response);
    }

    {
        BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "hasBT"), response);
#if CONFIG_BT_BLE_ENABLED
        BO_COAP_TRY(cbor_encode_boolean(&root_map, true), response);
#else
        BO_COAP_TRY(cbor_encode_boolean(&root_map, false), response);
#endif

#if CONFIG_BT_BLE_ENABLED
        // bt-mac
        uint8_t bt_mac[6];
        BO_COAP_TRY(esp_read_mac(bt_mac, ESP_MAC_BT), response);
        BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "btMac"), response);
        BO_COAP_TRY(cbor_encode_byte_string(&root_map, bt_mac, 6), response);
#endif
    }

    {
        BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "hasWifi"), response);
        BO_COAP_TRY(cbor_encode_boolean(&root_map, true), response);
    }

    {
        uint8_t wifi_mac[6];
        esp_read_mac(wifi_mac, ESP_MAC_WIFI_STA);
        BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "wifiMac"), response);
        BO_COAP_TRY(cbor_encode_byte_string(&root_map, wifi_mac, 6), response);
    }

    {
        BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "manufID"), response);
        BO_COAP_TRY(cbor_encode_uint(&root_map, 1), response);
    }

    {
        BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "manufName"), response);
        BO_COAP_TRY(cbor_encode_text_stringz(&root_map, sysinfo->manuf), response);
    }

    {
        BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "modelID"), response);
        BO_COAP_TRY(cbor_encode_uint(&root_map, 1), response);
    }

    {
        BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "modelName"), response);
        BO_COAP_TRY(cbor_encode_text_stringz(&root_map, sysinfo->model), response);
    }

    {
        BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "hwVer"), response);
        BO_COAP_TRY(cbor_encode_text_stringz(&root_map, CONFIG_BORNEO_HW_VER), response);
    }

    {
        const esp_app_desc_t* app_desc = esp_app_get_description();
        if (app_desc == NULL) {
            coap_pdu_set_code(response, BO_COAP_CODE_500_INTERNAL_SERVER_ERROR);
            return;
        }
        BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "fwVer"), response);
        BO_COAP_TRY(cbor_encode_text_stringz(&root_map, app_desc->version), response);
    }

    BO_COAP_TRY(cbor_encoder_close_container(&encoder, &root_map), response);

    encoded_size = cbor_encoder_get_buffer_size(&encoder, buf);

    coap_add_data_blocked_response(request, response, COAP_MEDIATYPE_APPLICATION_CBOR, 0, encoded_size, buf);
}

static void coap_hnd_borneo_reboot_post(coap_resource_t* resource, coap_session_t* session, const coap_pdu_t* request,
                                        const coap_string_t* query, coap_pdu_t* response)
{
    bo_system_reboot_later(5000);

    coap_pdu_set_code(response, COAP_RESPONSE_CODE(204));
}

static void coap_hnd_borneo_status_get(coap_resource_t* resource, coap_session_t* session, const coap_pdu_t* request,
                                       const coap_string_t* query, coap_pdu_t* response)
{
    size_t encoded_size = 0;
    uint8_t buf[1024];

    CborEncoder encoder;
    cbor_encoder_init(&encoder, buf, sizeof(buf), 0);
    CborEncoder root_map;

    BO_COAP_TRY(cbor_encoder_create_map(&encoder, &root_map, CborIndefiniteLength), response);

    BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "power"), response);
    BO_COAP_TRY(cbor_encode_boolean(&root_map, bo_power_is_on()), response);

    BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "timestamp"), response);
    BO_COAP_TRY(cbor_encode_uint(&root_map, bo_rtc_get_timestamp()), response);

    BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "bootDuration"), response);
    BO_COAP_TRY(cbor_encode_int(&root_map, esp_timer_get_time() / 1000ULL), response);

    BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "timezone"), response);
    char* tz_name = getenv("TZ");
    if (tz_name == NULL) {
        BO_COAP_TRY(cbor_encode_null(&root_map), response);
    }
    else {
        BO_COAP_TRY(cbor_encode_text_stringz(&root_map, tz_name), response);
    }

    // TODO FIXME
    BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "wifiStatus"), response);
    BO_COAP_TRY(cbor_encode_uint(&root_map, 0), response);

    // WiFi RSSI
    {
        BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "wifiRssi"), response);
        int wifi_rssi;
        if (bo_wifi_get_rssi(&wifi_rssi) == 0) {
            BO_COAP_TRY(cbor_encode_int(&root_map, wifi_rssi), response);
        }
        else {
            BO_COAP_TRY(cbor_encode_null(&root_map), response);
        }
    }

#if CONFIG_BT_BLE_ENABLED
    // TODO FIXME
    BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "btStatus"), response);
    BO_COAP_TRY(cbor_encode_uint(&root_map, 0), response);
#endif

    // TODO FIXME
    BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "serverStatus"), response);
    BO_COAP_TRY(cbor_encode_uint(&root_map, 0), response);

    BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "error"), response);
    BO_COAP_TRY(cbor_encode_int(&root_map, errno), response);

    BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "shutdownReason"), response);
    BO_COAP_TRY(cbor_encode_uint(&root_map, bo_system_get_shutdown_reason()), response);

    BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "shutdownTimestamp"), response);
    BO_COAP_TRY(cbor_encode_uint(&root_map, bo_system_get_shutdown_timestamp()), response);

#if CONFIG_BORNEO_NTC_ENABLED
    {
        BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "temperature"), response);
        int temp;
        int rc = ntc_read_temp(&temp);
        if (rc != 0) {
            BO_COAP_TRY(cbor_encode_null(&root_map), response);
        }
        else {
            BO_COAP_TRY(cbor_encode_int(&root_map, temp), response);
        }
    }
#endif // CONFIG_BORNEO_NTC_ENABLED

#if CONFIG_BORNEO_MEAS_VOLTAGE_ENABLED
    {
        BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "powerVoltage"), response);
        int mv;
        int rc = bo_power_volt_read(&mv);
        if (rc != 0) {
            BO_COAP_TRY(cbor_encode_null(&root_map), response);
        }
        else {
            BO_COAP_TRY(cbor_encode_int(&root_map, mv), response);
        }
    }
#endif // CONFIG_BORNEO_MEAS_VOLTAGE_ENABLED

#if CONFIG_BORNEO_MEAS_CURRENT_ENABLED
    {
        BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "powerCurrent"), response);
        int ma;
        int rc = bo_power_current_read(&ma);
        if (rc != 0) {
            BO_COAP_TRY(cbor_encode_null(&root_map), response);
        }
        else {
            BO_COAP_TRY(cbor_encode_int(&root_map, ma), response);
        }
    }
#endif // CONFIG_BORNEO_MEAS_CURRENT_ENABLED

    BO_COAP_TRY(cbor_encoder_close_container(&encoder, &root_map), response);

    encoded_size = cbor_encoder_get_buffer_size(&encoder, buf);

    coap_add_data_blocked_response(request, response, COAP_MEDIATYPE_APPLICATION_CBOR, 0, encoded_size, buf);
}

static void coap_hnd_borneo_fw_ver_get(coap_resource_t* resource, coap_session_t* session, const coap_pdu_t* request,
                                       const coap_string_t* query, coap_pdu_t* response)
{
    CborEncoder encoder;
    size_t encoded_size = 0;
    uint8_t buf[128] = { 0 };

    cbor_encoder_init(&encoder, buf, sizeof(buf), 0);
    const esp_app_desc_t* app_desc = esp_app_get_description();
    if (app_desc == NULL) {
        coap_pdu_set_code(response, BO_COAP_CODE_500_INTERNAL_SERVER_ERROR);
        return;
    }
    BO_COAP_TRY(cbor_encode_text_stringz(&encoder, app_desc->version), response);

    encoded_size = cbor_encoder_get_buffer_size(&encoder, buf);

    coap_add_data_blocked_response(request, response, COAP_MEDIATYPE_APPLICATION_CBOR, 0, encoded_size, buf);

    coap_pdu_set_code(response, COAP_RESPONSE_CODE_CONTENT);
    return;
}

static void coap_hnd_borneo_compatible_get(coap_resource_t* resource, coap_session_t* session,
                                           const coap_pdu_t* request, const coap_string_t* query, coap_pdu_t* response)
{
    CborEncoder encoder;
    size_t encoded_size = 0;
    uint8_t buf[128] = { 0 };

    cbor_encoder_init(&encoder, buf, sizeof(buf), 0);
    BO_COAP_TRY(cbor_encode_text_stringz(&encoder, CONFIG_BORNEO_DEVICE_COMPATIBLE), response);

    encoded_size = cbor_encoder_get_buffer_size(&encoder, buf);

    coap_add_data_blocked_response(request, response, COAP_MEDIATYPE_APPLICATION_CBOR, 0, encoded_size, buf);

    coap_pdu_set_code(response, COAP_RESPONSE_CODE_CONTENT);
    return;
}

COAP_RESOURCE_DEFINE("borneo/info", false, coap_hnd_borneo_info_get, NULL, NULL, NULL);

COAP_RESOURCE_DEFINE("borneo/reboot", false, NULL, coap_hnd_borneo_reboot_post, NULL, NULL);

COAP_RESOURCE_DEFINE("borneo/status", false, coap_hnd_borneo_status_get, NULL, NULL, NULL);

COAP_RESOURCE_DEFINE("borneo/fwver", false, coap_hnd_borneo_fw_ver_get, NULL, NULL, NULL);

COAP_RESOURCE_DEFINE("borneo/compatible", false, coap_hnd_borneo_compatible_get, NULL, NULL, NULL);
