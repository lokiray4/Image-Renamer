import Foundation

@main struct Tests {
    static func main() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }
        let source = dir.appendingPathComponent("原图.JPG")
        let data = Data([1, 2, 3, 4])
        try data.write(to: source)
        let record = try RenameEngine.rename(source, input: "海边日落.jpg")!
        precondition(record.after.lastPathComponent == "海边日落.JPG")
        precondition(tryData(record.after) == data)
        precondition(!fm.fileExists(atPath: source.path))
        let unchanged = try RenameEngine.rename(record.after, input: "海边日落")
        precondition(unchanged == nil)
        try RenameEngine.undo(record)
        precondition(tryData(source) == data)
        let existing = dir.appendingPathComponent("已存在.JPG")
        try Data([9]).write(to: existing)
        do {
            _ = try RenameEngine.rename(source, input: "已存在")
            fatalError("Collision was allowed")
        } catch RenameFailure.exists {}
        precondition(tryData(existing) == Data([9]))
        precondition(tryData(source) == data)
        for input in ["", "   ", ".", "..", "a/b", "a:b", "a\nb"] {
            do {
                _ = try RenameEngine.destination(for: source, input: input)
                fatalError("Invalid filename was allowed")
            } catch is RenameFailure {}
        }
        let first = try RenameEngine.rename(source, input: "第一步")!
        let second = try RenameEngine.rename(first.after, input: "第二步")!
        try RenameEngine.undo(second)
        try RenameEngine.undo(first)
        precondition(tryData(source) == data)
        // Undo must also refuse to overwrite an externally recreated source.
        let last = try RenameEngine.rename(source, input: "最后")!
        try Data([7]).write(to: source)
        do { try RenameEngine.undo(last); fatalError("Undo overwrote a file") }
        catch RenameFailure.exists {}
        precondition(tryData(source) == Data([7]))
        precondition(tryData(last.after) == data)
        print("PASS: rename, preserved bytes/extension, collision protection, validation, repeated rename and undo safety")
    }
    static func tryData(_ url: URL) -> Data { try! Data(contentsOf: url) }
}
