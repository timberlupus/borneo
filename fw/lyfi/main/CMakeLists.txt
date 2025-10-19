file(GLOB_RECURSE BORNEO_APP_SOURCES
    "src/*.c"
    "src/*.cpp"
)

idf_component_register(
    SRCS ${BORNEO_APP_SOURCES}
    REQUIRES drvfx coap borneo-core smf cbor coap button
    WHOLE_ARCHIVE
)
