import Foundation

// Usage: render-test-vault <templates dir> <output dir> [YYYY-MM-DD]
let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    FileHandle.standardError.write(Data("usage: render-test-vault <templates> <output> [YYYY-MM-DD]\n".utf8))
    exit(1)
}
var renderer = TestVaultRenderer(today: Date())
if arguments.count >= 4 {
    let parts = arguments[3].split(separator: "-").compactMap { Int($0) }
    if parts.count == 3 { renderer = TestVaultRenderer(year: parts[0], month: parts[1], day: parts[2]) }
}
do {
    try renderer.renderVault(from: URL(fileURLWithPath: arguments[1]), to: URL(fileURLWithPath: arguments[2]))
    print("Rendered test vault to \(arguments[2])")
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}
