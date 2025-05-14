
set(SDKCONFIG "${CMAKE_BINARY_DIR}/sdkconfig")
set(EXTRA_COMPONENT_DIRS
    "${CMAKE_CURRENT_SOURCE_DIR}/../components"
    "${CMAKE_CURRENT_SOURCE_DIR}/../3rd-components"
)

message("[BORNEO] > Product ID: `${PRODUCT_ID}`")


set(BORNEO_PRODUCT_ID ${PRODUCT_ID})

include("${CMAKE_CURRENT_SOURCE_DIR}/products/${BORNEO_PRODUCT_ID}/product.cmake")

message("[BORNEO] > Board ID: `${BORNEO_BOARD_ID}`")

include("${CMAKE_CURRENT_SOURCE_DIR}/boards/${BORNEO_BOARD_ID}/board.cmake")

set(BORNEO_BOARD_DIR  "${CMAKE_CURRENT_SOURCE_DIR}/boards/${BORNEO_BOARD_ID}")


if(CMAKE_BUILD_TYPE AND (CMAKE_BUILD_TYPE STREQUAL "Release"))
    set(SDKCONFIG_DEFAULTS "${CMAKE_CURRENT_SOURCE_DIR}/sdkconfig.common; ${CMAKE_CURRENT_SOURCE_DIR}/sdkconfig.release;${BORNEO_BOARD_DIR}/sdkconfig.board;${CMAKE_CURRENT_SOURCE_DIR}/products/${BORNEO_PRODUCT_ID}/sdkconfig.product")
else()
    set(SDKCONFIG_DEFAULTS "${CMAKE_CURRENT_SOURCE_DIR}/sdkconfig.common;${BORNEO_BOARD_DIR}/sdkconfig.board;${CMAKE_CURRENT_SOURCE_DIR}/products/${BORNEO_PRODUCT_ID}/sdkconfig.product")
endif()


set(BORNEO_PROJECT_ID ${BORNEO_PRODUCT_ID})
string(REPLACE "/" "_" BORNEO_PROJECT_ID "${BORNEO_PRODUCT_ID}")
message("[BORNEO] > Project: `${BORNEO_PROJECT_ID}`")

set(BORNEO_BOARD_INCLUDE_DIR  ${BORNEO_BOARD_DIR})
