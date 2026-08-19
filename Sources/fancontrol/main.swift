import Foundation
import FanControlKit

let version = "1.0.0"

func printHelp() {
    print("""
\(TerminalUI.bold)\(TerminalUI.cyan)fancontrol\(TerminalUI.reset) - macOS Fan & Thermal Control Utility (v\(version))

\(TerminalUI.bold)USAGE:\(TerminalUI.reset)
  fancontrol <command> [options]

\(TerminalUI.bold)COMMANDS:\(TerminalUI.reset)
  \(TerminalUI.bold)status\(TerminalUI.reset)                 Show fan speeds and thermal overview (default)
  \(TerminalUI.bold)set\(TerminalUI.reset) <fan> <value>     Set fan target speed (RPM, %, or auto)
  \(TerminalUI.bold)auto\(TerminalUI.reset) [fan]           Reset specified fan (or all fans) to system automatic mode
  \(TerminalUI.bold)sensors\(TerminalUI.reset)                List all hardware thermal sensors
  \(TerminalUI.bold)watch\(TerminalUI.reset)                  Live interactive terminal dashboard with real-time gauges
  \(TerminalUI.bold)curve\(TerminalUI.reset)                  Run smart temperature-driven fan curve daemon
  \(TerminalUI.bold)wizard\(TerminalUI.reset)                 Interactive step-by-step custom fan curve wizard
  \(TerminalUI.bold)stop\(TerminalUI.reset)                   Stop running background curve daemon and restore Auto mode
  \(TerminalUI.bold)dump\(TerminalUI.reset)                   Diagnostic SMC key dump
  \(TerminalUI.bold)version\(TerminalUI.reset)                Display tool version
  \(TerminalUI.bold)help\(TerminalUI.reset)                   Show this help information

\(TerminalUI.bold)OPTIONS:\(TerminalUI.reset)
  -b, --background           Run curve daemon in background (frees terminal prompt)
  --json                     Output result in JSON format (status, sensors)
  -u, --unit <C|F>           Temperature unit: Celsius (default) or Fahrenheit
  -i, --interval <seconds>   Polling interval for watch/curve (default: 1.0s)
  -c, --category <cat>       Filter sensors: cpu, gpu, battery, storage, ambient, system, all
  -h, --help                 Show help message

\(TerminalUI.bold)EXAMPLES:\(TerminalUI.reset)
  \(TerminalUI.gray)# View overview status\(TerminalUI.reset)
  fancontrol status
  fancontrol status --json

  \(TerminalUI.gray)# Run interactive fan curve wizard\(TerminalUI.reset)
  fancontrol wizard

  \(TerminalUI.gray)# Run curve daemon in background\(TerminalUI.reset)
  sudo fancontrol curve --sensor ambient --min-temp 36 --max-temp 44 --background

  \(TerminalUI.gray)# Stop background daemon\(TerminalUI.reset)
  sudo fancontrol stop

  \(TerminalUI.gray)# List all sensors in Fahrenheit\(TerminalUI.reset)
  fancontrol sensors -u F

  \(TerminalUI.gray)# Live monitoring dashboard (every 0.5s)\(TerminalUI.reset)
  fancontrol watch -i 0.5

  \(TerminalUI.gray)# Set fan speeds (requires sudo)\(TerminalUI.reset)
  sudo fancontrol set 0 3500
  sudo fancontrol set left 60%
  sudo fancontrol set all 4500
  sudo fancontrol set 0 auto

  \(TerminalUI.gray)# Restore all fans to automatic\(TerminalUI.reset)
  sudo fancontrol auto
""")
}

func main() {
    let rawArgs = Array(CommandLine.arguments.dropFirst())

    // Parse global flags
    let isJSON = rawArgs.contains("--json")
    let isHelp = rawArgs.contains("-h") || rawArgs.contains("--help") || rawArgs.contains("help")
    let isVersion = rawArgs.contains("-v") || rawArgs.contains("--version") || rawArgs.contains("version")

    if isVersion {
        print("fancontrol version \(version)")
        return
    }

    if isHelp && rawArgs.count <= 1 {
        printHelp()
        return
    }

    var unit = "C"
    if let unitIdx = rawArgs.firstIndex(where: { $0 == "--unit" || $0 == "-u" }), unitIdx + 1 < rawArgs.count {
        unit = rawArgs[unitIdx + 1].uppercased()
    }

    // Filter out global options to get command and command-specific args
    let filteredArgs = rawArgs.filter { $0 != "--json" }
    let command = filteredArgs.first?.lowercased() ?? "status"
    let subArgs = Array(filteredArgs.dropFirst())

    switch command {
    case "status", "fans", "overview":
        StatusCommand.run(isJSON: isJSON, unit: unit)
    case "set":
        SetCommand.run(args: subArgs)
    case "auto", "reset":
        AutoCommand.run(args: subArgs)
    case "stop", "kill":
        StopCommand.run()
    case "sensors", "temp", "temperatures":
        SensorsCommand.run(args: subArgs, isJSON: isJSON, unit: unit)
    case "watch", "monitor", "top":
        WatchCommand.run(args: subArgs, unit: unit)
    case "wizard", "setup", "interactive":
        WizardCommand.run(args: subArgs)
    case "curve", "smart", "daemon":
        if subArgs.contains("--wizard") || subArgs.contains("-w") || subArgs.contains("wizard") || subArgs.contains("interactive") {
            WizardCommand.run(args: subArgs)
        } else {
            CurveCommand.run(args: subArgs)
        }
    case "dump":
        DumpCommand.run(args: subArgs)
    case "help":
        printHelp()
    default:
        // Check if user passed arguments directly to status (e.g. `fancontrol --json`)
        if command.hasPrefix("-") {
            StatusCommand.run(isJSON: isJSON, unit: unit)
        } else {
            print("\(TerminalUI.red)Unknown command: '\(command)'\(TerminalUI.reset)\n")
            printHelp()
            exit(1)
        }
    }
}

main()
