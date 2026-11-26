import AppKit

let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSGraphicsContext.current?.imageInterpolation = .high
let bounds = CGRect(x: 0, y: 0, width: size, height: size)
let icon = NSBezierPath(roundedRect: bounds.insetBy(dx: 14, dy: 14), xRadius: 220, yRadius: 220)
NSGradient(colors: [NSColor(calibratedRed: 0.34, green: 0.64, blue: 1, alpha: 1), NSColor(calibratedRed: 0.35, green: 0.28, blue: 0.82, alpha: 1), NSColor(calibratedRed: 0.20, green: 0.15, blue: 0.43, alpha: 1)])!.draw(in: icon, angle: -55)

let colors: [NSColor] = [
    NSColor(calibratedRed: 0.95, green: 0.42, blue: 0.48, alpha: 1), NSColor(calibratedRed: 1, green: 0.67, blue: 0.30, alpha: 1), NSColor(calibratedRed: 0.99, green: 0.82, blue: 0.38, alpha: 1),
    NSColor(calibratedRed: 0.34, green: 0.82, blue: 0.66, alpha: 1), NSColor(calibratedRed: 0.43, green: 0.76, blue: 1, alpha: 1), NSColor(calibratedRed: 0.56, green: 0.59, blue: 1, alpha: 1),
    NSColor(calibratedRed: 0.73, green: 0.53, blue: 0.98, alpha: 1), NSColor(calibratedRed: 0.96, green: 0.49, blue: 0.73, alpha: 1), NSColor(calibratedRed: 0.48, green: 0.84, blue: 0.91, alpha: 1)
]
let tile = 204.0, gap = 28.0, start = 183.0
for row in 0..<3 {
    for col in 0..<3 {
        let i = row * 3 + col
        let rect = CGRect(x: start + Double(col) * (tile + gap), y: start + Double(2 - row) * (tile + gap), width: tile, height: tile)
        let path = NSBezierPath(roundedRect: rect, xRadius: 57, yRadius: 57)
        NSGraphicsContext.saveGraphicsState()
        NSColor.white.withAlphaComponent(0.2).setFill(); path.fill()
        let inset = rect.insetBy(dx: 8, dy: 8)
        let face = NSBezierPath(roundedRect: inset, xRadius: 51, yRadius: 51)
        NSGradient(colors: [colors[i].blended(withFraction: 0.36, of: .white)!, colors[i]])!.draw(in: face, angle: -45)
        NSGraphicsContext.restoreGraphicsState()
    }
}
NSGraphicsContext.restoreGraphicsState()
let png = bitmap.representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
