# iOS CocoaPods 与 Xcode Cloud 迁移说明

更新日期：2026-08-22

## 目标与范围

本次以 iNature (`plantCam-dev`) 的构建结构为基准，将 Mushroom、NatureEar、DrRock、Fish 的远程第三方依赖迁移到 CocoaPods，并保证 Xcode Cloud 能从干净 checkout 重建依赖、使用 workspace 归档。

所有项目只保留相邻仓库中的公共 Swift Package `BioScanKit`。NatureEar 的 ONNX Runtime 已切换为官方 CocoaPod，工程中不再保留第二个 Package 引用。

## 项目配置

| App | Workspace | Scheme | Podfile 位置 | Pods |
| --- | --- | --- | --- | --- |
| Mushroom | `ios/Mushroom.xcworkspace` | `Mushroom` | `ios/Podfile` | RevenueCat 5.80.2、Firebase 12.16.0 |
| NatureEar | `ios/NatureEar.xcworkspace` | `NatureEar` | `ios/Podfile` | ONNX Runtime 1.24.2、RevenueCat 5.80.2、Firebase 12.16.0 |
| DrRock | `ios/DrRock.xcworkspace` | `MrRock` | `ios/Podfile` | RevenueCat 5.80.2、Firebase 12.16.0、lottie-ios 4.6.0 |
| Fish | `Fish.xcworkspace` | `Fish` | `Podfile` | RevenueCat 5.80.2、Firebase 12.17.0、Kingfisher 8.0.0、WaterfallGrid 1.1.0 |

每个仓库应提交：

- `Podfile`
- `Podfile.lock`
- `*.xcworkspace/contents.xcworkspacedata`
- CocoaPods 集成后的 `.xcodeproj/project.pbxproj`
- 根目录 `ci_scripts/`

不要提交 `Pods/`。它由 Xcode Cloud 在构建时恢复。

## Xcode Cloud 设置

每个 Workflow 必须选择上表中的 workspace 和主 Scheme，不能继续选择 `.xcodeproj`。Archive 使用 Release 配置、Automatic Signing 和 App Store Connect distribution。

根目录脚本职责：

- `ci_post_clone.sh`：获取相邻的 `BioScanKit` 仓库，再执行 Pods bootstrap。
- `ci_pre_xcodebuild.sh`：构建前再次幂等校验 Pods，防止缓存不完整。
- `bootstrap_ios_pods.sh`：比较 `Podfile.lock` 与 `Pods/Manifest.lock`；一致时跳过，否则执行 `pod install --repo-update`，并校验 Release xcconfig 已生成。

Xcode Cloud 仓库访问凭证必须能读取 BioScanKit 仓库。如果仓库改为私有，应配置 Xcode Cloud Source Control 授权或改用同一组织内可访问的 HTTPS 地址。

## 本地与 CI 命令

首次准备：

```bash
./ci_scripts/ci_post_clone.sh
```

日常打开 workspace，不再直接打开 project：

```bash
open path/to/App.xcworkspace
```

无签名 Release 验证示例：

```bash
xcodebuild -workspace App.xcworkspace \
  -scheme App \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

## XcodeGen 规则

Mushroom、NatureEar、Fish 使用 XcodeGen。外部 Pod 不得重新写回 `packages:` 或 target 的 package dependency；否则会同时链接 SPM 和 Pod，造成重复符号或产品歧义。

Mushroom 与 Fish 必须保持 `ENABLE_USER_SCRIPT_SANDBOXING: NO`，否则 CocoaPods 的资源复制脚本无法创建 `Pods/resources-to-copy-*.txt`，Xcode Cloud 会在 Archive 阶段失败。重新运行 XcodeGen 后必须再执行 `pod install`，恢复 Pods xcconfig 和 Build Phases。

## 版本升级与回滚

升级单个 Pod 时只改 Podfile 中明确版本，然后执行：

```bash
pod update PodName
```

审核 `Podfile.lock` 的传递依赖变化，并跑 Release workspace 构建。不要无目的执行全量 `pod update`。

回滚时同时回滚 `Podfile`、`Podfile.lock` 和 `.xcodeproj/project.pbxproj`，再运行 `pod install`。业务代码和用户数据不受依赖管理器切换影响。

Firebase 已公告 CocoaPods 新版本发布将在 2026 年 10 月后停止。当前锁定版本仍可安装和构建，但届时升级 Firebase 应单独切回 Swift Package Manager；RevenueCat、Lottie、Kingfisher、WaterfallGrid 可继续使用 Pods。不要为追求“全 Pod”而冻结存在安全或合规修复需求的 Firebase。

## 验证结果

2026-08-22 使用 Xcode 26.4、全新 DerivedData，以下 Release workspace 模拟器构建均通过：

- Mushroom / `Mushroom`
- NatureEar / `NatureEar`（包含 Watch 与 ONNX Runtime Pod 集成）
- DrRock / `MrRock`
- Fish / `Fish`

现存警告主要是旧 SwiftUI/AVFoundation API、PromisesObjC 最低部署版本和个别资源目录问题，不属于 Pod 迁移阻断项。正式发布前仍需由 Xcode Cloud 完成带签名 Archive，以验证云端证书、Provisioning Profile 和 App Store Connect 权限。
