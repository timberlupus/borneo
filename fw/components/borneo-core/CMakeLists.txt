file(GLOB_RECURSE BORNEO_CORE_SOURCES
    "src/*.c"
    "src/*.cpp"
    "drivers/*.c"
    "drivers/*.cpp"
)

set(BORNEO_INCLUDE_DIRS "./include")


idf_component_register(
    SRCS ${BORNEO_CORE_SOURCES}
    INCLUDE_DIRS ${BORNEO_INCLUDE_DIRS}
    REQUIRES nvs_flash app_update esp_http_client esp_https_ota mbedtls esp_netif driver esp_wifi vfs esp_adc drvfx smf esp_timer spi_flash
    EMBED_TXTFILES ${BORNEO_BOARD_DIR}/ota_server_cert.pem
    LDFRAGMENTS src/coap.lf
    WHOLE_ARCHIVE
)
