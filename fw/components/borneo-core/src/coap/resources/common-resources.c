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
    BO_COAP_TRY(cbor_encoder_create_map(&encoder, &root_map, CborIndefiniteLength),
                BO_COAP_CODE_500_INTERNAL_SERVER_ERROR);

    {
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "id"));
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, sysinfo->hex_id));
    }

    {
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "compatible"));
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, CONFIG_BORNEO_DEVICE_COMPATIBLE));
    }

    {
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "name"));
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, sysinfo->name));
    }

    {
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "serno"));
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, sysinfo->hex_id));
    }

    {
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "hasBT"));
#if CONFIG_BT_BLE_ENABLED
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_boolean(&root_map, true));
#else
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_boolean(&root_map, false));
#endif

#if CONFIG_BT_BLE_ENABLED
        // bt-mac
        uint8_t bt_mac[6];
        BO_COAP_TRY(esp_read_mac(bt_mac, ESP_MAC_BT), BO_COAP_CODE_500_INTERNAL_SERVER_ERROR);
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "btMac"));
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_byte_string(&root_map, bt_mac, 6));
#endif
    }

    {
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "hasWifi"));
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_boolean(&root_map, true));
    }

    {
        uint8_t wifi_mac[6];
        esp_read_mac(wifi_mac, ESP_MAC_WIFI_STA);
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "wifiMac"));
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_byte_string(&root_map, wifi_mac, 6));
    }

    {
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "manufID"));
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_uint(&root_map, 1));
    }

    {
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "manufName"));
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, sysinfo->manuf));
    }

    {
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "modelID"));
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_uint(&root_map, 1));
    }

    {
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "modelName"));
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, sysinfo->model));
    }

    {
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "hwVer"));
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, CONFIG_BORNEO_HW_VER));
    }

    {
        const esp_partition_t* running = esp_ota_get_running_partition();
        if (running == NULL) {
            coap_pdu_set_code(response, BO_COAP_CODE_500_INTERNAL_SERVER_ERROR);
            return;
        }
        esp_app_desc_t running_app_info;
        BO_COAP_TRY(esp_ota_get_partition_description(running, &running_app_info),
                    BO_COAP_CODE_500_INTERNAL_SERVER_ERROR);

        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "fwVer"));
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, running_app_info.version));
    }

    BO_COAP_TRY_ENCODE_CBOR(cbor_encoder_close_container(&encoder, &root_map));

    encoded_size = cbor_encoder_get_buffer_size(&encoder, buf);

    coap_add_data_blocked_response(request, response, COAP_MEDIATYPE_APPLICATION_CBOR, 0, encoded_size, buf);
}

static void coap_hnd_borneo_reboot_post(coap_resource_t* resource, coap_session_t* session, const coap_pdu_t* request,
                                        const coap_string_t* query, coap_pdu_t* response)
{
    // 1 秒以后重启
    bo_system_reboot_later(1000);

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

    const struct system_status* sys_status = bo_system_get_status();

    BO_COAP_TRY_ENCODE_CBOR(cbor_encoder_create_map(&encoder, &root_map, CborIndefiniteLength));

    BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "power"));
    BO_COAP_TRY_ENCODE_CBOR(cbor_encode_boolean(&root_map, bo_power_is_on()));

    BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "timestamp"));
    BO_COAP_TRY_ENCODE_CBOR(cbor_encode_uint(&root_map, bo_rtc_get_timestamp()));

    BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "bootDuration"));
    BO_COAP_TRY_ENCODE_CBOR(cbor_encode_int(&root_map, esp_timer_get_time() / 1000ULL));

    BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "timezone"));
    char* tz_name = getenv("TZ");
    if (tz_name == NULL) {
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_null(&root_map));
    }
    else {
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, tz_name));
    }

    BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "wifiStatus"));
    BO_COAP_TRY_ENCODE_CBOR(cbor_encode_uint(&root_map, 0));

#if CONFIG_BT_BLE_ENABLED
    // TODO FIXME
    cbor_encode_text_stringz(&root_map, "btStatus");
    cbor_encode_uint(&root_map, 0);
#endif

    // TODO FIXME
    BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "serverStatus"));
    BO_COAP_TRY_ENCODE_CBOR(cbor_encode_uint(&root_map, 0));

    BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "error"));
    BO_COAP_TRY_ENCODE_CBOR(cbor_encode_int(&root_map, errno));

    BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "shutdownReason"));
    BO_COAP_TRY_ENCODE_CBOR(cbor_encode_uint(&root_map, sys_status->shutdown_reason));

    BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "shutdownTimestamp"));
    BO_COAP_TRY_ENCODE_CBOR(cbor_encode_uint(&root_map, sys_status->shutdown_timestamp));

#if CONFIG_BORNEO_NTC_ENABLED
    {
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "temperature"));
        int temp;
        int rc = ntc_read_temp(&temp);
        if (rc != 0) {
            BO_COAP_TRY_ENCODE_CBOR(cbor_encode_null(&root_map));
        }
        else {
            BO_COAP_TRY_ENCODE_CBOR(cbor_encode_int(&root_map, temp));
        }
    }
#endif // CONFIG_BORNEO_NTC_ENABLED

#if CONFIG_BORNEO_MEAS_VOLTAGE_ENABLED
   {
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "powerVoltage"));
        int mv;
        int rc = bo_power_volt_read(&mv);
        if (rc != 0) {
            BO_COAP_TRY_ENCODE_CBOR(cbor_encode_null(&root_map));
        }
        else {
            BO_COAP_TRY_ENCODE_CBOR(cbor_encode_int(&root_map, mv));
        }
    }
#endif // CONFIG_BORNEO_MEAS_VOLTAGE_ENABLED

#if CONFIG_BORNEO_MEAS_CURRENT_ENABLED
   {
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "powerCurrent"));
        int ma;
        int rc = bo_power_current_read(&ma);
        if (rc != 0) {
            BO_COAP_TRY_ENCODE_CBOR(cbor_encode_null(&root_map));
        }
        else {
            BO_COAP_TRY_ENCODE_CBOR(cbor_encode_int(&root_map, ma));
        }
    }
#endif // CONFIG_BORNEO_MEAS_CURRENT_ENABLED


    BO_COAP_TRY_ENCODE_CBOR(cbor_encoder_close_container(&encoder, &root_map));

    encoded_size = cbor_encoder_get_buffer_size(&encoder, buf);

    coap_add_data_blocked_response(request, response, COAP_MEDIATYPE_APPLICATION_CBOR, 0, encoded_size, buf);
}

COAP_RESOURCE_DEFINE("borneo/info", false, coap_hnd_borneo_info_get, NULL, NULL, NULL);

COAP_RESOURCE_DEFINE("borneo/reboot", false, NULL, coap_hnd_borneo_reboot_post, NULL, NULL);

COAP_RESOURCE_DEFINE("borneo/status", false, coap_hnd_borneo_status_get, NULL, NULL, NULL);
