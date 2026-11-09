// Menggambar ikon aplikasi ClipBar (1024×1024 PNG).
// Pemakaian: swift Tools/make_icon.swift <output.png>
import AppKit

let size: CGFloat = 1024
let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"

guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                 colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0),
      let gctx = NSGraphicsContext(bitmapImageRep: rep) else {
    fatalError("Tidak bisa membuat kanvas")
}
rep.size = NSSize(width: size, height: size)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = gctx
let ctx = gctx.cgContext

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
}

func rotated(_ degrees: CGFloat, around c: CGPoint, _ draw: () -> Void) {
    ctx.saveGState()
    ctx.translateBy(x: c.x, y: c.y)
    ctx.rotate(by: degrees * .pi / 180)
    ctx.translateBy(x: -c.x, y: -c.y)
    draw()
    ctx.restoreGState()
}

func rounded(_ rect: CGRect, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

// 1. Latar: squircle dengan gradien indigo → ungu → pink
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = rounded(tile, 186)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.28).cgColor)
rgb(0x5B4BEA).setFill()
tilePath.fill()
ctx.restoreGState()

NSGradient(colors: [rgb(0x4F5BF5), rgb(0x7C4DF2), rgb(0xC44CE6), rgb(0xF0609E)],
           atLocations: [0, 0.38, 0.72, 1], colorSpace: .sRGB)!
    .draw(in: tilePath, angle: -55)

ctx.saveGState()
tilePath.addClip()
// Kilau di kiri atas
NSGradient(starting: NSColor.white.withAlphaComponent(0.34), ending: NSColor.white.withAlphaComponent(0))!
    .draw(fromCenter: CGPoint(x: 300, y: 860), radius: 0, toCenter: CGPoint(x: 300, y: 860), radius: 600, options: [])
// Bayangan halus di bawah
NSGradient(starting: NSColor.black.withAlphaComponent(0), ending: NSColor.black.withAlphaComponent(0.16))!
    .draw(in: tile, angle: -90)
ctx.restoreGState()

let rim = rounded(tile.insetBy(dx: 2, dy: 2), 184)
rim.lineWidth = 4
NSColor.white.withAlphaComponent(0.20).setStroke()
rim.stroke()

// 2. Tumpukan kartu clipboard
let center = CGPoint(x: 512, y: 480)
let card = CGRect(x: 302, y: 214, width: 420, height: 524)

rotated(-12, around: center) {
    NSColor.white.withAlphaComponent(0.20).setFill()
    rounded(card.offsetBy(dx: -30, dy: 10), 60).fill()
}
rotated(7, around: center) {
    NSColor.white.withAlphaComponent(0.38).setFill()
    rounded(card.offsetBy(dx: 24, dy: 6), 60).fill()
}

let cardPath = rounded(card, 60)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -20), blur: 40, color: rgb(0x2A0E6B, 0.45).cgColor)
NSColor.white.setFill()
cardPath.fill()
ctx.restoreGState()
NSGradient(starting: NSColor.white, ending: rgb(0xEDEBFF))!.draw(in: cardPath, angle: -90)

// 3. Penjepit di atas kartu
let clip = CGRect(x: 512 - 104, y: card.maxY - 50, width: 208, height: 100)
let clipPath = rounded(clip, 34)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 16, color: rgb(0x1E1B4B, 0.45).cgColor)
rgb(0x2B2768).setFill()
clipPath.fill()
ctx.restoreGState()
NSGradient(starting: rgb(0x3F3A9E), ending: rgb(0x1E1B4B))!.draw(in: clipPath, angle: -90)
let slot = CGRect(x: 512 - 46, y: clip.maxY - 40, width: 92, height: 22)
rgb(0xFFFFFF, 0.9).setFill()
rounded(slot, 11).fill()

// 4. Baris teks; baris pertama "terpilih" dengan gradien merek
let lineX: CGFloat = card.minX + 58
let lineH: CGFloat = 36
let widths: [CGFloat] = [304, 250, 286, 180]
var y: CGFloat = card.maxY - 140
for (index, width) in widths.enumerated() {
    let rect = CGRect(x: lineX, y: y, width: width, height: lineH)
    let path = rounded(rect, lineH / 2)
    if index == 0 {
        NSGradient(colors: [rgb(0x5B5CF6), rgb(0xA855F7), rgb(0xEC4899)])!.draw(in: path, angle: 0)
    } else {
        rgb(0xD9D8F5).setFill()
        path.fill()
    }
    y -= 74
}

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("Gagal encode PNG") }
try png.write(to: URL(fileURLWithPath: output))
print("Ikon ditulis ke \(output)")
