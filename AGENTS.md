# 仓库指南

## 项目结构与模块组织

这是一个面向 Android、iOS、Linux、macOS、Web 和 Windows 的 Flutter 应用。应用代码位于 `lib/`：页面在 `lib/views/`，控制器在 `lib/controller/`，服务在 `lib/service/`，可复用 UI 在 `lib/component/`，模型在 `lib/model/`，共享配置在 `lib/config/`。`lib/main.dart` 是入口文件。测试位于 `test/`；JSON fixture 位于 `lib/controller/args/`。资源和字体位于 `assets/`，Web 文件位于 `web/`，各平台运行器位于对应平台目录，本地包位于 `third_party/`，发布脚本位于 `script/`，设计文件位于 `design/`。

## 构建、测试与开发命令

请使用 Flutter 3.27.1（Dart 3.6.x；版本信息见 `README.md` 和 CI 配置）。

```bash
flutter pub get                 # Install dependencies
flutter run -d windows          # Run the desktop app
flutter run -d chrome           # Run the web app
flutter analyze                 # Run static analysis
flutter test                    # Run all tests
flutter build windows           # Build the Windows release
flutter build web --web-renderer canvaskit --base-href="/OASX/"
flutter build apk --release     # Build an Android release APK
```

CI 会在 `v*` 标签上构建 Windows、MSIX 和 Android，并从 `master` 构建 Web；发布相关的敏感配置应保存在 GitHub Secrets 中。

## 代码风格与命名约定

遵循 `analysis_options.yaml` 和 `flutter_lints` 规则。使用两个空格缩进，多行 Dart 表达式保留尾逗号；类型使用 `PascalCase`，成员和变量使用 `camelCase`，文件名使用 `snake_case.dart`（例如 `server_controller.dart`）。将各功能代码放在现有职责目录中。提交前运行 `dart format lib test`。

## 测试规范

使用 `flutter_test`；Widget 测试放在 `test/` 中，并为 `testWidgets` 或 `test` 使用清晰的描述性名称。修改行为时应补充或更新测试，然后运行 `flutter test` 和 `flutter analyze`。项目没有规定覆盖率阈值，应优先覆盖用户可见流程以及控制器/模型解析逻辑。

## Commit 与 Pull Request 规范

近期提交使用简短的前缀格式，例如 `feat:`、`fix:` 和 `perf:`，发布/标签提交则使用简短说明。请遵循这一风格，例如：`fix: handle websocket reconnect`。保持每个提交关注单一目的。Pull Request 应说明变更内容、列出验证命令、在适用时关联 Issue；UI 变更应附截图或录屏，并注明平台和依赖变化。

## 安全与配置提示

不要提交 API 密钥、签名密码、证书或 CI Token。修改 `pubspec.yaml`、平台签名文件和发布脚本时请仔细检查；凭据应使用本地配置或 GitHub Secrets 管理。
