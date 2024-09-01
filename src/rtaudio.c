#include "rtaudio.h"

// for strcpy
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

ma_context g_Context;
int g_ContextInitialized = 0;

void _rta_log_callback(void* pUserData, ma_uint32 level, const char* pMessage)
{
    printf("[RTA_NATIVE:%d] %s\n", level, pMessage);
}

void _rta_check_and_init_context() {
    if (!g_ContextInitialized) {
        ma_context_config contextConfig = ma_context_config_init();

        ma_log log;
        ma_log_init(NULL, &log);
        ma_log_register_callback(&log, ma_log_callback_init(_rta_log_callback, NULL));
        contextConfig.pLog = &log;

        ma_context_init(NULL, 0, &contextConfig, &g_Context);
        g_ContextInitialized = 1;
    }
}

rta_error rta_get_device_count(int *count)
{
    _rta_check_and_init_context();

    ma_device_info *devices;
    ma_uint32 deviceCount;

    ma_result result = ma_context_get_devices(&g_Context, &devices, &deviceCount, NULL, NULL);
    if (result != MA_SUCCESS) {
        return RTA_FAILED_TO_GET_DEVICES;
    }

    *count = deviceCount;

    return RTA_SUCCESS;
}

rta_error rta_get_devices(rta_audio_device_t* list)
{
    _rta_check_and_init_context();

    ma_device_info *devices;
    ma_uint32 deviceCount;

    ma_result result = ma_context_get_devices(&g_Context, &devices, &deviceCount, NULL, NULL);
    if (result != MA_SUCCESS) {
        printf("[RTA_NATIVE] Failed to get devices. Error: %d\n", result);
        return RTA_FAILED_TO_GET_DEVICES;
    }

    for (ma_uint32 i = 0; i < deviceCount; i++) {
        rta_audio_device_t *device = &list[i];
        device->id = i;
        strcpy(device->name, devices[i].name);
        device->info = devices[i];
    }

    return RTA_SUCCESS;
}

rta_error rta_get_device(int id, rta_audio_device_t *info)
{
    _rta_check_and_init_context();

    ma_device_info *devices;
    ma_uint32 deviceCount;

    ma_result result = ma_context_get_devices(&g_Context, &devices, &deviceCount, NULL, NULL);
    if (result != MA_SUCCESS) {
        printf("[RTA_NATIVE] Failed to get devices. Error: %d\n", result);
        return RTA_FAILED_TO_GET_DEVICES;
    }

    if (id >= deviceCount) {
        return RTA_INVALID;
    }

    info->id = id;
    strcpy(info->name, devices[id].name);
    info->info = devices[id];

    return RTA_SUCCESS;
}

static ma_result rta_audio_callback_datasource_read(ma_data_source* pDataSource, void* pFramesOut, ma_uint64 frameCount, ma_uint64* pFramesRead)
{
    rta_audio_callback_datasource_t* pCallbackDataSource = (rta_audio_callback_datasource_t*)pDataSource;
    
    float* pFramesOutF32 = (float*)pFramesOut;
    ma_uint64 framesRead = 0;

    /* The frameCount parameter tells you how many frames can be written to the output buffer
        A "frame" is one sample for each channel. For example, in a stereo stream (2 channels),
        one frame is 2 samples: one for the left, one for the right. The channel count is defined by
        the device config. The size in bytes of an individual sample is defined by the sample format
        which is also specified in the device config. Multi-channel audio data is always interleaved,
        which means the samples for each frame are stored next to each other in memory. For example,
        in a stereo stream the first pair of samples will be the left and right samples for the first
        frame, the second pair of samples will be the left and right samples for the second frame, etc.
    */

    pCallbackDataSource->dataCallback(pFramesOutF32, frameCount);

    framesRead = frameCount;

    if (pFramesRead != NULL) {
        *pFramesRead = framesRead;
    }

    return MA_SUCCESS;
}

static ma_result rta_audio_callback_datasource_seek(ma_data_source* pDataSource, ma_uint64 frameIndex)
{
    (void)pDataSource;
    (void)frameIndex;
    return MA_NOT_IMPLEMENTED;
}

static ma_result rta_audio_callback_datasource_get_data_format(ma_data_source* pDataSource, ma_format* pFormat, ma_uint32* pChannels, ma_uint32* pSampleRate, ma_channel* pChannelMap, size_t channelMapCap)
{
    rta_audio_callback_datasource_t* pCallbackDataSource = (rta_audio_callback_datasource_t*)pDataSource;

    if (pFormat != NULL) {
        *pFormat = ma_format_f32;
    }

    if (pChannels != NULL) {
        *pChannels = pCallbackDataSource->numChannels;
    }

    if (pSampleRate != NULL) {
        *pSampleRate = pCallbackDataSource->sampleRate;
    }

    if (pChannelMap != NULL) {
        for (ma_uint32 i = 0; i < pCallbackDataSource->numChannels; i++) {
            pChannelMap[i] = i;
        }
    }

    return MA_SUCCESS;
}

static ma_result rta_audio_callback_datasource_get_cursor(ma_data_source* pDataSource, ma_uint64* pCursor)
{
    (void)pDataSource;
    (void)pCursor;
    return MA_NOT_IMPLEMENTED;
}

static ma_result rta_audio_callback_datasource_get_length(ma_data_source* pDataSource, ma_uint64* pLength)
{
    (void)pDataSource;
    (void)pLength;
    return MA_NOT_IMPLEMENTED;
}

static ma_data_source_vtable rta_audio_callback_datasource_vtable = {
    rta_audio_callback_datasource_read,
    rta_audio_callback_datasource_seek,
    rta_audio_callback_datasource_get_data_format,
    rta_audio_callback_datasource_get_cursor,
    rta_audio_callback_datasource_get_length
};

ma_result rta_audio_callback_datasource_init(rta_audio_callback_datasource_t* dataSource)
{
    if (dataSource == NULL) {
        return MA_INVALID_ARGS;
    }

    ma_result result;
    ma_data_source_config baseConfig = ma_data_source_config_init();
    baseConfig.vtable = &rta_audio_callback_datasource_vtable;

    result = ma_data_source_init(&baseConfig, &dataSource->base);
    if (result != MA_SUCCESS) {
        return result;
    }

    dataSource->dataCallback = NULL;
    dataSource->numChannels = 2;
    dataSource->sampleRate = 44100;

    return MA_SUCCESS;
}

void rta_audio_callback_datasource_uninit(rta_audio_callback_datasource_t* dataSource)
{
    if (dataSource == NULL) {
        return;
    }

    ma_data_source_uninit(&dataSource->base);
}

void _rta_data_callback(ma_device *pDevice, void *pOutput, const void *pInput, ma_uint32 frameCount)
{
    rta_audio_context_t* ctx = (rta_audio_context_t*)pDevice->pUserData;
    ma_uint64 framesRead;
    ma_data_source_read_pcm_frames(&ctx->dataSource, pOutput, frameCount, &framesRead);
}

rta_error rta_context_create(
    const rta_audio_context_config_t* contextConfig,
    const rta_audio_device_t* device,
    rta_audio_context_t* context
)
{
    _rta_check_and_init_context();
    
    ma_device_config config = ma_device_config_init(ma_device_type_playback);
    config.playback.pDeviceID = &device->info.id;
    config.playback.format = ma_format_f32;
    config.playback.channels = contextConfig->channels;
    config.sampleRate = contextConfig->sampleRate;
    config.dataCallback = _rta_data_callback;
    config.performanceProfile = ma_performance_profile_low_latency;
    config.pUserData = context;

    rta_audio_callback_datasource_init(&context->dataSource);

    context->dataSource.sampleRate = contextConfig->sampleRate;
    context->dataSource.numChannels = contextConfig->channels;
    context->dataSource.dataCallback = contextConfig->dataCallback;
    
    ma_result result = ma_device_init(&g_Context, &config, &context->device);
    if (result != MA_SUCCESS) {
        return RTA_FAILED_TO_INIT_DEVICE;
    }

    ma_device_start(&context->device);

    return RTA_SUCCESS;
}

rta_error rta_context_create_aaudio(const rta_audio_context_config_t *contextConfig, int deviceID, rta_audio_context_t *context)
{
    _rta_check_and_init_context();
    
    ma_device_id id;
    memset(&id, 0, sizeof(id));
    id.aaudio = deviceID;

    ma_device_config config = ma_device_config_init(ma_device_type_playback);
    config.playback.pDeviceID = &id;
    config.playback.format = ma_format_f32;
    config.playback.channels = contextConfig->channels;
    config.sampleRate = contextConfig->sampleRate;
    config.dataCallback = _rta_data_callback;
    config.performanceProfile = ma_performance_profile_low_latency;
    config.pUserData = context;

    rta_audio_callback_datasource_init(&context->dataSource);

    context->dataSource.sampleRate = contextConfig->sampleRate;
    context->dataSource.numChannels = contextConfig->channels;
    context->dataSource.dataCallback = contextConfig->dataCallback;
    
    ma_result result = ma_device_init(&g_Context, &config, &context->device);
    if (result != MA_SUCCESS) {
        return RTA_FAILED_TO_INIT_DEVICE;
    }

    ma_device_start(&context->device);

    return RTA_SUCCESS;
}

void rta_context_destroy(rta_audio_context_t *context)
{
    ma_device_stop(&context->device);
    rta_audio_callback_datasource_uninit(&context->dataSource);
    ma_device_uninit(&context->device);
}
