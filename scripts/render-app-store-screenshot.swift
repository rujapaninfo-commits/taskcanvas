import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let inputURL = root.appendingPathComponent("dist/app-store-screenshots/TaskCanvas-main-raw.png")
let outputURL = root.appendingPathComponent("dist/app-store-screenshots/TaskCanvas-main-1280x800.png")

guard let appImage = NSImage(contentsOf: inputURL) else {
    fatalError("Input image not found: \(inputURL.path)")
}

let canvasSize = NSSize(width: 1280, height: 800)
let image = NSImage(size: canvasSize)
image.lockFocus()

let canvas = NSRect(origin: .zero, size: canvasSize)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.94, green: 0.97, blue: 1.0, alpha: 1),
    NSColor(calibratedRed: 0.83, green: 0.90, blue: 1.0, alpha: 1)
])!
gradient.draw(in: canvas, angle: -18)

let accent = NSBezierPath(ovalIn: NSRect(x: -130, y: 510, width: 560, height: 430))
NSColor(calibratedRed: 0.54, green: 0.67, blue: 1.0, alpha: 0.20).setFill()
accent.fill()

let titleStyle = NSMutableParagraphStyle()
titleStyle.lineSpacing = 7
let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont(name: "HiraginoSans-W6", size: 52) ?? NSFont.boldSystemFont(ofSize: 52),
    .foregroundColor: NSColor(calibratedWhite: 0.10, alpha: 1),
    .paragraphStyle: titleStyle
]
let subtitleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont(name: "HiraginoSans-W3", size: 25) ?? NSFont.systemFont(ofSize: 25),
    .foregroundColor: NSColor(calibratedWhite: 0.28, alpha: 1)
]
let featureAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont(name: "HiraginoSans-W4", size: 21) ?? NSFont.systemFont(ofSize: 21),
    .foregroundColor: NSColor(calibratedWhite: 0.22, alpha: 1)
]

("タスクを\nいつもそばに。").draw(
    in: NSRect(x: 96, y: 455, width: 570, height: 190),
    withAttributes: titleAttributes
)
("ウィンドウ、メニューバー、ウィジェット。\nいつでも素早くタスクを確認できます。").draw(
    in: NSRect(x: 100, y: 360, width: 570, height: 86),
    withAttributes: subtitleAttributes
)

let features = [
    "✓  クラウド同期に対応",
    "✓  サブタスク・期限・メモに対応",
    "✓  コンパクトで邪魔をしない"
]
for (index, line) in features.enumerated() {
    line.draw(
        in: NSRect(x: 102, y: 255 - CGFloat(index * 42), width: 550, height: 32),
        withAttributes: featureAttributes
    )
}

let appRect = NSRect(x: 760, y: 110, width: 420, height: 580)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
shadow.shadowBlurRadius = 30
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.set()
NSColor.white.setFill()
NSBezierPath(roundedRect: appRect, xRadius: 25, yRadius: 25).fill()
NSGraphicsContext.restoreGraphicsState()

appImage.draw(in: appRect, from: .zero, operation: .sourceOver, fraction: 1)

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fatalError("Failed to encode output")
}

try png.write(to: outputURL)
print(outputURL.path)
