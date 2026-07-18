#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$REPO_DIR/../output/taskcanvas-demo"
APP_NAME="TaskCanvas"
DURATION="${1:-30}"

mkdir -p "$OUTPUT_DIR"

screen_device="$(
  ffmpeg -f avfoundation -list_devices true -i '' 2>&1 |
    sed -nE 's/.*\[([0-9]+)\] Capture screen 0/\1/p' |
    head -n 1
)"

if [[ -z "$screen_device" ]]; then
  echo "Capture screen 0 device not found." >&2
  exit 1
fi

frame="$(
  swift -e '
import AppKit
import CoreGraphics

let appName = "TaskCanvas"
NSWorkspace.shared.launchApplication(appName)
Thread.sleep(forTimeInterval: 0.5)

let scale = NSScreen.main?.backingScaleFactor ?? 1.0
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

guard let window = windows.first(where: { ($0[kCGWindowOwnerName as String] as? String) == appName }),
      let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] else {
  fputs("TaskCanvas window not found.\n", stderr)
  exit(1)
}

let x = Int((bounds["X"] ?? 0) * scale)
let y = Int((bounds["Y"] ?? 0) * scale)
let width = Int((bounds["Width"] ?? 0) * scale)
let height = Int((bounds["Height"] ?? 0) * scale)

print("\(x),\(y),\(width),\(height)")
'
)"

IFS=',' read -r x y width height <<<"$frame"

timestamp="$(date '+%Y%m%d-%H%M%S')"
output_path="$OUTPUT_DIR/taskcanvas-demo-$timestamp.mov"

echo "Recording $APP_NAME window: x=$x y=$y width=$width height=$height"
echo "Output: $output_path"
echo "Starting in 3 seconds..."
sleep 3

ffmpeg \
  -y \
  -f avfoundation \
  -framerate 30 \
  -i "${screen_device}:none" \
  -vf "crop=${width}:${height}:${x}:${y}" \
  -c:v libx264 \
  -pix_fmt yuv420p \
  -preset veryfast \
  -crf 18 \
  -t "$DURATION" \
  "$output_path"

echo "Saved: $output_path"
