#include "SMCBridge.h"
#include <string.h>
#include <pthread.h>
#include <CoreFoundation/CoreFoundation.h>

static io_connect_t g_smc_conn = 0;
static pthread_mutex_t g_smc_lock = PTHREAD_MUTEX_INITIALIZER;

uint32_t smc_fourcc_from_string(const char *str) {
    if (!str) return 0;
    uint32_t code = 0;
    for (int i = 0; i < 4; i++) {
        if (str[i] == '\0') {
            code = (code << 8) | ' ';
        } else {
            code = (code << 8) | (uint8_t)str[i];
        }
    }
    return code;
}

void smc_string_from_fourcc(uint32_t code, char outStr[5]) {
    outStr[0] = (char)((code >> 24) & 0xFF);
    outStr[1] = (char)((code >> 16) & 0xFF);
    outStr[2] = (char)((code >> 8) & 0xFF);
    outStr[3] = (char)(code & 0xFF);
    outStr[4] = '\0';
    for (int i = 0; i < 4; i++) {
        if (outStr[i] < 32 || outStr[i] > 126) {
            outStr[i] = ' ';
        }
    }
}

static kern_return_t smc_open_unlocked(void) {
    if (g_smc_conn != 0) {
        return kIOReturnSuccess;
    }

    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (!service) {
        return kIOReturnNotFound;
    }

    kern_return_t kr = IOServiceOpen(service, mach_task_self(), 0, &g_smc_conn);
    IOObjectRelease(service);
    return kr;
}

kern_return_t smc_open(void) {
    pthread_mutex_lock(&g_smc_lock);
    kern_return_t kr = smc_open_unlocked();
    pthread_mutex_unlock(&g_smc_lock);
    return kr;
}

void smc_close(void) {
    pthread_mutex_lock(&g_smc_lock);
    if (g_smc_conn != 0) {
        IOServiceClose(g_smc_conn);
        g_smc_conn = 0;
    }
    pthread_mutex_unlock(&g_smc_lock);
}

bool smc_is_open(void) {
    pthread_mutex_lock(&g_smc_lock);
    bool open = (g_smc_conn != 0);
    pthread_mutex_unlock(&g_smc_lock);
    return open;
}

static kern_return_t smc_call_internal(SMCKeyData_t *input, SMCKeyData_t *output) {
    pthread_mutex_lock(&g_smc_lock);
    if (g_smc_conn == 0) {
        kern_return_t kr = smc_open_unlocked();
        if (kr != kIOReturnSuccess) {
            pthread_mutex_unlock(&g_smc_lock);
            return kr;
        }
    }
    size_t inSize = sizeof(SMCKeyData_t);
    size_t outSize = sizeof(SMCKeyData_t);
    kern_return_t kr = IOConnectCallStructMethod(g_smc_conn, 2, input, inSize, output, &outSize);
    pthread_mutex_unlock(&g_smc_lock);
    return kr;
}

kern_return_t smc_get_key_info(const char *keyStr, SMCPublicKeyInfo *outInfo) {
    if (!keyStr || !outInfo) return kIOReturnBadArgument;

    SMCKeyData_t input = {0};
    SMCKeyData_t output = {0};

    input.key = smc_fourcc_from_string(keyStr);
    input.data8 = SMC_CMD_READ_KEYINFO;

    kern_return_t kr = smc_call_internal(&input, &output);
    if (kr != kIOReturnSuccess) {
        return kr;
    }

    if (output.result != SMC_SUCCESS) {
        return kIOReturnNotFound;
    }

    strncpy(outInfo->key, keyStr, 4);
    outInfo->key[4] = '\0';
    smc_string_from_fourcc(output.keyInfo.dataType, outInfo->dataType);
    outInfo->dataSize = output.keyInfo.dataSize;
    outInfo->dataAttributes = output.keyInfo.dataAttributes;

    return kIOReturnSuccess;
}

kern_return_t smc_read_raw(const char *keyStr, uint8_t *outBytes, uint32_t *outSize, SMCPublicKeyInfo *outInfo) {
    if (!keyStr || !outBytes || !outSize) return kIOReturnBadArgument;

    SMCPublicKeyInfo info;
    kern_return_t kr = smc_get_key_info(keyStr, &info);
    if (kr != kIOReturnSuccess) return kr;

    if (outInfo) {
        *outInfo = info;
    }

    SMCKeyData_t input = {0};
    SMCKeyData_t output = {0};

    input.key = smc_fourcc_from_string(keyStr);
    input.keyInfo.dataSize = info.dataSize;
    input.data8 = SMC_CMD_READ_BYTES;

    kr = smc_call_internal(&input, &output);
    if (kr != kIOReturnSuccess) {
        return kr;
    }

    if (output.result != SMC_SUCCESS) {
        return kIOReturnNotFound;
    }

    uint32_t copySize = info.dataSize;
    if (copySize > *outSize) copySize = *outSize;
    memcpy(outBytes, output.bytes, copySize);
    *outSize = copySize;

    return kIOReturnSuccess;
}

kern_return_t smc_write_raw(const char *keyStr, const uint8_t *bytes, uint32_t size) {
    if (!keyStr || !bytes) return kIOReturnBadArgument;

    SMCPublicKeyInfo info;
    kern_return_t kr = smc_get_key_info(keyStr, &info);
    if (kr != kIOReturnSuccess) return kr;

    SMCKeyData_t input = {0};
    SMCKeyData_t output = {0};

    input.key = smc_fourcc_from_string(keyStr);
    input.keyInfo.dataSize = info.dataSize;
    input.keyInfo.dataType = smc_fourcc_from_string(info.dataType);
    input.keyInfo.dataAttributes = info.dataAttributes;
    input.data8 = SMC_CMD_WRITE_BYTES;

    uint32_t copySize = size < info.dataSize ? size : info.dataSize;
    memcpy(input.bytes, bytes, copySize);

    kr = smc_call_internal(&input, &output);
    if (kr != kIOReturnSuccess) {
        return kr;
    }

    if (output.result != SMC_SUCCESS) {
        return (output.result == SMC_ERROR_NOT_WRITABLE) ? kIOReturnNotPermitted : kIOReturnError;
    }

    return kIOReturnSuccess;
}

kern_return_t smc_read_float(const char *keyStr, float *outValue) {
    if (!keyStr || !outValue) return kIOReturnBadArgument;

    uint8_t bytes[32] = {0};
    uint32_t size = sizeof(bytes);
    SMCPublicKeyInfo info;

    kern_return_t kr = smc_read_raw(keyStr, bytes, &size, &info);
    if (kr != kIOReturnSuccess) return kr;

    if (strcmp(info.dataType, "flt ") == 0 && size >= 4) {
        memcpy(outValue, bytes, sizeof(float));
        return kIOReturnSuccess;
    } else if (strcmp(info.dataType, "fpe2") == 0 && size >= 2) {
        uint16_t raw = ((uint16_t)bytes[0] << 8) | (uint16_t)bytes[1];
        *outValue = (float)raw / 4.0f;
        return kIOReturnSuccess;
    } else if (strcmp(info.dataType, "sp78") == 0 && size >= 2) {
        int16_t raw = ((int16_t)(int8_t)bytes[0] << 8) | (int16_t)bytes[1];
        *outValue = (float)raw / 256.0f;
        return kIOReturnSuccess;
    } else if (strcmp(info.dataType, "ui8 ") == 0 && size >= 1) {
        *outValue = (float)bytes[0];
        return kIOReturnSuccess;
    } else if (strcmp(info.dataType, "ui16") == 0 && size >= 2) {
        uint16_t raw = ((uint16_t)bytes[0] << 8) | (uint16_t)bytes[1];
        *outValue = (float)raw;
        return kIOReturnSuccess;
    } else if (strcmp(info.dataType, "ui32") == 0 && size >= 4) {
        uint32_t raw = ((uint32_t)bytes[0] << 24) | ((uint32_t)bytes[1] << 16) | ((uint32_t)bytes[2] << 8) | (uint32_t)bytes[3];
        *outValue = (float)raw;
        return kIOReturnSuccess;
    }

    return kIOReturnUnsupported;
}

kern_return_t smc_read_uint8(const char *keyStr, uint8_t *outValue) {
    if (!keyStr || !outValue) return kIOReturnBadArgument;
    uint8_t bytes[32] = {0};
    uint32_t size = sizeof(bytes);
    SMCPublicKeyInfo info;
    kern_return_t kr = smc_read_raw(keyStr, bytes, &size, &info);
    if (kr != kIOReturnSuccess) return kr;
    if (size >= 1) {
        *outValue = bytes[0];
        return kIOReturnSuccess;
    }
    return kIOReturnUnderrun;
}

kern_return_t smc_read_uint16(const char *keyStr, uint16_t *outValue) {
    if (!keyStr || !outValue) return kIOReturnBadArgument;
    uint8_t bytes[32] = {0};
    uint32_t size = sizeof(bytes);
    SMCPublicKeyInfo info;
    kern_return_t kr = smc_read_raw(keyStr, bytes, &size, &info);
    if (kr != kIOReturnSuccess) return kr;
    if (size >= 2) {
        *outValue = ((uint16_t)bytes[0] << 8) | (uint16_t)bytes[1];
        return kIOReturnSuccess;
    }
    return kIOReturnUnderrun;
}

kern_return_t smc_read_uint32(const char *keyStr, uint32_t *outValue) {
    if (!keyStr || !outValue) return kIOReturnBadArgument;
    uint8_t bytes[32] = {0};
    uint32_t size = sizeof(bytes);
    SMCPublicKeyInfo info;
    kern_return_t kr = smc_read_raw(keyStr, bytes, &size, &info);
    if (kr != kIOReturnSuccess) return kr;
    if (size >= 4) {
        *outValue = ((uint32_t)bytes[0] << 24) | ((uint32_t)bytes[1] << 16) | ((uint32_t)bytes[2] << 8) | (uint32_t)bytes[3];
        return kIOReturnSuccess;
    }
    return kIOReturnUnderrun;
}

kern_return_t smc_write_float(const char *keyStr, float value) {
    SMCPublicKeyInfo info;
    kern_return_t kr = smc_get_key_info(keyStr, &info);
    if (kr != kIOReturnSuccess) return kr;

    if (strcmp(info.dataType, "flt ") == 0) {
        uint8_t bytes[4];
        memcpy(bytes, &value, 4);
        return smc_write_raw(keyStr, bytes, 4);
    } else if (strcmp(info.dataType, "fpe2") == 0) {
        return smc_write_fpe2(keyStr, value);
    }

    return kIOReturnUnsupported;
}

kern_return_t smc_write_uint8(const char *keyStr, uint8_t value) {
    return smc_write_raw(keyStr, &value, 1);
}

kern_return_t smc_write_uint16(const char *keyStr, uint16_t value) {
    uint8_t bytes[2];
    bytes[0] = (uint8_t)((value >> 8) & 0xFF);
    bytes[1] = (uint8_t)(value & 0xFF);
    return smc_write_raw(keyStr, bytes, 2);
}

kern_return_t smc_write_fpe2(const char *keyStr, float value) {
    uint16_t raw = (uint16_t)(value * 4.0f);
    uint8_t bytes[2];
    bytes[0] = (uint8_t)((raw >> 8) & 0xFF);
    bytes[1] = (uint8_t)(raw & 0xFF);
    return smc_write_raw(keyStr, bytes, 2);
}

// Private IOHIDEventSystem symbols
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;
typedef struct __IOHIDServiceClient *IOHIDServiceClientRef;
typedef struct __IOHIDEvent *IOHIDEventRef;

extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef match);
extern CFArrayRef IOHIDEventSystemClientCopyServices(IOHIDEventSystemClientRef client);
extern CFTypeRef IOHIDServiceClientCopyProperty(IOHIDServiceClientRef service, CFStringRef key);
extern IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef service, int64_t type, int32_t options, int64_t timeout);
extern double IOHIDEventGetFloatValue(IOHIDEventRef event, int32_t field);

#define IOHIDEventFieldBase(type)   ((type) << 16)
#define kIOHIDEventTypeTemperature  15
#define kIOHIDEventFieldTemperatureLevel IOHIDEventFieldBase(kIOHIDEventTypeTemperature)

int smc_read_hid_sensors(SMCHIDSensor *outSensors, int maxCount) {
    if (!outSensors || maxCount <= 0) return 0;

    IOHIDEventSystemClientRef client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    if (!client) return 0;

    int usagePage = 0xff00;
    int usage = 5;
    CFNumberRef pageNum = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &usagePage);
    CFNumberRef usageNum = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &usage);

    const void *keys[] = { CFSTR("PrimaryUsagePage"), CFSTR("PrimaryUsage") };
    const void *vals[] = { pageNum, usageNum };
    CFDictionaryRef matchDict = CFDictionaryCreate(kCFAllocatorDefault, keys, vals, 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

    IOHIDEventSystemClientSetMatching(client, matchDict);
    CFRelease(pageNum);
    CFRelease(usageNum);
    CFRelease(matchDict);

    CFArrayRef services = IOHIDEventSystemClientCopyServices(client);
    int foundCount = 0;

    if (services) {
        CFIndex count = CFArrayGetCount(services);
        for (CFIndex i = 0; i < count && foundCount < maxCount; i++) {
            IOHIDServiceClientRef service = (IOHIDServiceClientRef)CFArrayGetValueAtIndex(services, i);
            IOHIDEventRef event = IOHIDServiceClientCopyEvent(service, kIOHIDEventTypeTemperature, 0, 0);
            if (event) {
                double temp = IOHIDEventGetFloatValue(event, kIOHIDEventFieldTemperatureLevel);
                CFRelease(event);

                if (temp > 0.0 && temp < 125.0) {
                    CFStringRef product = (CFStringRef)IOHIDServiceClientCopyProperty(service, CFSTR("Product"));
                    if (product) {
                        char nameBuf[64] = {0};
                        CFStringGetCString(product, nameBuf, sizeof(nameBuf), kCFStringEncodingUTF8);
                        CFRelease(product);

                        if (strlen(nameBuf) > 0) {
                            strncpy(outSensors[foundCount].name, nameBuf, sizeof(outSensors[foundCount].name) - 1);
                            outSensors[foundCount].temperature = (float)temp;
                            foundCount++;
                        }
                    }
                }
            }
        }
        CFRelease(services);
    }

    CFRelease(client);
    return foundCount;
}

uint32_t smc_get_key_count(void) {
    uint32_t count = 0;
    if (smc_read_uint32("#KEY", &count) == kIOReturnSuccess) {
        return count;
    }
    return 0;
}

kern_return_t smc_get_key_by_index(uint32_t index, char outKey[5]) {
    if (!outKey) return kIOReturnBadArgument;

    SMCKeyData_t input = {0};
    SMCKeyData_t output = {0};

    input.data8 = SMC_CMD_READ_INDEX;
    input.data32 = index;

    kern_return_t kr = smc_call_internal(&input, &output);
    if (kr != kIOReturnSuccess) {
        return kr;
    }

    if (output.result != SMC_SUCCESS) {
        return kIOReturnNotFound;
    }

    smc_string_from_fourcc(output.key, outKey);
    return kIOReturnSuccess;
}
