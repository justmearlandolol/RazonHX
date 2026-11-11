#ifndef RAZONHX_BRIDGE_H
#define RAZONHX_BRIDGE_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
/* All engine access is serialized on the creating thread (the AppKit main thread).
 * Nonzero return means failure. error, when supplied, receives an owned UTF-8 string.
 * All returned strings must be freed once with rx_string_free, including errors.
 * Output slots must not contain unfreed strings. Input strings are borrowed during the call.
 * A handle must not be used after destroy or destroyed twice. NULL frees are safe. */
typedef struct RxEngine RxEngine;
int32_t rx_engine_create(const char *path, RxEngine **output, char **error);
void rx_engine_destroy(RxEngine *engine);
int32_t rx_engine_snapshot(RxEngine *engine, char **output, char **error);
int32_t rx_engine_update(RxEngine *engine, const char *json, char **error);
int32_t rx_engine_reset(RxEngine *engine, char **error);
/* Empty queue returns success and NULL output. No timer/polling is needed:
 * drain notifications after a successful state change. */
int32_t rx_engine_next_event(RxEngine *engine, char **output, char **error);
void rx_string_free(char *value);
#ifdef __cplusplus
}
#endif
#endif
