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

let glowRect = CGRect(x: 460, y: 380, width: 440, height: 440)
context.saveGState()
context.setShadow(
    offset: CGSize(width: 0, height: 0),
    blur: 110,
    color: color(0x16D68A, alpha: 0.62).cgColor
)
context.setFillColor(color(0x16D68A, alpha: 0.36).cgColor)
context.fillEllipse(in: glowRect)
context.restoreGState()

context.saveGState()
let framePath = NSBezierPath(
    roundedRect: CGRect(x: 72, y: 72, width: 880, height: 880),
    xRadius: 230,
    yRadius: 230
)
context.setStrokeColor(color(0xFFFFFF, alpha: 0.10).cgColor)
context.setLineWidth(8)
context.addPath(framePath.cgPath)
context.strokePath()
context.restoreGState()

context.setStrokeColor(color(0xFFFFFF, alpha: 0.10).cgColor)
context.setLineWidth(10)
for offset in [0, 1, 2] {
    let y = CGFloat(284 + (offset * 160))
    context.move(to: CGPoint(x: 144, y: y))
    context.addLine(to: CGPoint(x: 880, y: y))
    context.strokePath()
}
for offset in [0, 1, 2] {
    let x = CGFloat(212 + (offset * 200))
    context.move(to: CGPoint(x: x, y: 144))
    context.addLine(to: CGPoint(x: x, y: 880))
    context.strokePath()
}

func drawBar(x: CGFloat, low: CGFloat, high: CGFloat, open: CGFloat, close: CGFloat, bodyColor: NSColor) {
    context.setStrokeColor(color(0xF3F5F7, alpha: 0.95).cgColor)
    context.setLineWidth(24)
    context.setLineCap(.round)
    context.move(to: CGPoint(x: x, y: low))
    context.addLine(to: CGPoint(x: x, y: high))
    context.strokePath()

    let bodyY = min(open, close)
    let bodyHeight = max(abs(close - open), 48)
    let rect = CGRect(x: x - 52, y: bodyY, width: 104, height: bodyHeight)
    let path = NSBezierPath(roundedRect: rect, xRadius: 34, yRadius: 34)
    context.setFillColor(bodyColor.cgColor)
    context.addPath(path.cgPath)
    context.fillPath()
}

drawBar(
    x: 270,
    low: 248,
    high: 658,
    open: 326,
    close: 542,
    bodyColor: color(0xFFFFFF, alpha: 0.92)
)
drawBar(
    x: 512,
    low: 176,
    high: 824,
    open: 308,
    close: 706,
    bodyColor: color(0x16D68A, alpha: 1.0)
)
drawBar(
    x: 754,
    low: 360,
    high: 894,
    open: 438,
    close: 792,
    bodyColor: color(0xFFFFFF, alpha: 0.92)
)

let linePath = NSBezierPath()
linePath.move(to: CGPoint(x: 118, y: 214))
linePath.curve(
    to: CGPoint(x: 286, y: 406),
    controlPoint1: CGPoint(x: 160, y: 246),
    controlPoint2: CGPoint(x: 214, y: 334)
)
linePath.curve(
    to: CGPoint(x: 470, y: 338),
    controlPoint1: CGPoint(x: 340, y: 486),
    controlPoint2: CGPoint(x: 394, y: 372)
)
linePath.curve(
    to: CGPoint(x: 916, y: 896),
    controlPoint1: CGPoint(x: 626, y: 336),
    controlPoint2: CGPoint(x: 804, y: 742)
)

context.saveGState()
context.setShadow(
    offset: CGSize(width: 0, height: 16),
    blur: 42,
    color: color(0x16D68A, alpha: 0.5).cgColor
)
context.addPath(linePath.cgPath)
context.setStrokeColor(color(0x16D68A).cgColor)
context.setLineWidth(44)
context.setLineCap(.round)
context.setLineJoin(.round)
context.strokePath()
context.restoreGState()

let arrowPath = NSBezierPath()
arrowPath.move(to: CGPoint(x: 844, y: 888))
arrowPath.line(to: CGPoint(x: 972, y: 922))
arrowPath.line(to: CGPoint(x: 924, y: 792))
arrowPath.close()
context.setFillColor(color(0x16D68A).cgColor)
context.addPath(arrowPath.cgPath)
context.fillPath()

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
