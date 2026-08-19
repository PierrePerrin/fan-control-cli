import Foundation
import FanControlKit

public struct StopCommand {
    public static func run() {
        if let pid = DaemonManager.shared.runningPID {
            print("Found active background fan control daemon (PID: \(pid)). Stopping daemon...")
            let success = DaemonManager.shared.stopDaemon()
            if success {
                print("\(TerminalUI.green)✓ Background daemon (PID \(pid)) stopped.\(TerminalUI.reset)")
                print("\(TerminalUI.green)✓ Restored all fans to Automatic system control.\(TerminalUI.reset)")
            } else {
                print("\(TerminalUI.yellow)Daemon process terminated. Restored all fans to Automatic system control.\(TerminalUI.reset)")
            }
        } else {
            print("No active background daemon PID file found.")
            do {
                try FanManager.shared.resetAllToAuto()
                print("\(TerminalUI.green)✓ Restored all fans to Automatic system control.\(TerminalUI.reset)")
            } catch {
                print("\(TerminalUI.red)Failed to reset fans to Auto: \(error.localizedDescription)\(TerminalUI.reset)")
                print("If permission was denied, please run with sudo: \(TerminalUI.cyan)sudo fancontrol stop\(TerminalUI.reset)")
            }
        }
    }
}
