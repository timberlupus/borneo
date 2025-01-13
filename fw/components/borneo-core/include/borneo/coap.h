#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include "common.h"

struct coap_resource_desc {
    const char* path;
    coap_method_handler_t get_handler;
    coap_method_handler_t post_handler;
    coap_method_handler_t put_handler;
    coap_method_handler_t delete_handler;
    bool is_observable;
};

#define __COAP_MAKE_UNIQUE_TOKEN(x, y) _CONCAT(x, y)

#define COAP_RESOURCE_DEFINE(res_path, res_is_observable, res_get, res_post, res_put, res_delete)                      \
    static const struct coap_resource_desc __attribute__((section(".coap_resource_desc"), used))                       \
    __COAP_MAKE_UNIQUE_TOKEN(__coap_resource_desc_, __LINE__)                                                          \
        = {                                                                                                            \
              .path = res_path,                                                                                        \
              .is_observable = (res_is_observable),                                                                    \
              .get_handler = (res_get),                                                                                \
              .post_handler = (res_post),                                                                              \
              .put_handler = (res_put),                                                                                \
              .delete_handler = (res_delete),                                                                          \
          };

#define BO_COAP_TRY(expression, code)                                                                                  \
    ({                                                                                                                 \
        int _rc = (expression);                                                                                        \
        if (_rc != 0) {                                                                                                \
            coap_pdu_set_code(response, code);                                                                         \
            return;                                                                                                    \
        }                                                                                                              \
    })

#define BO_COAP_VERIFY(expression) (BO_COAP_TRY((expression), COAP_RESPONSE_CODE(400)))

#define BO_COAP_TRY_ENCODE_CBOR(expression) (BO_COAP_TRY((expression), COAP_RESPONSE_CODE(500)))

#define BO_COAP_CODE_201_CREATED COAP_RESPONSE_CODE(201)
#define BO_COAP_CODE_202_DELETED COAP_RESPONSE_CODE(202)
#define BO_COAP_CODE_203_VALID COAP_RESPONSE_CODE(203)
#define BO_COAP_CODE_204_CHANGED COAP_RESPONSE_CODE(204)
#define BO_COAP_CODE_205_CONTENT COAP_RESPONSE_CODE(205)
#define BO_COAP_CODE_231_CONTINUE COAP_RESPONSE_CODE(231)
#define BO_COAP_CODE_400_BAD_REQUEST COAP_RESPONSE_CODE(400)
#define BO_COAP_CODE_401_UNAUTHORIZED COAP_RESPONSE_CODE(401)
#define BO_COAP_CODE_405_METHOD_NOT_ALLOWED COAP_RESPONSE_CODE(405)
#define BO_COAP_CODE_406_NOT_ACCEPTABLE COAP_RESPONSE_CODE(406)
#define BO_COAP_CODE_500_INTERNAL_SERVER_ERROR COAP_RESPONSE_CODE(500)
#define BO_COAP_CODE_501_NOT_IMPLEMENTED COAP_RESPONSE_CODE(501)

#ifdef __cplusplus
}
#endif