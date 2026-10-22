import AppKit
import UniformTypeIdentifiers

final class PreviewPane: NSScrollView {
    let picture = NSImageView()
    private let canvas = NSView()
    var originalSize = NSSize.zero
    var scale: CGFloat = 1
    var fits = true
    var zoomChanged: ((String) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        drawsBackground = true
        backgroundColor = NSColor(calibratedWhite: 0.10, alpha: 1)
        hasVerticalScroller = true
        hasHorizontalScroller = true
        autohidesScrollers = true
        documentView = canvas
        picture.imageScaling = .scaleAxesIndependently
        canvas.addSubview(picture)
    }
    required init?(coder: NSCoder) { fatalError() }
    func show(_ image: NSImage?) {
        picture.image = image
        originalSize = image?.size ?? .zero
        fits = true
        resizePicture()
        contentView.scroll(to: .zero)
    }
    override func layout() {
        super.layout()
        resizePicture()
    }
    func resizePicture() {
        let viewport = contentSize
        guard originalSize.width > 0, originalSize.height > 0 else {
            picture.frame = .zero
            canvas.setFrameSize(viewport)
            zoomChanged?("—")
            return
        }
        if fits {
            scale = min(max(1, viewport.width - 48) / originalSize.width,
                        max(1, viewport.height - 48) / originalSize.height)
        }
        let size = NSSize(width: originalSize.width * scale, height: originalSize.height * scale)
        let bounds = NSSize(width: max(viewport.width, size.width + 48), height: max(viewport.height, size.height + 48))
        canvas.setFrameSize(bounds)
        picture.frame = NSRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2, width: size.width, height: size.height)
        zoomChanged?(String(format: "%.0f%%", scale * 100))
    }
    func zoom(_ factor: CGFloat) {
        guard picture.image != nil else { return }
        fits = false
        scale = min(12, max(0.02, scale * factor))
        resizePicture()
        let center = NSPoint(x: max(0, (canvas.bounds.width - contentSize.width) / 2), y: max(0, (canvas.bounds.height - contentSize.height) / 2))
        contentView.scroll(to: center)
        reflectScrolledClipView(contentView)
    }
    override func magnify(with event: NSEvent) { zoom(1 + event.magnification) }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSWindowDelegate {
    var window: NSWindow!
    let table = NSTableView()
    let preview = PreviewPane()
    let nameField = NSTextField()
    let currentLabel = NSTextField(labelWithString: "选择一个图片文件夹，开始整理")
    let folderLabel = NSTextField(labelWithString: "尚未选择文件夹")
    let progressLabel = NSTextField(labelWithString: "0 / 0")
    let extensionLabel = NSTextField(labelWithString: "扩展名自动保留")
    let zoomLabel = NSTextField(labelWithString: "—")
    let statusLabel = NSTextField(labelWithString: "只读取所选文件夹的第一层；原图内容不会改变。")
    let emptyLabel = NSTextField(labelWithString: "选择文件夹后，在这里放大查看图片")
    var previousButton: NSButton!
    var nextButton: NSButton!
    var saveButton: NSButton!
    var saveNextButton: NSButton!
    var undoButton: NSButton!
    var files: [URL] = []
    var index = -1
    var records: [RenameRecord] = []
    var savedStem = ""
    var changingSelection = false
    var folder: URL?

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        buildWindow()
        updateControls()
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return resolveDraft() ? .terminateNow : .terminateCancel
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { resolveDraft() }

    func button(_ title: String, _ action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded
        return b
    }
    func stack(_ views: [NSView], vertical: Bool = false, spacing: CGFloat = 10) -> NSStackView {
        let s = NSStackView(views: views)
        s.orientation = vertical ? .vertical : .horizontal
        s.alignment = vertical ? .leading : .centerY
        s.spacing = spacing
        return s
    }
    func pin(_ view: NSView, in parent: NSView, inset: CGFloat = 0) {
        view.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: inset),
            view.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -inset),
            view.topAnchor.constraint(equalTo: parent.topAnchor, constant: inset),
            view.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -inset)
        ])
    }
    func buildMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        menu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "关于 逐图改名", action: #selector(about), keyEquivalent: "") .target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出 逐图改名", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let fileItem = NSMenuItem()
        menu.addItem(fileItem)
        let fileMenu = NSMenu(title: "文件")
        fileItem.submenu = fileMenu
        for (title, action, key) in [("选择文件夹…", #selector(chooseFolder), "o"), ("保存并下一张", #selector(saveNext), "\r"), ("上一张", #selector(previous), "["), ("下一张", #selector(next), "]"), ("撤销上次重命名", #selector(undoRename), "z")] {
            fileMenu.addItem(withTitle: title, action: action, keyEquivalent: key).target = self
        }
        let editItem = NSMenuItem()
        menu.addItem(editItem)
        let edit = NSMenu(title: "编辑")
        editItem.submenu = edit
        for (title, action, key) in [("剪切", #selector(NSText.cut(_:)), "x"), ("复制", #selector(NSText.copy(_:)), "c"), ("粘贴", #selector(NSText.paste(_:)), "v"), ("全选", #selector(NSText.selectAll(_:)), "a")] {
            edit.addItem(withTitle: title, action: action, keyEquivalent: key)
        }
        NSApp.mainMenu = menu
    }
    func buildWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 820), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "逐图改名"
        window.minSize = NSSize(width: 860, height: 620)
        window.delegate = self
        window.isReleasedWhenClosed = false
        let root = NSView()
        window.contentView = root
        let choose = button("选择文件夹…", #selector(chooseFolder))
        choose.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
        choose.imagePosition = .imageLeading
        folderLabel.lineBreakMode = .byTruncatingMiddle
        folderLabel.textColor = .secondaryLabelColor
        folderLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        progressLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        let top = stack([choose, folderLabel, NSView(), progressLabel])
        top.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(top)

        let sidebar = NSScrollView()
        sidebar.hasVerticalScroller = true
        sidebar.autohidesScrollers = true
        sidebar.borderType = .noBorder
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("filename"))
        column.title = "图片列表"
        column.width = 230
        table.addTableColumn(column)
        table.headerView = nil
        table.rowHeight = 38
        table.style = .sourceList
        table.dataSource = self
        table.delegate = self
        table.allowsEmptySelection = false
        sidebar.documentView = table
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(sidebar)

        let previewBox = NSView()
        previewBox.wantsLayer = true
        previewBox.layer?.cornerRadius = 12
        previewBox.layer?.masksToBounds = true
        pin(preview, in: previewBox)
        emptyLabel.textColor = NSColor(calibratedWhite: 0.68, alpha: 1)
        emptyLabel.font = .systemFont(ofSize: 16)
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        previewBox.addSubview(emptyLabel)
        NSLayoutConstraint.activate([emptyLabel.centerXAnchor.constraint(equalTo: previewBox.centerXAnchor), emptyLabel.centerYAnchor.constraint(equalTo: previewBox.centerYAnchor)])
        currentLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        currentLabel.lineBreakMode = .byTruncatingMiddle
        currentLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let zoomOut = button("−", #selector(zoomOut))
        let zoomIn = button("＋", #selector(zoomIn))
        let fit = button("适应窗口", #selector(fitImage))
        let actual = button("100%", #selector(actualSize))
        zoomLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        zoomLabel.widthAnchor.constraint(equalToConstant: 50).isActive = true
        let info = stack([currentLabel, NSView(), zoomOut, zoomLabel, zoomIn, fit, actual], spacing: 6)
        let title = NSTextField(labelWithString: "输入新的图片名称")
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        extensionLabel.textColor = .secondaryLabelColor
        let nameTitle = stack([title, NSView(), extensionLabel])
        nameField.font = .systemFont(ofSize: 20)
        nameField.placeholderString = "在这里输入描述，例如：海边日落"
        nameField.bezelStyle = .roundedBezel
        nameField.focusRingType = .default
        nameField.delegate = self
        nameField.target = self
        nameField.action = #selector(saveNext)
        nameField.heightAnchor.constraint(equalToConstant: 42).isActive = true
        previousButton = button("← 上一张", #selector(previous))
        nextButton = button("下一张 →", #selector(next))
        saveButton = button("仅保存", #selector(saveOnly))
        saveNextButton = button("保存并下一张 ↵", #selector(saveNext))
        saveNextButton.bezelColor = .controlAccentColor
        undoButton = button("撤销重命名", #selector(undoRename))
        let actions = stack([previousButton, nextButton, undoButton, NSView(), saveButton, saveNextButton])
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail
        let right = stack([info, previewBox, nameTitle, nameField, actions, statusLabel], vertical: true, spacing: 12)
        right.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(right)
        for child in [info, previewBox, nameTitle, nameField, actions, statusLabel] {
            child.widthAnchor.constraint(equalTo: right.widthAnchor).isActive = true
        }
        previewBox.heightAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true
        NSLayoutConstraint.activate([
            top.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            top.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            top.topAnchor.constraint(equalTo: root.topAnchor, constant: 16),
            top.heightAnchor.constraint(equalToConstant: 32),
            sidebar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: top.bottomAnchor, constant: 16),
            sidebar.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 230),
            right.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: 20),
            right.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            right.topAnchor.constraint(equalTo: sidebar.topAnchor),
            right.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -18)
        ])
        preview.zoomChanged = { [weak self] in self?.zoomLabel.stringValue = $0 }
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
    func numberOfRows(in tableView: NSTableView) -> Int { files.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = NSTableCellView()
        let text = NSTextField(labelWithString: "\(row + 1).  \(files[row].lastPathComponent)")
        text.lineBreakMode = .byTruncatingMiddle
        text.font = .systemFont(ofSize: 12)
        text.toolTip = files[row].lastPathComponent
        cell.textField = text
        pin(text, in: cell, inset: 8)
        return cell
    }
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !changingSelection, table.selectedRow >= 0, table.selectedRow != index else { return }
        let desired = table.selectedRow
        if resolveDraft() { display(desired) } else { selectRow(index) }
    }
    func selectRow(_ row: Int) {
        changingSelection = true
        table.selectRowIndexes(row >= 0 ? IndexSet(integer: row) : IndexSet(), byExtendingSelection: false)
        if row >= 0 { table.scrollRowToVisible(row) }
        changingSelection = false
    }
    var dirty: Bool { index >= 0 && nameField.stringValue != savedStem }
    func resolveDraft() -> Bool {
        guard dirty else { return true }
        let alert = NSAlert()
        alert.messageText = "保存当前图片的新名称？"
        alert.informativeText = "输入的名称尚未保存。"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "不保存")
        alert.addButton(withTitle: "取消")
        switch alert.runModal() {
        case .alertFirstButtonReturn: return commit()
        case .alertSecondButtonReturn:
            nameField.stringValue = savedStem
            return true
        default: return false
        }
    }
    @objc func chooseFolder() {
        guard resolveDraft() else { return }
        let panel = NSOpenPanel()
        panel.title = "选择需要重命名的图片文件夹"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let entries = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles])
            let images = entries.filter { item in
                guard let values = try? item.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]), values.isRegularFile == true, values.isSymbolicLink != true else { return false }
                return UTType(filenameExtension: item.pathExtension)?.conforms(to: .image) == true
            }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            files = images
            folder = url
            records.removeAll()
            folderLabel.stringValue = url.path
            folderLabel.toolTip = url.path
            changingSelection = true
            table.reloadData()
            changingSelection = false
            display(files.isEmpty ? -1 : 0)
            setStatus(files.isEmpty ? "这个文件夹中没有可识别的图片。请检查文件格式；不含子文件夹和隐藏文件。" : "已载入 \(files.count) 张图片。输入名称后按 Return 保存并前进。")
        } catch { showError(error) }
    }
    func display(_ row: Int) {
        index = row
        selectRow(row)
        emptyLabel.isHidden = row >= 0
        if row >= 0 {
            let url = files[row]
            savedStem = url.deletingPathExtension().lastPathComponent
            nameField.stringValue = savedStem
            extensionLabel.stringValue = url.pathExtension.isEmpty ? "无扩展名" : ".\(url.pathExtension) 自动保留"
            currentLabel.stringValue = url.lastPathComponent
            currentLabel.toolTip = url.path
            let image = NSImage(contentsOf: url)
            preview.show(image)
            if image == nil {
                emptyLabel.stringValue = "此图片无法预览，仍可改名或切换下一张"
                emptyLabel.isHidden = false
                setStatus("无法解码此图片：\(url.lastPathComponent)", error: true)
            }
            focusName()
        } else {
            savedStem = ""
            nameField.stringValue = ""
            currentLabel.stringValue = "尚未载入图片"
            extensionLabel.stringValue = "扩展名自动保留"
            emptyLabel.stringValue = "选择文件夹后，在这里放大查看图片"
            preview.show(nil)
        }
        updateControls()
    }
    func focusName() {
        window.makeFirstResponder(nameField)
        nameField.selectText(nil)
    }
    func updateControls() {
        let loaded = index >= 0 && index < files.count
        nameField.isEnabled = loaded
        saveButton.isEnabled = loaded
        saveNextButton.isEnabled = loaded
        previousButton.isEnabled = loaded && index > 0
        nextButton.isEnabled = loaded && index < files.count - 1
        undoButton.isEnabled = !records.isEmpty
        progressLabel.stringValue = loaded ? "\(index + 1) / \(files.count)" : "0 / \(files.count)"
    }
    func setStatus(_ message: String, error: Bool = false) {
        statusLabel.stringValue = message
        statusLabel.toolTip = message
        statusLabel.textColor = error ? .systemRed : .secondaryLabelColor
    }
    func showError(_ error: Error) {
        setStatus(error.localizedDescription, error: true)
        let alert = NSAlert(error: error)
        alert.runModal()
    }
    @discardableResult func commit() -> Bool {
        guard index >= 0 else { return false }
        do {
            let old = files[index]
            if let record = try RenameEngine.rename(old, input: nameField.stringValue) {
                records.append(record)
                files[index] = record.after
                setStatus("已重命名：\(old.lastPathComponent) → \(record.after.lastPathComponent)")
            } else { setStatus("名称未改变。") }
            savedStem = files[index].deletingPathExtension().lastPathComponent
            nameField.stringValue = savedStem
            currentLabel.stringValue = files[index].lastPathComponent
            currentLabel.toolTip = files[index].path
            changingSelection = true
            table.reloadData()
            changingSelection = false
            selectRow(index)
            updateControls()
            return true
        } catch { showError(error); focusName(); return false }
    }
    @objc func saveOnly() { if commit() { focusName() } }
    @objc func saveNext() {
        guard commit() else { return }
        if index < files.count - 1 { display(index + 1) }
        else { setStatus("已保存，已到最后一张（共 \(files.count) 张）。"); focusName() }
    }
    @objc func previous() {
        guard index > 0, resolveDraft() else { return }
        display(index - 1)
        setStatus("输入名称后按 Return 保存并前进。")
    }
    @objc func next() {
        guard index >= 0, index < files.count - 1, resolveDraft() else { return }
        display(index + 1)
        setStatus("输入名称后按 Return 保存并前进。")
    }
    @objc func undoRename() {
        guard !records.isEmpty, resolveDraft(), let record = records.last else { return }
        do {
            try RenameEngine.undo(record)
            records.removeLast()
            if let row = files.firstIndex(of: record.after) { files[row] = record.before; table.reloadData(); display(row) }
            updateControls()
            setStatus("已撤销：\(record.before.lastPathComponent)")
        } catch { showError(error) }
    }
    @objc func zoomOut() { preview.zoom(1 / 1.25) }
    @objc func zoomIn() { preview.zoom(1.25) }
    @objc func fitImage() { preview.fits = true; preview.resizePicture() }
    @objc func actualSize() { preview.fits = false; preview.scale = 1; preview.resizePicture() }
    @objc func about() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.1"
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "逐图改名", .applicationVersion: version, .credits: NSAttributedString(string: "选择文件夹 · 大图预览 · 逐张重命名\n所有操作在本机完成。")])
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.setActivationPolicy(.regular)
app.delegate = delegate
app.run()
