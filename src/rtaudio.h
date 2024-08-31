#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "miniaudio.h"

#if _WIN32
#include <windows.h>
#else
#include <pthread.h>
#include <unistd.h>
#endif

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

typedef enum rta_error {
    RTA_SUCCESS = 0,
    RTA_ERROR,
    RTA_FAILED_TO_INITIALIZE_CONTEXT,
    RTA_FAILED_TO_GET_DEVICES,
    RTA_FAILED_TO_INIT_DEVICE,
    RTA_INVALID
} rta_error;

// audio callback function
typedef void (*rta_audio_callback_t)(float* output, int frameCount);

// MINIAUDIO datasource
typedef struct rta_audio_callback_datasource_t {
    ma_data_source_base base;
    rta_audio_callback_t dataCallback;
    ma_uint32 numChannels, sampleRate;
} rta_audio_callback_datasource_t;

typedef struct rta_audio_device_t {
    int id;
    char name[256];
    ma_device_info info;
} rta_audio_device_t;

typedef struct rta_audio_context_config_t {
    int channels;
    int sampleRate;
    rta_audio_callback_t dataCallback;
} rta_audio_context_config_t;

typedef struct rta_audio_context_t {
    ma_device device;
    rta_audio_callback_datasource_t dataSource;
} rta_audio_context_t;

rta_error rta_get_device(int id, rta_audio_device_t* info);
rta_error rta_get_device_count(int* count);
rta_error rta_get_devices(rta_audio_device_t* list);
rta_error rta_context_create(
    const rta_audio_context_config_t* contextConfig,
    const rta_audio_device_t* device,
    rta_audio_context_t* context
);
rta_error rta_context_create_aaudio(
    const rta_audio_context_config_t* contextConfig,
    int deviceID,
    rta_audio_context_t* context
);
void rta_context_destroy(rta_audio_context_t* context);

// global context
extern ma_context g_Context;
extern int g_ContextInitialized;
