import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputURL = root.appendingPathComponent(
    "dist/app-store-screenshots/TaskCanvas-menubar-1280x800.png"
)

let canvasSize = NSSize(width: 1280, height: 800)
let image = NSImage(size: canvasSize)
image.lockFocus()

func roundedRect(
    _ rect: NSRect,
    radius: CGFloat,
    fill: NSColor,
    stroke: NSColor? = nil,
    lineWidth: CGFloat = 1
) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()
    if let stroke {
        stroke.setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }
}

func drawText(
    _ text: String,
    rect: NSRect,
    font: NSFont,
    color: NSColor,
    lineSpacing: CGFloat = 0
) {
    let style = NSMutableParagraphStyle()
    style.lineSpacing = lineSpacing
    text.draw(
        in: rect,
        withAttributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style
        ]
    )
}

func drawSymbol(
    _ name: String,
    in rect: NSRect,
    pointSize: CGFloat,
    weight: NSFont.Weight = .regular,
    color: NSColor
) {
    guard let symbol = NSImage(
        systemSymbolName: name,
        accessibilityDescription: nil
    )?.withSymbolConfiguration(
        NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
    ) else { return }

    let tinted = NSImage(size: symbol.size)
    tinted.lockFocus()
    color.set()
    let symbolRect = NSRect(origin: .zero, size: symbol.size)
    symbol.draw(in: symbolRect)
    symbolRect.fill(using: .sourceAtop)
    tinted.unlockFocus()
    tinted.draw(in: rect)
}

let canvas = NSRect(origin: .zero, size: canvasSize)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.95, green: 0.98, blue: 1.0, alpha: 1),
    NSColor(calibratedRed: 0.84, green: 0.90, blue: 1.0, alpha: 1),
    NSColor(calibratedRed: 0.90, green: 0.87, blue: 0.98, alpha: 1)
])!
gradient.draw(in: canvas, angle: -16)

NSColor(calibratedRed: 0.48, green: 0.65, blue: 1.0, alpha: 0.14).setFill()
NSBezierPath(ovalIn: NSRect(x: -170, y: 480, width: 590, height: 470)).fill()
NSColor(calibratedRed: 0.72, green: 0.55, blue: 1.0, alpha: 0.10).setFill()
NSBezierPath(ovalIn: NSRect(x: 955, y: -220, width: 520, height: 500)).fill()

let ink = NSColor(calibratedWhite: 0.10, alpha: 1)
let secondaryInk = NSColor(calibratedWhite: 0.30, alpha: 1)

drawText(
    "メニューバーから、\nすぐチェック。",
    rect: NSRect(x: 82, y: 490, width: 560, height: 165),
    font: NSFont(name: "HiraginoSans-W6", size: 50) ?? .boldSystemFont(ofSize: 50),
    color: ink,
    lineSpacing: 6
)
drawText(
    "作業中のウィンドウを切り替えずに、\nタスクの追加と完了チェック。",
    rect: NSRect(x: 86, y: 386, width: 560, height: 82),
    font: NSFont(name: "HiraginoSans-W3", size: 24) ?? .systemFont(ofSize: 24),
    color: secondaryInk,
    lineSpacing: 5
)

let features = [
    ("bolt.fill", "アイコンをクリックするだけ"),
    ("plus.circle.fill", "その場ですぐタスクを追加"),
    ("checkmark.circle.fill", "終わったらワンクリックで完了")
]
for (index, feature) in features.enumerated() {
    let y = 282 - CGFloat(index * 50)
    drawSymbol(
        feature.0,
        in: NSRect(x: 88, y: y + 2, width: 21, height: 21),
        pointSize: 18,
        weight: .medium,
        color: NSColor(calibratedRed: 0.16, green: 0.43, blue: 0.92, alpha: 1)
    )
    drawText(
        feature.1,
        rect: NSRect(x: 122, y: y, width: 480, height: 30),
        font: NSFont(name: "HiraginoSans-W4", size: 20) ?? .systemFont(ofSize: 20),
        color: NSColor(calibratedWhite: 0.22, alpha: 1)
    )
}

let desktopRect = NSRect(x: 686, y: 85, width: 520, height: 630)
NSGraphicsContext.saveGraphicsState()
let desktopShadow = NSShadow()
desktopShadow.shadowColor = NSColor.black.withAlphaComponent(0.20)
desktopShadow.shadowBlurRadius = 34
desktopShadow.shadowOffset = NSSize(width: 0, height: -12)
desktopShadow.set()
roundedRect(desktopRect, radius: 26, fill: .white)
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.saveGraphicsState()
NSBezierPath(roundedRect: desktopRect, xRadius: 26, yRadius: 26).addClip()
let desktopGradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.72, green: 0.83, blue: 0.98, alpha: 1),
    NSColor(calibratedRed: 0.91, green: 0.86, blue: 0.98, alpha: 1)
])!
desktopGradient.draw(in: desktopRect, angle: -48)

NSColor.white.withAlphaComponent(0.20).setFill()
NSBezierPath(ovalIn: NSRect(x: 650, y: 225, width: 460, height: 500)).fill()
NSColor(calibratedRed: 0.27, green: 0.50, blue: 0.92, alpha: 0.13).setFill()
NSBezierPath(ovalIn: NSRect(x: 965, y: -10, width: 400, height: 430)).fill()

let menuBarRect = NSRect(x: desktopRect.minX, y: desktopRect.maxY - 38, width: desktopRect.width, height: 38)
NSColor.white.withAlphaComponent(0.82).setFill()
menuBarRect.fill()
NSColor.black.withAlphaComponent(0.08).setFill()
NSRect(x: menuBarRect.minX, y: menuBarRect.minY, width: menuBarRect.width, height: 1).fill()

drawText(
    "TaskCanvas",
    rect: NSRect(x: 712, y: 687, width: 90, height: 20),
    font: .boldSystemFont(ofSize: 13),
    color: ink
)
drawText(
    "ファイル   編集   表示",
    rect: NSRect(x: 806, y: 687, width: 160, height: 20),
    font: .systemFont(ofSize: 12),
    color: ink
)

roundedRect(
    NSRect(x: 1042, y: 681, width: 34, height: 26),
    radius: 7,
    fill: NSColor.black.withAlphaComponent(0.10)
)
drawSymbol(
    "checklist.checked",
    in: NSRect(x: 1051, y: 687, width: 16, height: 16),
    pointSize: 14,
    weight: .medium,
    color: ink
)
drawSymbol(
    "wifi",
    in: NSRect(x: 1089, y: 688, width: 17, height: 14),
    pointSize: 13,
    weight: .medium,
    color: ink
)
drawSymbol(
    "battery.100percent",
    in: NSRect(x: 1118, y: 687, width: 22, height: 15),
    pointSize: 13,
    weight: .medium,
    color: ink
)
drawText(
    "10:09",
    rect: NSRect(x: 1150, y: 687, width: 48, height: 18),
    font: .systemFont(ofSize: 12),
    color: ink
)

let popupRect = NSRect(x: 852, y: 219, width: 300, height: 454)
NSGraphicsContext.saveGraphicsState()
let popupShadow = NSShadow()
popupShadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
popupShadow.shadowBlurRadius = 28
popupShadow.shadowOffset = NSSize(width: 0, height: -10)
popupShadow.set()
roundedRect(
    popupRect,
    radius: 18,
    fill: NSColor.white.withAlphaComponent(0.97),
    stroke: NSColor.black.withAlphaComponent(0.08)
)
NSGraphicsContext.restoreGraphicsState()

drawText(
    "マイタスク",
    rect: NSRect(x: 870, y: 623, width: 180, height: 26),
    font: NSFont(name: "HiraginoSans-W6", size: 16) ?? .boldSystemFont(ofSize: 16),
    color: ink
)
drawSymbol(
    "arrow.clockwise",
    in: NSRect(x: 1080, y: 625, width: 16, height: 16),
    pointSize: 14,
    color: secondaryInk
)
drawSymbol(
    "rectangle.on.rectangle",
    in: NSRect(x: 1112, y: 625, width: 17, height: 16),
    pointSize: 14,
    color: secondaryInk
)

drawSymbol(
    "plus.circle.fill",
    in: NSRect(x: 871, y: 584, width: 18, height: 18),
    pointSize: 16,
    weight: .medium,
    color: NSColor(calibratedRed: 0.05, green: 0.48, blue: 0.96, alpha: 1)
)
drawText(
    "タスクを追加",
    rect: NSRect(x: 899, y: 582, width: 180, height: 24),
    font: NSFont(name: "HiraginoSans-W3", size: 14) ?? .systemFont(ofSize: 14),
    color: secondaryInk
)
NSColor.black.withAlphaComponent(0.09).setFill()
NSRect(x: 852, y: 568, width: 300, height: 1).fill()

let tasks = [
    "企画書の構成を見直す",
    "メールの返信をする",
    "明日の予定を確認",
    "資料を共有する",
    "買い物リストを整理",
    "アイデアをメモする",
    "請求書を確認する",
    "週末の予定を立てる"
]
for (index, task) in tasks.enumerated() {
    let y = 528 - CGFloat(index * 40)
    let circle = NSBezierPath(ovalIn: NSRect(x: 872, y: y + 3, width: 17, height: 17))
    NSColor(calibratedWhite: 0.24, alpha: 1).setStroke()
    circle.lineWidth = 1.6
    circle.stroke()
    drawText(
        task,
        rect: NSRect(x: 901, y: y, width: 220, height: 25),
        font: NSFont(name: "HiraginoSans-W4", size: 14) ?? .systemFont(ofSize: 14),
        color: ink
    )
}

roundedRect(
    NSRect(x: 1142, y: 257, width: 5, height: 260),
    radius: 2.5,
    fill: NSColor.black.withAlphaComponent(0.16)
)
roundedRect(
    NSRect(x: 1142, y: 430, width: 5, height: 78),
    radius: 2.5,
    fill: NSColor.black.withAlphaComponent(0.40)
)
NSGraphicsContext.restoreGraphicsState()

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fatalError("Failed to encode output")
}

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try png.write(to: outputURL)
print(outputURL.path)
