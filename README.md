# Quickshell Desktop Shell — Nix 打包

[StatIndet/quickshell](https://github.com/StatIndet/quickshell) 的 Nix 包，包含 C++ 后端（clavis-core）和 QML 前端，提供 Bar、灵动岛（Keystone）、控制中心、启动器、锁屏、侧边栏等桌面组件。

> [!WARNING]
> 当前项目仍在活跃开发中，配置和功能可能有调整。

<p><br/></p>

<p align="center">
  <a href="https://github.com/yigexuanmu/quickshell-nix/stargazers">
    <img src="https://img.shields.io/github/stars/yigexuanmu/quickshell-nix?style=for-the-badge&labelColor=FFF59B&color=FFF59B&logo=github&logoColor=070722" alt="GitHub stars" />
  </a>
  <a href="https://github.com/yigexuanmu/quickshell-nix/commits">
    <img src="https://img.shields.io/github/last-commit/yigexuanmu/quickshell-nix?style=for-the-badge&labelColor=FFF59B&color=FFF59B&logo=git&logoColor=070722&label=commit" alt="Last commit" />
  </a>
  <a href="https://github.com/StatIndet/quickshell">
    <img src="https://img.shields.io/badge/upstream-FFF59B?style=for-the-badge&logo=github&logoColor=070722&labelColor=FFF59B" alt="Upstream" />
  </a>
</p>

## 安装

### 前提

- NixOS 或已安装 Nix 包管理器的 Linux 发行版
- NixOS 需启用 `nix-command` 和 `flakes` 特性
- Niri 或 Hyprland 等 Wayland 合成器

### 作为 NixOS 模块使用

在 `flake.nix` 中添加本仓库作为输入：

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    quickshell-nix = {
      url = "github:yigexuanmu/quickshell-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, quickshell-nix, ... }: let
    inherit (nixpkgs.lib) nixosSystem;
    system = "x86_64-linux";
  in {
    nixosConfigurations.HOSTNAME = nixosSystem {
      inherit system;
      modules = [
        quickshell-nix.nixosModules.default
      ];
    };
  };
}
```

### 单次运行

```sh
nix run github:yigexuanmu/quickshell-nix
```

### 直接安装

```sh
nix profile install github:yigexuanmu/quickshell-nix
```

安装后会产生以下入口：

| 命令 | 说明 |
|------|------|
| `quickshell-desktop` | 完整桌面，加载 shell.qml |
| `qs` | 同上，快捷方式 |

这两个命令已自动配置好 `QML2_IMPORT_PATH` 和项目目录。

### 与 Niri 集成

在 Niri 配置中添加：

```kdl
spawn-at-startup "quickshell-desktop"
```

或使用 `qs`：

```kdl
spawn-at-startup "qs"
```

## 包含的包

| 包 | 说明 |
|----|------|
| `cava-lib` | 音频可视化库 libcava（来自 karlstav/cava v0.10.7，含 pkg-config） |
| `clavis-core` | C++ 后端（key 二进制 + Clavis 和 M3Shapes QML 插件） |
| `meteocons-lottie` | 475 个动画天气图标（@meteocons/lottie v0.1.0） |
| `quickshell-desktop` | 默认包：QML 前端 + 包装器，可直接运行 |

## 包含的功能

- 多显示器 Bar（工作区、托盘、系统监视器、快速设置）
- 灵动岛（Keystone）：媒体、歌词、通知、音量、壁纸、天气、时钟
- 控制中心
- 启动器
- 锁屏（含 PAM 认证）
- 左右侧边栏（天气、通知）
- 壁纸管理和过渡 shader
- Material 3 风格界面
- 动画天气图标（Lottie）
- 常用音频可视化

## 致谢

本项目在实现过程中参考并复用了多个优秀开源项目的设计、组件和实现思路，感谢这些项目及其维护者：

1. [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)：可复用组件、Quickshell 模块组织和 Material 风格界面的重要参考来源。
2. [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell)：提供了成熟的 Quickshell Material Shell 模板、控制中心和交互设计参考，也是壁纸过渡 shader 的来源。
3. [caelestia-shell](https://github.com/caelestia-dots/shell)：锁屏界面和 Quickshell Shell 视觉风格的重要参考来源。
4. [qml-niri](https://github.com/imiric/qml-niri)：Niri IPC、工作区/窗口模型和 QML 插件封装的实现参考。
5. [Breezy Weather](https://github.com/breezy-weather/breezy-weather)：天气界面、天气信息组织和 Material 3 天气可视化设计参考。
6. [soramanew/m3shapes](https://github.com/soramanew/m3shapes)：提供 Material 3 Expressive 形状、形变算法与解析抗锯齿 QML 原生模块。

## 开源协议

本项目以 [GNU GPL-3.0](https://github.com/StatIndet/quickshell/blob/main/LICENSE) 作为主许可证发布。项目中参考、改写或复用的第三方源码、设计和资源仍遵循其原始项目许可证；相关许可证副本集中存放在 [`licenses/`](https://github.com/StatIndet/quickshell/blob/main/licenses) 目录中。

- `end-4/dots-hyprland`：GPL-3.0，见 [`licenses/end-4-dots-hyprland-GPL-3.0.txt`](https://github.com/StatIndet/quickshell/blob/main/licenses/end-4-dots-hyprland-GPL-3.0.txt)。
- `DankMaterialShell`：MIT，见 [`licenses/DankMaterialShell-MIT.txt`](https://github.com/StatIndet/quickshell/blob/main/licenses/DankMaterialShell-MIT.txt)。
- `caelestia-shell`：GPL-3.0，见 [`licenses/caelestia-shell-GPL-3.0.txt`](https://github.com/StatIndet/quickshell/blob/main/licenses/caelestia-shell-GPL-3.0.txt)。
- `qml-niri`：MIT，见 [`licenses/qml-niri-MIT.txt`](https://github.com/StatIndet/quickshell/blob/main/licenses/qml-niri-MIT.txt)。
- `Breezy Weather`：LGPL-3.0 及附加条款，见 [`licenses/BreezyWeather-LGPL-3.0.txt`](https://github.com/StatIndet/quickshell/blob/main/licenses/BreezyWeather-LGPL-3.0.txt) 和 [`licenses/BreezyWeather-LICENSE_ADDITIONAL.txt`](https://github.com/StatIndet/quickshell/blob/main/licenses/BreezyWeather-LICENSE_ADDITIONAL.txt)。
- `Animated Weather Cards`：MIT，见 [`licenses/AnimatedWeatherCards-MIT.txt`](https://github.com/StatIndet/quickshell/blob/main/licenses/AnimatedWeatherCards-MIT.txt)。
- `soramanew/m3shapes`：Apache-2.0，见 [`licenses/M3Shapes-Apache-2.0.txt`](https://github.com/StatIndet/quickshell/blob/main/licenses/M3Shapes-Apache-2.0.txt)。

若某个文件中保留了更具体的版权或许可证声明，以该文件内声明和对应上游许可证为准。
