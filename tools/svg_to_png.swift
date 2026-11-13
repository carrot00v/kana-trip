// SVG를 투명 없는 정사각 PNG로 바꾼다. macOS AppKit의 SVG 렌더러를 쓰므로 따로 설치할 것이 없다.
// 실행: swift tools/svg_to_png.swift 입력.svg 출력.png 1024
// make_app_icon.py가 swiftc로 컴파일해서 부른다.
import AppKit

let args = CommandLine.arguments
guard args.count == 4, let size = Int(args[3]), size > 0 else {
    FileHandle.standardError.write("usage: svg_to_png 입력.svg 출력.png 크기\n".data(using: .utf8)!)
    exit(2)
}
guard let image = NSImage(contentsOf: URL(fileURLWithPath: args[1])) else {
    FileHandle.standardError.write("SVG를 읽지 못했다: \(args[1])\n".data(using: .utf8)!)
    exit(1)
}
var rect = NSRect(x: 0, y: 0, width: size, height: size)
guard let source = image.cgImage(forProposedRect: &rect, context: nil, hints: nil),
      let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    FileHandle.standardError.write("그리기에 실패했다\n".data(using: .utf8)!)
    exit(1)
}
context.interpolationQuality = .high
context.draw(source, in: CGRect(x: 0, y: 0, width: size, height: size))
let output = NSBitmapImageRep(cgImage: context.makeImage()!)
try output.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
