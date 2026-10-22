import Foundation

enum RenameFailure: LocalizedError {
    case empty, invalid, exists, missing
    var errorDescription: String? {
        switch self {
        case .empty: return "请输入新的图片名称。"
        case .invalid: return "名称不能是 . 或 ..，也不能包含 /、:、换行或控制字符。"
        case .exists: return "文件夹中已存在这个名称。请换一个名称，原文件不会被覆盖。"
        case .missing: return "原文件已被移动或删除，请重新选择文件夹。"
        }
    }
}

struct RenameRecord {
    let before: URL
    let after: URL
}

enum RenameEngine {
    static func destination(for source: URL, input: String) throws -> URL {
        var name = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let ext = source.pathExtension
        // The text field contains the stem; tolerate a pasted full filename.
        if !ext.isEmpty && name.lowercased().hasSuffix("." + ext.lowercased()) {
            name = String(name.dropLast(ext.count + 1))
        }
        guard !name.isEmpty else { throw RenameFailure.empty }
        guard name != ".", name != "..", !name.contains("/"), !name.contains(":"),
              !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw RenameFailure.invalid
        }
        return source.deletingLastPathComponent().appendingPathComponent(name + (ext.isEmpty ? "" : "." + ext))
    }

    @discardableResult
    static func rename(_ source: URL, input: String) throws -> RenameRecord? {
        let target = try destination(for: source, input: input)
        guard FileManager.default.fileExists(atPath: source.path) else { throw RenameFailure.missing }
        if source.lastPathComponent == target.lastPathComponent { return nil }
        // Deliberately refuse even case-only collisions on case-insensitive volumes.
        guard !FileManager.default.fileExists(atPath: target.path) else { throw RenameFailure.exists }
        try FileManager.default.moveItem(at: source, to: target)
        return RenameRecord(before: source, after: target)
    }

    static func undo(_ record: RenameRecord) throws {
        guard FileManager.default.fileExists(atPath: record.after.path) else { throw RenameFailure.missing }
        guard !FileManager.default.fileExists(atPath: record.before.path) else { throw RenameFailure.exists }
        try FileManager.default.moveItem(at: record.after, to: record.before)
    }
}
