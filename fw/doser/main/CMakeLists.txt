file(GLOB_RECURSE BORNEO_APP_SOURCES
    "src/*.c"
    "src/*.cpp"
)

#set(BORNEO_INCLUDE_DIRS "./include")


idf_component_register(
    SRCS ${BORNEO_APP_SOURCES}
    INCLUDE_DIRS ${BORNEO_INCLUDE_DIRS}
    REQUIRES drvfx coap smf cbor coap borneo-core borneo-factory
    WHOLE_ARCHIVE
)
