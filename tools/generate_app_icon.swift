import AppKit

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "assets/branding/app_icon_master.png"

let outputURL = URL(fileURLWithPath: outputPath)
let size = CGSize(width: 1024, height: 1024)

let image = NSImage(size: size)
image.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else {
    fputs("Failed to create graphics context.\n", stderr)
    exit(1)
}

let canvas = CGRect(origin: .zero, size: size)

func color(_ hex: UInt32, alpha: CGFloat = 1.0) -> NSColor {
    let red = CGFloat((hex >> 16) & 0xFF) / 255.0
    let green = CGFloat((hex >> 8) & 0xFF) / 255.0
    let blue = CGFloat(hex & 0xFF) / 255.0
    return NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
}

context.setFillColor(color(0x101315).cgColor)
context.fill(canvas)

let gradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        color(0x101315).cgColor,
        color(0x132A24).cgColor,
        color(0x16D68A).withAlphaComponent(0.70).cgColor,
    ] as CFArray,
    locations: [0.0, 0.58, 1.0]
)!
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 140, y: 120),
    end: CGPoint(x: 900, y: 950),
    options: []
)

let glowRect = CGRect(x: 540, y: 520, width: 360, height: 360)
context.saveGState()
context.setShadow(
    offset: CGSize(width: 0, height: 0),
    blur: 90,
    color: color(0x16D68A, alpha: 0.55).cgColor
)
context.setFillColor(color(0x16D68A, alpha: 0.32).cgColor)
context.fillEllipse(in: glowRect)
context.restoreGState()

context.saveGState()
let framePath = NSBezierPath(roundedRect: CGRect(x: 150, y: 150, width: 724, height: 724), xRadius: 180, yRadius: 180)
context.setStrokeColor(color(0xFFFFFF, alpha: 0.10).cgColor)
context.setLineWidth(10)
context.addPath(framePath.cgPath)
context.strokePath()
context.restoreGState()

context.setStrokeColor(color(0xFFFFFF, alpha: 0.10).cgColor)
context.setLineWidth(8)
for offset in [0, 1, 2] {
    let y = CGFloat(330 + (offset * 110))
    context.move(to: CGPoint(x: 250, y: y))
    context.addLine(to: CGPoint(x: 774, y: y))
    context.strokePath()
}
for offset in [0, 1, 2] {
    let x = CGFloat(290 + (offset * 150))
    context.move(to: CGPoint(x: x, y: 250))
    context.addLine(to: CGPoint(x: x, y: 774))
    context.strokePath()
}

func drawBar(x: CGFloat, low: CGFloat, high: CGFloat, open: CGFloat, close: CGFloat, bodyColor: NSColor) {
    context.setStrokeColor(color(0xF3F5F7, alpha: 0.95).cgColor)
    context.setLineWidth(20)
    context.setLineCap(.round)
    context.move(to: CGPoint(x: x, y: low))
    context.addLine(to: CGPoint(x: x, y: high))
    context.strokePath()

    let bodyY = min(open, close)
    let bodyHeight = max(abs(close - open), 36)
    let rect = CGRect(x: x - 42, y: bodyY, width: 84, height: bodyHeight)
    let path = NSBezierPath(roundedRect: rect, xRadius: 28, yRadius: 28)
    context.setFillColor(bodyColor.cgColor)
    context.addPath(path.cgPath)
    context.fillPath()
}

drawBar(
    x: 360,
    low: 360,
    high: 610,
    open: 420,
    close: 540,
    bodyColor: color(0xFFFFFF, alpha: 0.92)
)
drawBar(
    x: 520,
    low: 300,
    high: 700,
    open: 380,
    close: 640,
    bodyColor: color(0x16D68A, alpha: 1.0)
)
drawBar(
    x: 680,
    low: 430,
    high: 790,
    open: 500,
    close: 720,
    bodyColor: color(0xFFFFFF, alpha: 0.92)
)

let linePath = NSBezierPath()
linePath.move(to: CGPoint(x: 250, y: 350))
linePath.curve(
    to: CGPoint(x: 370, y: 470),
    controlPoint1: CGPoint(x: 285, y: 370),
    controlPoint2: CGPoint(x: 325, y: 415)
)
linePath.curve(
    to: CGPoint(x: 535, y: 430),
    controlPoint1: CGPoint(x: 420, y: 525),
    controlPoint2: CGPoint(x: 475, y: 455)
)
linePath.curve(
    to: CGPoint(x: 760, y: 760),
    controlPoint1: CGPoint(x: 615, y: 430),
    controlPoint2: CGPoint(x: 700, y: 645)
)

context.saveGState()
context.setShadow(
    offset: CGSize(width: 0, height: 16),
    blur: 30,
    color: color(0x16D68A, alpha: 0.45).cgColor
)
context.addPath(linePath.cgPath)
context.setStrokeColor(color(0x16D68A).cgColor)
context.setLineWidth(34)
context.setLineCap(.round)
context.setLineJoin(.round)
context.strokePath()
context.restoreGState()

let arrowPath = NSBezierPath()
arrowPath.move(to: CGPoint(x: 710, y: 755))
arrowPath.line(to: CGPoint(x: 822, y: 782))
arrowPath.line(to: CGPoint(x: 778, y: 676))
arrowPath.close()
context.setFillColor(color(0x16D68A).cgColor)
context.addPath(arrowPath.cgPath)
context.fillPath()

let badgeRect = CGRect(x: 220, y: 730, width: 165, height: 84)
let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: 34, yRadius: 34)
context.setFillColor(color(0xFFFFFF, alpha: 0.92).cgColor)
context.addPath(badgePath.cgPath)
context.fillPath()

let badgeText = "M"
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 54, weight: .black),
    .foregroundColor: color(0x101315),
    .paragraphStyle: paragraph,
]
let attributed = NSAttributedString(string: badgeText, attributes: attributes)
attributed.draw(in: CGRect(x: 220, y: 744, width: 165, height: 60))

image.unlockFocus()

guard
    let tiffData = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiffData),
    let pngData = bitmap.representation(using: .png, properties: [:])
else {
    fputs("Failed to encode PNG.\n", stderr)
    exit(1)
}

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try pngData.write(to: outputURL)
