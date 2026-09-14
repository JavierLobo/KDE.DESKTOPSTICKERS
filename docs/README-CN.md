<p align="center">
  <img src="../img/logo-sticker.png" alt="Desktop Stickers 徽标" width="120">
</p>

<h1 align="center">Desktop Stickers</h1>

<p align="center">
  <a href="../LICENSE"><img alt="License: GPL-3.0" src="https://img.shields.io/badge/License-GPL--3.0-blue.svg"></a>
  <a href="README-SP.md"><img alt="ES" src="https://img.shields.io/badge/lang-ES-red.svg"></a>
  <a href="README-IT.md"><img alt="IT" src="https://img.shields.io/badge/lang-IT-green.svg"></a>
  <a href="README-EN.md"><img alt="EN" src="https://img.shields.io/badge/lang-EN-blue.svg"></a>
  <a href="README-DE.md"><img alt="DE" src="https://img.shields.io/badge/lang-DE-orange.svg"></a>
  <a href="README-RU.md"><img alt="RU" src="https://img.shields.io/badge/lang-RU-blueviolet.svg"></a>
  <a href="README-CN.md"><img alt="CN" src="https://img.shields.io/badge/lang-CN-yellow.svg"></a>
  <a href="README-JP.md"><img alt="JP" src="https://img.shields.io/badge/lang-JP-lightgrey.svg"></a>
</p>

适用于 KDE Plasma 桌面的悬浮便签应用。这是一个独立的 Qt6/QML 应用程序
(并非 Plasmoid 小组件),以普通程序的方式安装并支持开机自启——每个便签
都是一个独立、无边框装饰的窗口,位置和大小会持久保存,并可按每个便签
单独选择是否在所有虚拟桌面上显示(置顶)。

<p align="center">
  <img src="../img/screenshot-desktop.png" alt="KDE Plasma 桌面上的悬浮便签" width="720">
</p>

## 系统要求

- Plasma 6.x(已在 6.7.4 版本验证)及 KWin,Wayland 会话
- Qt 6.4+(`Core`、`Gui`、`Qml`、`Quick`、`Widgets`、`DBus`)
- CMake、Bash

## 安装

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

编译二进制文件,将其安装到 `~/.local/bin/desktop-stickers`,并注册开机自
启。完整指南(首次启动、示例数据、故障排除)请参见
[QUICKSTART-CN.md](QUICKSTART-CN.md),手动验证清单请参见
`QA_CHECKLIST.md`。

## 功能特性

- 可从托盘图标或已有便签上的 "+" 按钮创建新便签(新便签以级联方式出
  现,相对于创建它的便签有一定偏移),id 按顺序递增
- 可在桌面上拖动(通过 `Window.startSystemMove()` 实现真实的窗口移
  动),每次拖动后,真实位置(由 KWin 而非 Qt 报告)都会被持久保存,
  并在应用重启时通过每个便签专属的 KWin 窗口规则
  (`desktopstickers-sticker-<id>`)恢复
- 可从右下角拖拽调整大小,尺寸的保存与恢复方式与位置相同
- 按便签单独置顶(📍/📌 按钮):可单独开启,使该便签同时显示在所有虚拟
  桌面上,依赖同一便签的 KWin 窗口规则;未置顶时,便签只存在于创建或
  移动到的那个桌面。默认行为可在设置(桌面)中配置;开箱即用状态下,
  新建便签默认不置顶
- 支持**完整 Markdown** 文本编辑(标题、表格、代码、引用、列表、粗体/
  斜体、链接、复选框),并自动切换:点击进入编辑模式,失去焦点后返回
  渲染后的预览
- **Markdown 格式化工具栏**:编辑时显示,包含粗体、斜体、删除线、
  H1-H3 标题、无序列表、有序列表、任务列表、链接、图片、行内代码、引
  用、代码块、水平分割线,以及表格(带行/列选择器)——每个按钮都可对
  选中内容进行切换,并配有各自的键盘快捷键。随着便签变窄,优先级较低
  的按钮会依次从右向左收进"更多选项"按钮中;整个工具栏既可以从便签标
  题栏隐藏,也可以在设置中将其设为默认隐藏
- 预览中的链接可点击(通过系统的 URL 处理程序打开),围栏代码块会以带
  有独立背景色的方框展示
- 内容可滚动:较长的便签内容不会超出便签范围,编辑区域会在输入时自动
  滚动以保持光标可见
- 背景颜色:随机、跟随系统主题强调色(实时跟随 Plasma 主题变化),或
  自选固定颜色——可在设置(外观)中配置
- 可在设置中配置字体和字号:提供一个有序的字体优先级列表(例如
  "Times New Roman" → "Liberation Serif"),应用会解析并使用系统中实
  际安装的第一个可用字体,字号大小同样可配置
- 每个便签都可设置名称,可在便签面板中编辑:若未设置,则自动从文本首
  个非空行派生(会去掉开头的 `#` 标题符号)。无论是在便签标题栏
  (`#<id> | <名称或默认值>`)还是在托盘菜单/面板中,名称都会被截断为
  30 个字符
- **便签面板**:显示完整、不限数量的便签列表,支持搜索、排序(最近修
  改/按字母/按颜色)、点击打开、右键菜单(打开、重命名、复制)、多
  选,以及删除(可选确认提示,并提供数秒内的撤销操作)
- 系统托盘图标会列出最近修改的 10 条便签(不分页)——点击每一行可打开
  或重新聚焦对应便签
- 便签的 "✕" 按钮只会关闭该窗口——便签本身依然存在,可从托盘菜单或便
  签面板重新打开。删除便签是另一个独立操作,始终提供撤销选项
- **设置面板**(右键点击托盘图标 → 选项 → 设置):外观(颜色/字体)、
  行为(Markdown 工具栏默认可见性、删除确认、托盘左键点击动作)、系统
  (开机自启、数据路径及"打开文件夹"按钮、备份导出/导入),以及语言
- **多语言界面**:设置中提供语言选择器,每种语言的名称都用该语言本身
  书写(例如 "Español" 而非 "Spanish"),并配有对应的旗帜图标。内置
  西班牙语、英语、法语和俄语——每种语言都是 `src/i18n/` 目录下一个独
  立的 JSON 文件,构建时和运行时都会自动识别
- 托盘菜单中的**"选项"子菜单**:帮助(GitHub 上的文档)、捐赠(支持开
  发者)、查看许可证、设置,以及关于
- 单实例运行:若应用已在运行,再次启动不会打开重复的副本
- 若 KWin 在会话中途重启(崩溃或执行 `kwin_wayland --replace`),位置
  持久化功能会自动重新连接,无需重启应用
- 安装脚本会清理此前会话中已删除便签遗留下来的孤立 KWin 规则
- 通过标准 freedesktop `.desktop` 条目实现开机自启(而非 Plasma 的"后
  台服务"),可在设置中开关

<p align="center">
  <img src="../img/Desktop-stickers-markdown.png" alt="渲染后的 Markdown 便签示例:标题、表格和代码块" width="720">
</p>

## 数据存储

Desktop Stickers 遵循 **XDG 基本目录规范**——不会在你的主目录下单独占
用一个杂乱的文件夹。

便签数据保存在 `$XDG_DATA_HOME/desktop-stickers/stickers.json`(通常
为 `~/.local/share/desktop-stickers/stickers.json`):

```json
{
  "stickers": [
    {
      "id": "001",
      "name": "",
      "text": "Markdown 内容",
      "color": "#FFD700",
      "x": 100,
      "y": 200,
      "width": 300,
      "height": 250,
      "pinned": false,
      "fontFamily": "Liberation Serif",
      "fontSize": 10,
      "created": "2026-08-17T10:30:00Z",
      "modified": "2026-08-17T15:45:00Z"
    }
  ]
}
```

应用偏好设置单独保存在
`$XDG_CONFIG_HOME/desktop-stickers/settings.json`(通常为
`~/.config/desktop-stickers/settings.json`)中——包括外观、行为、开机
自启和语言设置。

> 从 v1.1.0 之前的版本升级?首次运行新版本的二进制文件时,你的数据会
> 自动、静默地从旧的 `~/.stickers/` 路径迁移到上面两个 XDG 路径,无需
> 任何手动操作。

## 下载

所有已发布的版本都在仓库的
[Releases](https://github.com/JavierLobo/KDE.DESKTOPSTICKERS/releases)
页面,每个版本都附有对应的源代码和更新说明。

## 许可证

GPL-3.0
