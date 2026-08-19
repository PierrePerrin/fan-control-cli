# VHS tape recording for fancontrol CLI

Output assets/demo.gif
Output assets/demo.mp4

Set Shell "zsh"
Set FontSize 15
Set Width 900
Set Height 580
Set Padding 18
Set Theme "Catppuccin Mocha"
Set WindowBar Colorful
Set BorderRadius 10

# Clean prompt
Hide
Type "export PATH=$PWD/.build/release:$PATH; clear"
Enter
Show

# 1. Overview Status
Type "fancontrol status"
Sleep 500ms
Enter
Sleep 3s

# 2. Thermal Sensors
Type "fancontrol sensors -c ambient"
Sleep 500ms
Enter
Sleep 3s

# 3. Interactive Wizard
Type "fancontrol wizard"
Sleep 500ms
Enter
Sleep 1.5s

# Step 1: Select Fans (0 = All Fans)
Type "0"
Enter
Sleep 1.5s

# Step 2: Select Sensor (1 = Ambient / Keyboard)
Type "1"
Enter
Sleep 1.5s

# Step 3: Curve Profile (2 = Cool Keyboard)
Type "2"
Enter
Sleep 1.5s

# Step 4: Curve Shape (2 = Quiet Exponential)
Type "2"
Enter
Sleep 2.5s

# Step 5: Action (3 = Exit / print command)
Type "3"
Enter
Sleep 3.5s

# 4. Live Dashboard
Type "fancontrol watch -i 0.5"
Sleep 500ms
Enter
Sleep 4.5s
Ctrl+C
Sleep 1.5s
