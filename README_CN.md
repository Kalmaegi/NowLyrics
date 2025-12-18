<p align="center">
  <img src="https://img.shields.io/badge/平台-macOS-blue.svg" alt="Platform">
  <img src="https://img.shields.io/badge/swift-5.9+-orange.svg" alt="Swift">
  <img src="https://img.shields.io/badge/许可证-MIT-green.svg" alt="License">
</p>

<h1 align="center">🎵 NowLyrics</h1>

<p align="center">
  <b>一个现代化的 macOS 桌面歌词应用，专为 Apple Music 设计</b>
</p>

<p align="center">
  <a href="README.md">🇺🇸 English</a>
</p>

---

## ✨ 功能特点

- 🎵 **自动获取歌词** - 自动检测 Apple Music 播放状态，智能匹配并获取歌词
- 🖥️ **桌面歌词显示** - 透明悬浮歌词窗口，始终置顶显示
- 🔄 **多歌词源支持** - 支持网易云音乐、QQ音乐等多个歌词源搜索
- 💾 **智能缓存** - 本地歌词缓存，离线也能使用
- 🎯 **手动选择** - 从搜索结果中选择您喜欢的歌词版本


## 📋 系统要求

- macOS 13.0 (Ventura) 或更高版本
- Apple Music 应用
- 自动化权限（用于访问 Apple Music）

## 🚀 安装

### 从源码编译

```bash
# 克隆仓库
git clone https://github.com/mahan/NowLyrics.git
cd NowLyrics

# 使用 Swift Package Manager 编译
swift build -c release

# 运行应用
swift run NowLyrics
```

### 使用 Xcode

1. 在 Xcode 中打开 `NowLyrics.xcodeproj`
2. 编译运行 (⌘R)

## 🔧 使用方法

1. **启动 NowLyrics** - 应用在菜单栏运行
2. **播放音乐** - 在 Apple Music 中播放歌曲
3. **授予权限** - 首次运行时允许自动化访问
4. **享受歌词** - 歌词将自动显示在桌面上

### 菜单栏选项

| 选项 | 描述 |
|------|------|
| 显示/隐藏桌面歌词 | 切换歌词显示 |
| 选择歌词 | 从可用歌词中选择 |
| 偏移 +/- | 调整歌词时间 |
| 搜索更多 | 搜索更多歌词 |
| 偏好设置 | 应用设置 |
| 退出 | 退出应用 |

## 🏗️ 项目架构

```
NowLyrics/
├── Sources/
│   ├── App/
│   │   └── AppDelegate.swift           # 应用程序入口
│   ├── Core/
│   │   ├── LyricsManager.swift         # 歌词管理核心
│   │   ├── LocalizationManager.swift   # 国际化管理
│   │   └── Logger.swift                # 统一日志系统
│   ├── Models/
│   │   ├── Track.swift                 # 曲目数据模型
│   │   ├── Lyrics.swift                # 歌词模型 + LRC 解析器
│   │   └── PlaybackState.swift         # 播放状态模型
│   ├── Services/
│   │   ├── AppleMusicService.swift     # Apple Music 通信
│   │   ├── LyricsSearchService.swift   # 多源歌词搜索
│   │   └── LyricsCacheService.swift    # 歌词持久化
│   └── Views/
│       ├── DesktopLyricsWindow.swift   # 悬浮歌词窗口
│       ├── LyricsSelectionViewController.swift
│       └── PreferencesViewController.swift
├── Resources/
│   ├── en.lproj/                       # 英文本地化
│   └── zh-Hans.lproj/                  # 中文本地化
└── Package.swift
```

## 核心模块

### AppleMusicService
通过 AppleScript 与 Apple Music 通信，获取当前播放的曲目信息和播放状态。使用 Swift Actor 确保线程安全的状态管理。

### LyricsSearchService
使用 Swift TaskGroup 并行搜索多个歌词源（网易云、QQ音乐）。结果按相关性评分排序。

### LyricsCacheService
管理本地歌词存储，支持 LRC 文件持久化和用户偏好追踪。

### LyricsManager
核心协调器，负责：
- 监听播放状态变化
- 协调歌词搜索和缓存
- 使用二分查找计算当前歌词行
- 通过 AsyncStream 广播更新


## 权限说明

NowLyrics 需要以下权限：

- **自动化** - 访问 Apple Music 获取播放信息
- **网络** - 从在线歌词源下载歌词

首次启动时，macOS 会提示您授予自动化权限。您也可以在以下位置启用：
> 系统设置 → 隐私与安全性 → 自动化 → NowLyrics

## 🤝 参与贡献

欢迎贡献代码！请随时提交 Pull Request。

有新需求或发现了Bug欢迎[提交 Issue](../../issues/new)，期待收到大家的反馈！



## 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 致谢

- 灵感来源于 [LyricsX](https://github.com/ddddxxx/LyricsX)
- 感谢所有歌词提供方

---

<p align="center">
  用 ❤️ 为音乐爱好者打造
</p>
