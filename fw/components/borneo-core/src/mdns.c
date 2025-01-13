#include <stdlib.h>

#include <esp_mac.h>
#include <esp_system.h>
#include <esp_event.h>
#include <esp_log.h>
#include <esp_ota_ops.h>
#include <mdns.h>

#include <borneo/common.h>
#include <borneo/mdns.h>
#include <borneo/system.h>

#define TAG "bo-mdns"

static int populate_hostname();
static int add_mdns_services();

#define MDNS_SERVICE_TYPE "_borneo"
#define MDNS_UDP_PORT 5683
#define HOSTNAME_MAX_LEN 32

static char _hostname[HOSTNAME_MAX_LEN] = { 0 };

int bo_mdns_init()
{
    ESP_LOGI(TAG, "Initializing Borneo MDNS sub-system...");

    BO_TRY(mdns_init());

    BO_TRY(populate_hostname());

    const struct system_info* sysinfo = bo_system_get_info();

    BO_TRY(mdns_hostname_set(_hostname));

    BO_TRY(mdns_instance_name_set(sysinfo->name));

    BO_TRY(add_mdns_services());

    ESP_LOGI(TAG, "mDNS sub-system module has been initialized successfully.");

    return 0;
}

int populate_hostname()
{
    uint8_t mac[6] = { 0 };
    BO_TRY(esp_read_mac(mac, ESP_MAC_WIFI_STA));
    snprintf(_hostname, sizeof(_hostname), "borneo-%02x%02x%02x%02x%02x%02x", mac[0], mac[1], mac[2], mac[3],
             mac[4], mac[5]);
    return 0;
}

static int add_mdns_services()
{
    const struct system_info* sysinfo = bo_system_get_info();
    // Add the mDNS service
    BO_TRY(mdns_service_add(NULL, MDNS_SERVICE_TYPE, "_udp", MDNS_UDP_PORT, NULL, 0));

    // Note: You must add the service first, then you can set its properties.
    // The web server uses a custom instance name.
    BO_TRY(mdns_service_instance_name_set(MDNS_SERVICE_TYPE, "_udp", sysinfo->name));

    const esp_app_desc_t* app_desc = esp_app_get_description();

    mdns_txt_item_t serviceTxtData[] = {
        { "name", CONFIG_BORNEO_DEVICE_NAME_DEFAULT },
        { "id", sysinfo->hex_id },
        { "manuf_id", "1" },
        { "manuf_name", sysinfo->manuf },
        { "model_name", CONFIG_BORNEO_BOARD_NAME },
        { "model_id", "1" },
        { "hwver", CONFIG_BORNEO_HW_VER },
        { "fwver", app_desc->version },
        { "serno", sysinfo->hex_id },
        { "category", CONFIG_BORNEO_DEVICE_CATEGORY },
        { "compatible", CONFIG_BORNEO_DEVICE_COMPATIBLE },
    };

    BO_TRY(mdns_service_txt_set(MDNS_SERVICE_TYPE, "_udp", serviceTxtData, sizeof(serviceTxtData) / sizeof(mdns_txt_item_t)));

    return 0;
}
