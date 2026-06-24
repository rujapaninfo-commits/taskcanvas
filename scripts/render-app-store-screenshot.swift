import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let inputURL = root.appendingPathComponent("dist/app-store-screenshots/TaskCanvas-main-raw.png")
let outputURL = root.appendingPathComponent("dist/app-store-screenshots/TaskCanvas-main-1280x800.png")

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

func makeMockAppImage() -> NSImage {
    let image = NSImage(size: NSSize(width: 420, height: 580))
    image.lockFocus()

    let bounds = NSRect(x: 0, y: 0, width: 420, height: 580)
    roundedRect(bounds, radius: 24, fill: .white)

    NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.99, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: 58, height: 580).fill()
    NSColor.black.withAlphaComponent(0.08).setFill()
    NSRect(x: 58, y: 0, width: 1, height: 580).fill()

    let sidebarItems = ["T", "P"]
    for (index, item) in sidebarItems.enumerated() {
        let y = 512 - CGFloat(index * 44)
        roundedRect(
            NSRect(x: 12, y: y, width: 34, height: 30),
            radius: 9,
            fill: index == 0
                ? NSColor(calibratedRed: 0.18, green: 0.45, blue: 0.92, alpha: 0.12)
                : .clear
        )
        drawText(
            item,
            rect: NSRect(x: 22, y: y + 6, width: 18, height: 18),
            font: .boldSystemFont(ofSize: 13),
            color: index == 0 ? NSColor(calibratedRed: 0.12, green: 0.34, blue: 0.78, alpha: 1) : .secondaryLabelColor
        )
    }

    drawText(
        "Today",
        rect: NSRect(x: 84, y: 522, width: 220, height: 30),
        font: NSFont(name: "HiraginoSans-W6", size: 22) ?? .boldSystemFont(ofSize: 22),
        color: NSColor(calibratedWhite: 0.10, alpha: 1)
    )
    drawText(
        "通常アプリ表示",
        rect: NSRect(x: 84, y: 499, width: 220, height: 20),
        font: .systemFont(ofSize: 11),
        color: .secondaryLabelColor
    )

    drawSymbol(
        "arrow.clockwise",
        in: NSRect(x: 342, y: 527, width: 17, height: 17),
        pointSize: 15,
        color: .secondaryLabelColor
    )
    drawSymbol(
        "gearshape",
        in: NSRect(x: 376, y: 527, width: 17, height: 17),
        pointSize: 15,
        color: .secondaryLabelColor
    )

    drawSymbol(
        "plus.circle.fill",
        in: NSRect(x: 85, y: 462, width: 18, height: 18),
        pointSize: 16,
        weight: .medium,
        color: NSColor(calibratedRed: 0.05, green: 0.48, blue: 0.96, alpha: 1)
    )
    drawText(
        "タスクを追加",
        rect: NSRect(x: 112, y: 459, width: 160, height: 24),
        font: .systemFont(ofSize: 14),
        color: .secondaryLabelColor
    )
    NSColor.black.withAlphaComponent(0.08).setFill()
    NSRect(x: 58, y: 445, width: 362, height: 1).fill()

    let tasks: [(String, Int, Bool)] = [
        ("今日の優先タスクを3つに絞る", 0, false),
        ("レビュー用の動作確認", 0, false),
        ("サブタスクもそのまま管理", 1, false),
        ("メニューバーから素早く追加する", 0, false),
        ("資料を共有する", 0, false),
        ("完了済みタスクの表示切替", 0, true)
    ]

    for (index, task) in tasks.enumerated() {
        let y = 396 - CGFloat(index * 54)
        let x = 86 + CGFloat(task.1 * 22)
        let circleRect = NSRect(x: x, y: y + 4, width: 18, height: 18)
        let circle = NSBezierPath(ovalIn: circleRect)
        NSColor(calibratedWhite: 0.25, alpha: task.2 ? 0.30 : 1).setStroke()
        circle.lineWidth = 1.6
        circle.stroke()
        if task.2 {
            drawSymbol(
                "checkmark",
                in: NSRect(x: x + 4, y: y + 8, width: 10, height: 8),
                pointSize: 9,
                weight: .medium,
                color: .secondaryLabelColor
            )
        }
        drawText(
            task.0,
            rect: NSRect(x: x + 30, y: y, width: 270, height: 26),
            font: NSFont(name: "HiraginoSans-W4", size: 14) ?? .systemFont(ofSize: 14),
            color: task.2 ? .secondaryLabelColor : NSColor(calibratedWhite: 0.12, alpha: 1)
        )
        if index < tasks.count - 1 {
            NSColor.black.withAlphaComponent(0.04).setFill()
            NSRect(x: 84, y: y - 18, width: 300, height: 1).fill()
        }
    }

    image.unlockFocus()
    return image
}

let appImage = NSImage(contentsOf: inputURL) ?? makeMockAppImage()

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

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try png.write(to: outputURL)
print(outputURL.path)
