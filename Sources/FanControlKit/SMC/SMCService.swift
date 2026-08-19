import Foundation
import SMCBridge

public enum SMCError: LocalizedError, Sendable {
    case serviceNotFound
    case connectionFailed(Int32)
    case keyNotFound(String)
    case readFailed(String, Int32)
    case writeFailed(String, Int32)
    case permissionDenied(String)
    case invalidArgument(String)
    case unsupportedType(String)

    public var errorDescription: String? {
        switch self {
        case .serviceNotFound:
            return "AppleSMC kernel service was not found on this system."
        case .connectionFailed(let code):
            return "Failed to establish connection to AppleSMC (code: \(code))."
        case .keyNotFound(let key):
            return "SMC key '\(key)' was not found."
        case .readFailed(let key, let code):
            return "Failed to read SMC key '\(key)' (code: \(code))."
        case .writeFailed(let key, let code):
            return "Failed to write SMC key '\(key)' (code: \(code))."
        case .permissionDenied(let action):
            return "Permission denied for '\(action)'. Setting fan speed requires administrator privileges. Please run with sudo."
        case .invalidArgument(let msg):
            return "Invalid argument: \(msg)"
        case .unsupportedType(let type):
            return "Unsupported SMC data type: \(type)"
        }
    }
}

public final class SMCService: @unchecked Sendable {
    public static let shared = SMCService()

    private init() {}

    public func open() throws {
        let kr = smc_open()
        if kr == kIOReturnNotFound {
            throw SMCError.serviceNotFound
        } else if kr != kIOReturnSuccess {
            throw SMCError.connectionFailed(kr)
        }
    }

    public func close() {
        smc_close()
    }

    public var isOpen: Bool {
        return smc_is_open()
    }

    public func getKeyInfo(key: String) throws -> SMCPublicKeyInfo {
        var info = SMCPublicKeyInfo()
        let kr = smc_get_key_info(key, &info)
        if kr == kIOReturnNotFound {
            throw SMCError.keyNotFound(key)
        } else if kr != kIOReturnSuccess {
            throw SMCError.readFailed(key, kr)
        }
        return info
    }

    public func readFloat(key: String) throws -> Float {
        var val: Float = 0
        let kr = smc_read_float(key, &val)
        if kr == kIOReturnNotFound {
            throw SMCError.keyNotFound(key)
        } else if kr == kIOReturnUnsupported {
            throw SMCError.unsupportedType(key)
        } else if kr != kIOReturnSuccess {
            throw SMCError.readFailed(key, kr)
        }
        return val
    }

    public func readUInt8(key: String) throws -> UInt8 {
        var val: UInt8 = 0
        let kr = smc_read_uint8(key, &val)
        if kr == kIOReturnNotFound {
            throw SMCError.keyNotFound(key)
        } else if kr != kIOReturnSuccess {
            throw SMCError.readFailed(key, kr)
        }
        return val
    }

    public func readUInt16(key: String) throws -> UInt16 {
        var val: UInt16 = 0
        let kr = smc_read_uint16(key, &val)
        if kr == kIOReturnNotFound {
            throw SMCError.keyNotFound(key)
        } else if kr != kIOReturnSuccess {
            throw SMCError.readFailed(key, kr)
        }
        return val
    }

    public func readUInt32(key: String) throws -> UInt32 {
        var val: UInt32 = 0
        let kr = smc_read_uint32(key, &val)
        if kr == kIOReturnNotFound {
            throw SMCError.keyNotFound(key)
        } else if kr != kIOReturnSuccess {
            throw SMCError.readFailed(key, kr)
        }
        return val
    }

    public func writeFloat(key: String, value: Float) throws {
        let kr = smc_write_float(key, value)
        if kr == kIOReturnNotPermitted || kr == -536870207 /* 0xe00002c1 */ {
            throw SMCError.permissionDenied("write \(key)")
        } else if kr == kIOReturnNotFound {
            throw SMCError.keyNotFound(key)
        } else if kr != kIOReturnSuccess {
            throw SMCError.writeFailed(key, kr)
        }
    }

    public func writeUInt8(key: String, value: UInt8) throws {
        let kr = smc_write_uint8(key, value)
        if kr == kIOReturnNotPermitted || kr == -536870207 {
            throw SMCError.permissionDenied("write \(key)")
        } else if kr == kIOReturnNotFound {
            throw SMCError.keyNotFound(key)
        } else if kr != kIOReturnSuccess {
            throw SMCError.writeFailed(key, kr)
        }
    }

    public func writeUInt16(key: String, value: UInt16) throws {
        let kr = smc_write_uint16(key, value)
        if kr == kIOReturnNotPermitted || kr == -536870207 {
            throw SMCError.permissionDenied("write \(key)")
        } else if kr == kIOReturnNotFound {
            throw SMCError.keyNotFound(key)
        } else if kr != kIOReturnSuccess {
            throw SMCError.writeFailed(key, kr)
        }
    }

    public func getAllKeys() -> [String] {
        let count = smc_get_key_count()
        guard count > 0 else { return [] }
        var result: [String] = []
        result.reserveCapacity(Int(count))
        var keyBuffer: [CChar] = [0, 0, 0, 0, 0]
        for i in 0..<count {
            if smc_get_key_by_index(i, &keyBuffer) == kIOReturnSuccess {
                let keyStr = String(cString: keyBuffer).trimmingCharacters(in: .whitespaces)
                if !keyStr.isEmpty {
                    result.append(keyStr)
                }
            }
        }
        return result
    }
}
