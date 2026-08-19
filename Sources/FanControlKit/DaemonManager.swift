import Foundation
import Darwin

public final class DaemonManager: @unchecked Sendable {
    public static let shared = DaemonManager()
    public static let pidFilePath = "/tmp/fancontrol.pid"

    private init() {}

    public var runningPID: pid_t? {
        guard let data = try? String(contentsOfFile: Self.pidFilePath, encoding: .utf8),
              let pid = pid_t(data.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        // Verify if process with this PID is still active
        if kill(pid, 0) == 0 {
            return pid
        }
        // Stale PID file
        try? FileManager.default.removeItem(atPath: Self.pidFilePath)
        return nil
    }

    public func launchInBackground(args: [String], logPath: String? = nil) -> pid_t? {
        // Stop any existing background daemon first
        stopDaemon()

        let process = Process()

        // Discover absolute path to current binary
        let exeURL: URL
        if let bundleExe = Bundle.main.executableURL, FileManager.default.fileExists(atPath: bundleExe.path) {
            exeURL = bundleExe
        } else {
            let arg0 = CommandLine.arguments[0]
            if arg0.hasPrefix("/") && FileManager.default.fileExists(atPath: arg0) {
                exeURL = URL(fileURLWithPath: arg0)
            } else if FileManager.default.fileExists(atPath: "/usr/local/bin/fancontrol") {
                exeURL = URL(fileURLWithPath: "/usr/local/bin/fancontrol")
            } else {
                exeURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(arg0)
            }
        }
        process.executableURL = exeURL

        // Filter out background flags to prevent recursive backgrounding loop in child
        let filteredArgs = args.filter { $0 != "--background" && $0 != "-b" && $0 != "-d" && $0 != "--daemon" }
        process.arguments = filteredArgs

        // Redirect stdin to /dev/null
        if let nullRead = FileHandle(forReadingAtPath: "/dev/null") {
            process.standardInput = nullRead
        }

        if let logFile = logPath {
            FileManager.default.createFile(atPath: logFile, contents: nil)
            if let logHandle = FileHandle(forWritingAtPath: logFile) {
                process.standardOutput = logHandle
                process.standardError = logHandle
            }
        } else if let nullWrite = FileHandle(forWritingAtPath: "/dev/null") {
            process.standardOutput = nullWrite
            process.standardError = nullWrite
        }

        do {
            try process.run()
            let pid = process.processIdentifier
            try? "\(pid)".write(toFile: Self.pidFilePath, atomically: true, encoding: .utf8)
            return pid
        } catch {
            print("\u{001B}[31mProcess spawn error: \(error.localizedDescription)\u{001B}[0m")
            return nil
        }
    }

    @discardableResult
    public func stopDaemon() -> Bool {
        guard let pid = runningPID else {
            try? FanManager.shared.resetAllToAuto()
            return false
        }

        // Send SIGINT signal to daemon process to trigger cleanup & restore fans
        kill(pid, SIGINT)

        // Wait briefly for process to exit
        var count = 0
        while kill(pid, 0) == 0 && count < 20 {
            usleep(100_000) // 100ms
            count += 1
        }

        // Force kill if still running
        if kill(pid, 0) == 0 {
            kill(pid, SIGKILL)
        }

        try? FileManager.default.removeItem(atPath: Self.pidFilePath)
        // Reset fans to automatic mode to ensure clean hardware state
        try? FanManager.shared.resetAllToAuto()
        return true
    }
}
