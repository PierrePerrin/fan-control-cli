# fancontrol 🌀

A fast, lightweight, and modern macOS CLI utility and Swift library for monitoring thermal sensors and controlling fan speeds on Apple Silicon and Intel Macs.

---

## ✨ Features

- 🏎️ **Apple Silicon & Intel Support**: Direct SMC and IOKit HID thermal sensor telemetry.
- 🧙‍♂️ **Interactive Curve Setup Wizard (`fancontrol wizard`)**: Step-by-step CLI wizard with sensor-adaptive temperature recommendations (e.g. ambient surface/keyboard vs. core CPU).
- 📈 **Custom Response Shapes & Curves**:
  - `linear`: Standard linear proportional ramp.
  - `quiet`: Exponential / convex response — keeps fans whisper-quiet longer, ramping up at high temperatures.
  - `aggressive`: Concave curve — ramps speeds early for maximum cooling.
  - `scurve`: Smoothstep (Sigmoid) transitions for smooth acoustics.
  - `stepped`: Discrete speed levels (prevents constant RPM fluctuations).
- 📍 **Multi-Point Curve Support (`--points`)**: Define custom temperature-to-RPM knots (e.g. `30:2317,35:3000,40:5000,44:7826` or percentage `30:20%,45:50%,60:80%`), ready for future GUI editors.
- 🚀 **Background Daemon Mode (`--background`)**: Runs silently in the background, freeing your terminal prompt.
- 🛑 **Daemon Management (`sudo fancontrol stop`)**: Stops background daemons and restores Apple system automatic control.
- 📊 **Real-time Live Gauge Dashboard (`fancontrol watch`)**: Interactive full-screen terminal monitor with live colorized thermal gauges.
- 🤖 **JSON Telemetry (`--json`)**: Easy programmatic integration with status bars (SketchyBar, tmux, SwiftBar) or automation scripts.

---

## 📦 Installation & Build

### Prerequisites
- macOS 12.0+ (Monterey, Ventura, Sonoma, Sequoia+)
- Xcode Command Line Tools (`xcode-select --install`) or Swift 5.9+

### Build from Source

```bash
# Clone the repository
git clone https://github.com/your-username/fan-control.git
cd fan-control

# Build release executable
swift build -c release

# Install to /usr/local/bin
sudo cp .build/release/fancontrol /usr/local/bin/fancontrol
```

---

## 🚀 Quick Start

### 1. Check Status & Overview
```bash
fancontrol status
```
*Output:*
```text
=== macOS Fan & Thermal Overview ===
  • Left Fan   :  2317 RPM (Range: 2317 - 7826 RPM) [Auto]
  • Right Fan  :  2317 RPM (Range: 2317 - 7826 RPM) [Auto]

=== Thermal Sensors ===
  • Trackpad Area (Ambient)        :  33.5°C
  • CPU Efficiency Core (CPU)      :  48.2°C
  • GPU Cluster (GPU)              :  45.0°C
  • Battery Pack (Battery)         :  31.2°C
```

### 2. Run the Interactive Curve Wizard
```bash
sudo fancontrol wizard
```
Guides you through:
1. Selecting target fans (All Fans, Left Fan, Right Fan)
2. Selecting sensor category (`Ambient/Keyboard`, `CPU`, `GPU`, `Battery`, `Storage`, etc.)
3. Applying sensor-tailored presets or custom thresholds
4. Picking response curve shape or defining control points
5. Launching directly in background daemon mode or live foreground monitoring

---

## 📖 Command Reference

### `fancontrol status`
Show fan speeds and a categorized thermal summary.
```bash
fancontrol status
fancontrol status --json
fancontrol status -u F   # Fahrenheit
```

### `fancontrol sensors`
List all discovered hardware thermal sensors.
```bash
fancontrol sensors
fancontrol sensors -c cpu       # Filter by category: cpu, gpu, ambient, battery, storage, system
fancontrol sensors --json
```

### `fancontrol watch`
Launch the live terminal dashboard with interactive gauges.
```bash
fancontrol watch
fancontrol watch -i 0.5   # Refresh interval (seconds)
```

### `sudo fancontrol set <fan> <value>`
Manually set fan speeds (RPM, percentage, or auto).
```bash
sudo fancontrol set 0 3500      # Set Fan 0 to 3500 RPM
sudo fancontrol set left 60%    # Set Left Fan to 60%
sudo fancontrol set all 5000    # Set all fans to 5000 RPM
sudo fancontrol set 0 auto      # Restore Fan 0 to Auto
```

### `sudo fancontrol auto [fan]`
Restore all fans (or a specific fan) to automatic system control.
```bash
sudo fancontrol auto
sudo fancontrol auto 0
```

### `sudo fancontrol curve [options]`
Run the temperature-driven smart fan curve daemon.

| Option | Description | Example |
| :--- | :--- | :--- |
| `-s, --sensor <cat\|name>` | Sensor category or specific sensor name/ID | `--sensor ambient`, `--sensor cpu` |
| `-f, --fan <id\|all>` | Target fan ID or `all` | `--fan 0`, `--fan all` |
| `--min-temp <deg>` | Temperature where fans begin ramping up | `--min-temp 36.0` |
| `--max-temp <deg>` | Temperature where fans reach max RPM | `--max-temp 44.0` |
| `--min-rpm <rpm>` | Minimum fan speed (clamped to hardware) | `--min-rpm 2317` |
| `--max-rpm <rpm>` | Maximum fan speed (clamped to hardware) | `--max-rpm 7826` |
| `--shape <shape>` | Response shape: `linear`, `quiet`, `aggressive`, `scurve`, `stepped` | `--shape quiet` |
| `--points <pts>` | Custom multi-point curve knots | `--points 30:2317,35:3000,40:5000,44:7826` |
| `-b, --background` | Run silently in the background (frees terminal) | `--background` |
| `--log <path>` | Redirect background daemon logs to file | `--log /tmp/fancontrol.log` |
| `-i, --interval <sec>` | Temperature evaluation interval | `-i 2.0` |

#### Examples:
```bash
# Keep keyboard/palmrest cool with a quiet curve in background
sudo fancontrol curve --sensor ambient --min-temp 36 --max-temp 44 --shape quiet --background

# Performance gaming curve on CPU
sudo fancontrol curve --sensor cpu --min-temp 45 --max-temp 80 --shape aggressive --background

# Multi-point custom curve
sudo fancontrol curve --sensor ambient --points 30:2317,35:3000,40:5000,44:7826 --background
```

### `sudo fancontrol stop`
Stop any active background curve daemon and restore all fans to Apple default automatic control.
```bash
sudo fancontrol stop
```

### `fancontrol dump`
Diagnostic SMC key dump for inspecting raw hardware keys.
```bash
fancontrol dump
fancontrol dump TC0P
```

---

## 🏗️ Project Architecture

The project is structured into clean modular Swift packages:

- **`SMCBridge`**: Low-level C bridge interfacing with Apple's `AppleSMC` driver via IOKit.
- **`FanControlKit`**: Core Swift library containing:
  - `FanManager`: High-level fan detection, speed reading, manual control, and auto restoration.
  - `SensorManager` & `HIDThermalClient`: Fast sensor discovery across Intel SMC keys and Apple Silicon HID thermal clients.
  - `FanCurveController`: Multi-point interpolation engine and non-linear response curves.
  - `DaemonManager`: Background process detachment, PID tracking, and graceful signal cleanup.
- **`fancontrol`**: CLI command-line tool with rich ANSI terminal UI (`TerminalUI`), interactive wizard, and command parsers.

---

## 🔒 Safety & Permissions

- **Root Privilege (`sudo`)**: Controlling hardware fan speeds via the Apple SMC requires root privileges on macOS. Read-only operations (`status`, `sensors`, `watch`) do not require `sudo`.
- **Hardware Clamping**: Fan speeds are always strictly clamped between the minimum and maximum RPM values reported by your machine's hardware SMC registers.
- **Fail-Safe Cleanup**: Both foreground and background daemon modes install `SIGINT` (Ctrl+C) and `SIGTERM` signal handlers to automatically restore all fans to system automatic mode upon exit.

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.
