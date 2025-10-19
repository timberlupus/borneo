file(GLOB_RECURSE BORNEO_APP_SOURCES
    "src/*.c"
    "src/*.cpp"
)

set(REQUIRES_PRO)
set(PRIV_REQUIRES_PRO)

if(BORNEO_EDITION_PRO STREQUAL "1")
    list(APPEND REQUIRES_PRO borneo-ota)
    list(APPEND PRIV_REQUIRES_PRO borneo-factory)
endif()

idf_component_register(
    SRCS ${BORNEO_APP_SOURCES}
    REQUIRES drvfx coap borneo-core smf cbor coap button ${REQUIRES_PRO}
    PRIV_REQUIRES ${PRIV_REQUIRES_PRO}
    WHOLE_ARCHIVE
)
