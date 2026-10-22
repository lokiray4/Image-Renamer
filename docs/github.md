# 上传到 GitHub 与发布应用

推荐仓库名：`image-renamer`。推荐描述：`原生 macOS 图片重命名工具：大图预览、输入名称、回车进入下一张。Swift + AppKit。`

推荐 Topics：`macos`、`swift`、`appkit`、`image-renamer`、`productivity`。

## 用 Git 上传（推荐）

1. 在 GitHub 新建一个名为 `image-renamer` 的空仓库，按需选择公开或私有。不要勾选自动创建 README、许可证或 .gitignore，因为本项目已包含。
2. 打开终端，进入本项目根目录，执行以下命令。将 `YOUR_USERNAME` 替换成自己的 GitHub 用户名：

```bash
git init -b main
git add .
git commit -m "Initial release: native macOS image renamer"
git remote add origin https://github.com/YOUR_USERNAME/image-renamer.git
git push -u origin main
```

如果 Git 提示缺少作者信息，先用 `git config user.name` 和 `git config user.email` 配置你希望记录在提交中的姓名和邮箱；可使用 GitHub 提供的私密 noreply 邮箱。认证使用你自己的 GitHub 登录流程或令牌，不要将令牌写进仓库。

本地交付目录已经初始化为 `main` 分支，尚未创建提交或设置远程地址。ZIP 解压后的目录不含 Git 历史，以上命令适用于两种情况。

## 用网页上传

解压项目后，将文件和目录上传到空仓库根目录；确保 `.github/workflows/build.yml`、`.gitignore` 和 `.gitattributes` 这些隐藏文件也被上传。Finder 可通过 `⌘ Shift .` 显示隐藏文件。请确认 GitHub 首页能直接显示本项目 README，而不是再多套一层 `image-renamer/`。

## 自动构建

代码推送到 `main`、推送 `v*` 标签、向 `main` 提交 PR 或手动运行工作流时，会在 macOS runner 上测试、构建，并将 ZIP 与 SHA-256 校验文件保存为 Actions artifact。需要登录 GitHub，在对应工作流的运行详情页下载。产物保留 14 天。

工作流仅申请 `contents: read` 权限，不需要额外密钥，不会自动发布 Release。若仓库禁止运行 Actions，需由仓库所有者在 GitHub 设置中启用。GitHub 云端工作流需要在上传后才能实际验证。

工作流使用官方 [actions/checkout](https://github.com/actions/checkout) 和 [actions/upload-artifact](https://github.com/actions/upload-artifact)。

## 发布一个可下载版本

1. 在 `Resources/Info.plist` 更新 `CFBundleShortVersionString` 和递增的 `CFBundleVersion`，并更新 `CHANGELOG.md`。
2. 执行 `bash scripts/test.sh` 和 `bash scripts/package.sh`。
3. 提交版本修改，并创建与版本一致的标签，例如 `git tag v1.0.1`，再推送标签。
4. 在 GitHub 的 Releases 页面创建 Release，选择标签，填写更新说明。
5. 上传 `dist/image-renamer-mac-v1.0.1.zip` 及对应 `.sha256` 文件，然后发布。也可使用该标签对应的 Actions 构建产物；校验文件应与实际上传的 ZIP 配套。

安装包应作为 Release 附件发布，不要加入源码 Git 历史。不要上传 `.build/` 缓存或本机测试文件。

当前构建采用 ad-hoc 签名，未公证；发布说明应保留这一点。如果之后使用 Developer ID 签名／公证，应在生成最终 ZIP 前完成，并重新生成校验文件。
