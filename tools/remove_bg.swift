// 단색 바탕 위에 그린 아이템 그림에서 바탕을 지워 투명 PNG로 만든다.
// 그림 가장자리에서 시작해 바탕색과 비슷한 픽셀만 따라가며 지우므로,
// 진갈색 외곽선 안쪽(아이템의 흰 면 등)은 바탕과 색이 비슷해도 지워지지 않는다.
// 실행: swift tools/remove_bg.swift 입력.png 출력.png [허용차 기본 40]
import AppKit

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write("usage: remove_bg 입력.png 출력.png [허용차]\n".data(using: .utf8)!)
    exit(2)
}
let hard = Double(args.count > 3 ? args[3] : "40") ?? 40   // 이 거리 안이면 완전히 지운다
let soft = hard * 1.8                                      // 이 거리까지는 반투명으로 가장자리를 부드럽게

guard let image = NSImage(contentsOf: URL(fileURLWithPath: args[1])),
      let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write("그림을 읽지 못했다: \(args[1])\n".data(using: .utf8)!)
    exit(1)
}
let w = cg.width, h = cg.height
var px = [UInt8](repeating: 0, count: w * h * 4)
let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

// 바탕색: 네 변의 픽셀 중앙값
var border: [(Double, Double, Double)] = []
for x in stride(from: 0, to: w, by: 4) { for y in [0, h - 1] { let i = (y * w + x) * 4; border.append((Double(px[i]), Double(px[i + 1]), Double(px[i + 2]))) } }
for y in stride(from: 0, to: h, by: 4) { for x in [0, w - 1] { let i = (y * w + x) * 4; border.append((Double(px[i]), Double(px[i + 1]), Double(px[i + 2]))) } }
func median(_ v: [Double]) -> Double { let s = v.sorted(); return s[s.count / 2] }
let bg = (median(border.map { $0.0 }), median(border.map { $0.1 }), median(border.map { $0.2 }))

func dist(_ i: Int) -> Double {
    let r = Double(px[i]) - bg.0, g = Double(px[i + 1]) - bg.1, b = Double(px[i + 2]) - bg.2
    return (r * r + g * g + b * b).squareRoot()
}

var alpha = [UInt8](repeating: 255, count: w * h)
var seen = [Bool](repeating: false, count: w * h)
var stack: [Int] = []
for x in 0..<w { stack.append(x); stack.append((h - 1) * w + x) }
for y in 0..<h { stack.append(y * w); stack.append(y * w + w - 1) }
var removed = 0
while let p = stack.popLast() {
    if seen[p] { continue }
    seen[p] = true
    let d = dist(p * 4)
    if d < hard {
        alpha[p] = 0
        removed += 1
        let x = p % w, y = p / w
        if x > 0 { stack.append(p - 1) }
        if x < w - 1 { stack.append(p + 1) }
        if y > 0 { stack.append(p - w) }
        if y < h - 1 { stack.append(p + w) }
    } else if d < soft {
        alpha[p] = UInt8(255 * (d - hard) / (soft - hard))
    }
}

// 반투명 가장자리는 바탕색을 빼서 테두리에 바탕색 테가 남지 않게 한다
var out = [UInt8](repeating: 0, count: w * h * 4)
for p in 0..<(w * h) {
    let i = p * 4, a = Double(alpha[p]) / 255
    if a == 0 { continue }
    if a < 1 {
        let un = { (c: UInt8, b: Double) -> Double in min(255, max(0, (Double(c) - b * (1 - a)) / a)) }
        out[i] = UInt8(un(px[i], bg.0) * a); out[i + 1] = UInt8(un(px[i + 1], bg.1) * a); out[i + 2] = UInt8(un(px[i + 2], bg.2) * a)
    } else {
        out[i] = px[i]; out[i + 1] = px[i + 1]; out[i + 2] = px[i + 2]
    }
    out[i + 3] = alpha[p]
}
let octx = CGContext(data: &out, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                     space: CGColorSpace(name: CGColorSpace.sRGB)!,
                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let rep = NSBitmapImageRep(cgImage: octx.makeImage()!)
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
print(String(format: "바탕 rgb(%.0f,%.0f,%.0f), 지운 비율 %.0f%%", bg.0, bg.1, bg.2, Double(removed) * 100 / Double(w * h)))
