<p align="center">
  <img src="docs/icon.png" width="160" alt="逐图改名应用图标">
</p>

<h1 align="center">逐图改名 · Image Renamer</h1>

<p align="center">选择文件夹，看大图，输入名称，按回车进入下一张。</p>

一个使用 Swift 和 AppKit 编写的原生 macOS 图片重命名工具。适合整理照片、素材和图片资料，所有操作在本机完成，无需网络或账号。

## 功能

- 选择文件夹，按文件名自然排序逐张浏览图片。
- 大图预览、适应窗口、原始尺寸及触控板捏合缩放。
- 在图片下方输入新名称，按 Return 保存并进入下一张。
- 保留扩展名，不重新编码图片；遇到名称冲突时拒绝覆盖。
- 支持上一张、下一张、列表跳转和本次会话内连续撤销。
- 切换或退出前提示处理未保存的名称。
- 包含独立应用图标，构建产物同时支持 Apple 芯片和 Intel。

## 运行要求

macOS 12 或以上。运行编译后的 App 不需要安装开发工具。

源代码构建需要 Apple Command Line Tools 或 Xcode，以及 Swift 6.1 或以上编译器（使用 Swift 5 语言模式）。不依赖第三方 Swift 包，不需要 Xcode 项目文件。

## 构建与运行

在仓库根目录执行：

```bash
# 首次安装命令行开发工具；如果已安装，可以跳过
xcode-select --install

# 编译双架构 App
bash scripts/build.sh

# 打开应用
open "dist/逐图改名.app"
```

也可以指定输出文件夹：`bash scripts/build.sh /path/to/output`。

## 使用

1. 点击“选择文件夹…”。只读取当前文件夹第一层的图片。
2. 在大图下方输入名称，例如 `海边日落`。不需要输入扩展名。
3. 按 **Return** 保存并切换下一张；“仅保存”会停留在当前图片。
4. 用列表或“上一张／下一张”导航；误改时可点击“撤销重命名”。

改名直接作用于原文件。关闭应用或切换文件夹后，撤销历史不保留。隐藏文件、符号链接和子文件夹会被跳过。实际支持的图片预览格式取决于 macOS 解码能力。

完整说明和快捷键见 [使用指南](docs/usage.md)。

## 测试与打包

```bash
# 文件改名、名称检查、冲突保护、撤销及文件字节保留测试
bash scripts/test.sh

# 重新构建，生成 ZIP 与 SHA-256 校验文件
bash scripts/package.sh
```

产物位于 `dist/`：

```text
dist/
├── 逐图改名.app
├── image-renamer-mac-v1.0.1.zip
└── image-renamer-mac-v1.0.1.zip.sha256
```

App 使用本地 ad-hoc 签名，未经过 Apple 开发者公证。首次打开被系统拦截时，见使用指南。正式分发时可自行配置 Developer ID 签名和公证。

## 仓库结构

```text
Sources/ImageRenamer/   AppKit 界面和文件操作逻辑
Tests/                 独立文件操作测试
Resources/             Info.plist 与 AppIcon.icns
scripts/               构建、测试、打包及编译器配置
docs/                  使用指南、Logo、设计与发布说明
.github/workflows/     macOS 自动测试和构建
```

推送到 `main`、创建 `v*` 标签或提交 Pull Request 时，GitHub Actions 会运行测试、构建双架构应用，并保存 ZIP 和校验文件供下载。工作流也支持手动运行，不会自动创建公开 Release。

上传、发布步骤见 [GitHub 发布指南](docs/github.md)，贡献方式见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证

采用 [MIT License](LICENSE)。应用源码及随仓库提供的图标均按该许可证分发。图标由 AI 生成，生成方式与提示词见 [设计记录](docs/icon-design.md)。
