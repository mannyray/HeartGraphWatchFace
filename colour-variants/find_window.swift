// Find the main Connect IQ Device Simulator window and print its window ID.
// Used by generate.py to drive `screencapture -l`.
//
// Prefers the window whose title is "CIQ Simulator" (the main watch-face
// window) over "largest by area" — sub-windows opened by sim features
// (persistence editor, dialogs, etc.) can sometimes be larger than the
// main face window and would otherwise win on area alone.
import Cocoa

let opts = CGWindowListOption(arrayLiteral: .optionAll)
let windows = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] ?? []

var fallbackBest: (id: Int, area: Int)? = nil

for w in windows {
    let owner = w[kCGWindowOwnerName as String] as? String ?? ""
    if !owner.lowercased().contains("imulator") { continue }
    let layer = w[kCGWindowLayer as String] as? Int ?? 0
    if layer != 0 { continue }
    let bounds = w[kCGWindowBounds as String] as? [String: Any] ?? [:]
    let width = bounds["Width"] as? Int ?? 0
    let height = bounds["Height"] as? Int ?? 0
    if height < 100 || width < 100 { continue }
    let num = w[kCGWindowNumber as String] as? Int ?? 0
    let name = w[kCGWindowName as String] as? String ?? ""
    // Strong preference: the main face window's title starts with
    // "CIQ Simulator" (e.g. "CIQ Simulator - Forerunner® 955 / Solar (5.2.0)").
    if name.hasPrefix("CIQ Simulator") {
        print(num)
        exit(0)
    }
    let area = width * height
    if fallbackBest == nil || area > fallbackBest!.area {
        fallbackBest = (id: num, area: area)
    }
}

if let b = fallbackBest {
    print(b.id)
    exit(0)
}
fputs("no simulator window found\n", stderr)
exit(1)
