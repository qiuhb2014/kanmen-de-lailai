# 看门的来来

看门的来来是一个 HarmonyOS 原生两步验证令牌管理器，用 ArkUI / ArkTS 实现。它用于保存 TOTP 账号，并在本地实时生成 6 位验证码。

## 功能

- 添加 TOTP 令牌：支持扫码和手动输入 Base32 Secret
- 实时生成验证码：按账号显示当前验证码和倒计时
- 点击复制：点击令牌卡片复制当前验证码
- 本地保存：账号数据保存在应用沙箱
- 应用锁：支持通过系统生物识别保护应用
- 加密备份：支持导出和导入加密备份文件
- 原生实现：基于 HarmonyOS ArkUI / ArkTS，不依赖 WebView

## 隐私

看门的来来默认不上传令牌密钥。账号数据保存在设备应用沙箱内，备份文件由用户设置的密码加密保护。

请注意：当前项目仍处于早期维护阶段，正式保存重要 2FA 密钥前，建议先自行验证构建、备份和恢复流程。

## 技术栈

- HarmonyOS
- ArkUI
- ArkTS
- Hvigor
- OHPM

## 开发环境

建议使用：

- DevEco Studio
- HarmonyOS SDK 26.0.0 或兼容版本
- OHPM
- Hvigor

项目主要配置：

- `modelVersion`: `5.0.0`
- `compatibleSdkVersion`: `26.0.0`
- `targetSdkVersion`: `26.0.0`

## 本地运行

1. 使用 DevEco Studio 打开项目根目录。
2. 等待 OHPM 依赖同步完成。
3. 选择 `entry` 模块。
4. 连接 HarmonyOS 设备或启动模拟器。
5. 点击 Run。

命令行同步可参考：

```bash
ohpm install
hvigorw --sync
```

如果命令行打包提示找不到 Java Runtime，请在本机配置 JDK/JBR，或直接使用 DevEco Studio 内置运行环境。

## GitHub 维护流程

第一次维护开源项目可以参考 [GitHub 维护操作手册](docs/GitHub-Workflow.md)，里面包含分支、提交、推送和 PR 的完整流程图。

## 项目结构

```text
AppScope/                         应用级配置与资源
entry/src/main/ets/pages/          首页
entry/src/main/ets/features/       添加、扫码、设置、备份、锁屏页面
entry/src/main/ets/components/     可复用组件
entry/src/main/ets/crypto/         TOTP 与备份加密逻辑
entry/src/main/ets/store/          本地存储与状态管理
entry/src/main/ets/theme/          设计 token
entry/src/main/ets/utils/          工具函数
```

## 开源协议

本项目使用 MIT License。详见 [LICENSE](LICENSE)。

## 维护状态

这个项目正在整理和重构中，欢迎通过 Issue 反馈问题或建议。
