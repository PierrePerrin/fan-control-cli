import Foundation
import FanControlKit
import SMCBridge

public struct DumpCommand {
    public static func run(args: [String]) {
        var filterPrefix: String? = nil
        var i = 0
        while i < args.count {
            if (args[i] == "--filter" || args[i] == "-f") && i + 1 < args.count {
                filterPrefix = args[i + 1]
                i += 1
            }
            i += 1
        }

        let smc = SMCService.shared
        TerminalUI.printHeader("SMC Keys Diagnostic Dump")

        let keys = smc.getAllKeys()
        print("Total SMC keys found: \(keys.count)\n")
        print("  \(TerminalUI.bold)\(TerminalUI.gray)Key   Type  Size  Decoded Value\(TerminalUI.reset)")
        print("  \(TerminalUI.gray)--------------------------------------------------------\(TerminalUI.reset)")

        for key in keys {
            if let filter = filterPrefix, !key.hasPrefix(filter) {
                continue
            }

            guard let info = try? smc.getKeyInfo(key: key) else { continue }
            let typeStr = withUnsafeBytes(of: info.dataType) { ptr in
                String(cString: ptr.baseAddress!.assumingMemoryBound(to: CChar.self))
            }.trimmingCharacters(in: .whitespacesAndNewlines)

            var valueStr = ""
            if typeStr == "flt" || typeStr == "flt " {
                if let val = try? smc.readFloat(key: key) {
                    valueStr = String(format: "%.2f", val)
                }
            } else if typeStr == "fpe2" {
                if let val = try? smc.readFloat(key: key) {
                    valueStr = String(format: "%.2f (fpe2)", val)
                }
            } else if typeStr == "sp78" {
                if let val = try? smc.readFloat(key: key) {
                    valueStr = String(format: "%.2f (sp78)", val)
                }
            } else if typeStr == "ui8" || typeStr == "ui8 " {
                if let val = try? smc.readUInt8(key: key) {
                    valueStr = "\(val)"
                }
            } else if typeStr == "ui16" || typeStr == "ui16" {
                if let val = try? smc.readUInt16(key: key) {
                    valueStr = "\(val)"
                }
            } else if typeStr == "ui32" || typeStr == "ui32" {
                if let val = try? smc.readUInt32(key: key) {
                    valueStr = "\(val)"
                }
            }

            print(String(format: "  %-4@  %-4@  %3u   %@", key, typeStr, info.dataSize, valueStr))
        }
    }
}
