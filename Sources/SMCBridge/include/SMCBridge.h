#ifndef SMCBridge_h
#define SMCBridge_h

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <mach/mach.h>
#include <IOKit/IOKitLib.h>

#ifdef __cplusplus
extern "C" {
#endif

// SMC Command codes
#define SMC_CMD_READ_BYTES       5
#define SMC_CMD_WRITE_BYTES      6
#define SMC_CMD_READ_INDEX       8
#define SMC_CMD_READ_KEYINFO     9

// SMC Result codes
#define SMC_SUCCESS              0
#define SMC_ERROR_NOT_FOUND      0x84
#define SMC_ERROR_NOT_WRITABLE   0x86

typedef struct {
    uint8_t major;
    uint8_t minor;
    uint8_t build;
    uint8_t reserved;
    uint16_t release;
} SMCVersion;

typedef struct {
    uint16_t version;
    uint16_t length;
    uint32_t cpuPLimit;
    uint32_t gpuPLimit;
    uint32_t memPLimit;
} SMCPLimitData;

typedef struct {
    uint32_t dataSize;
    uint32_t dataType;
    uint8_t dataAttributes;
} SMCKeyInfoData;

typedef struct {
    uint32_t key;
    SMCVersion vers;
    SMCPLimitData pLimitData;
    SMCKeyInfoData keyInfo;
    uint8_t result;
    uint8_t status;
    uint8_t data8;
    uint32_t data32;
    uint8_t bytes[32];
} SMCKeyData_t;

typedef struct {
    char key[5];
    char dataType[5];
    uint32_t dataSize;
    uint8_t dataAttributes;
} SMCPublicKeyInfo;

// SMC Lifecycle
kern_return_t smc_open(void);
void smc_close(void);
bool smc_is_open(void);

// Key operations
kern_return_t smc_get_key_info(const char *keyStr, SMCPublicKeyInfo *outInfo);
kern_return_t smc_read_raw(const char *keyStr, uint8_t *outBytes, uint32_t *outSize, SMCPublicKeyInfo *outInfo);
kern_return_t smc_write_raw(const char *keyStr, const uint8_t *bytes, uint32_t size);

// Typed readers
kern_return_t smc_read_float(const char *keyStr, float *outValue);
kern_return_t smc_read_uint8(const char *keyStr, uint8_t *outValue);
kern_return_t smc_read_uint16(const char *keyStr, uint16_t *outValue);
kern_return_t smc_read_uint32(const char *keyStr, uint32_t *outValue);

// Typed writers
kern_return_t smc_write_float(const char *keyStr, float value);
kern_return_t smc_write_uint8(const char *keyStr, uint8_t value);
kern_return_t smc_write_uint16(const char *keyStr, uint16_t value);
kern_return_t smc_write_fpe2(const char *keyStr, float value);

// HID Temperature sensors
typedef struct {
    char name[64];
    float temperature;
} SMCHIDSensor;

int smc_read_hid_sensors(SMCHIDSensor *outSensors, int maxCount);

// Key enumeration
uint32_t smc_get_key_count(void);
kern_return_t smc_get_key_by_index(uint32_t index, char outKey[5]);

// Helper utilities
uint32_t smc_fourcc_from_string(const char *str);
void smc_string_from_fourcc(uint32_t code, char outStr[5]);

#ifdef __cplusplus
}
#endif

#endif /* SMCBridge_h */
