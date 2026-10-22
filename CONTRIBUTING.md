# 参与开发

请在 macOS 上开发。项目使用 Swift / AppKit，没有第三方运行时依赖。

提交修改前运行：

```bash
bash scripts/test.sh
bash scripts/build.sh
```

涉及界面的改动，请打开 `dist/逐图改名.app`，在专用测试图片文件夹中检查：选择目录、缩放预览、输入中文名称、Return 保存并切换、重复名称保护、撤销，以及未保存输入提示。文件改名会直接操作所选目录，请使用测试副本。

文件操作行为的修改应在 `Tests/RenameEngineTests.swift` 中补充相应场景。测试必须保持原文件字节不变，并覆盖失败时不覆盖其他文件的行为。

请勿提交 `dist/`、`.build/`、`.DS_Store`、证书、密钥或个人图片。提交问题时注明 macOS 版本、芯片架构、图片格式和复现步骤。
