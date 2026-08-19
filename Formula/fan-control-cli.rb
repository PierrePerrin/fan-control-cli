class FanControlCli < Formula
  desc "macOS Fan & Thermal Control Utility"
  homepage "https://github.com/PierrePerrin/fan-control-cli"
  url "https://github.com/PierrePerrin/fan-control-cli/archive/refs/tags/v1.0.0.tar.gz"
  head "https://github.com/PierrePerrin/fan-control-cli.git", branch: "main"
  license "MIT"

  depends_on :macos
  depends_on xcode: ["14.0", :build]

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/fancontrol"
  end

  test do
    assert_match "fancontrol", shell_output("#{bin}/fancontrol version")
  end
end
