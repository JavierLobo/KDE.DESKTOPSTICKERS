<p align="center">
  <img src="../img/logo-sticker.png" alt="KDE Stickers 徽标" width="120">
</p>

<h1 align="center">KDE Stickers</h1>

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
单独选择是否在所有虚拟桌面上显示(置顶/固定)。

<p align="center">
  <img src="../img/screenshot-desktop.png" alt="KDE Plasma 桌面上的悬浮便签" width="720">
</p>

## 系统要求

- Plasma 6.x(已在 6.7.4 版本验证)及 KWin,Wayland 会话
- Qt 6.5+(`Core`、`Gui`、`Qml`、`Quick`、`Widgets`、`DBus`)
- CMake、Bash

## 安装

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

编译二进制文件,将其安装到 `~/.local/bin/kde-stickers`,并注册开机自
启。完整指南(首次启动、示例数据、故障排除)请参见
[QUICKSTART-CN.md](QUICKSTART-CN.md),手动验证清单请参见
`QA_CHECKLIST.md`。

## 功能特性

- 可从系统托盘图标或已存在便签的 "+" 按钮创建新便签(会以级联方式出
  现,相对源便签有一定偏移),id 按顺序递增
- 可在桌面上拖动(通过 `Window.startSystemMove()` 实现真实移动),每次
  拖动后,真实位置(由 KWin 而非 Qt 报告)会被持久保存,并在应用重启
  时通过每个便签专属的 KWin 窗口规则(`kdestickers-sticker-<id>`)恢复
- 可从右下角拖拽调整大小,尺寸的保存与恢复方式与位置相同
- 按便签单独置顶(📍/📌 按钮):可单独开启,使该便签同时显示在所有虚拟
  桌面上,依赖该便签同一条 KWin 窗口规则;未置顶时,便签只存在于创建
  或移动到的那个桌面。新建便签默认不置顶
- 支持**完整 Markdown** 文本编辑(标题、表格、代码、引用、列表、粗体/
  斜体、链接、复选框),并自动切换:点击进入编辑模式,失去焦点后返回
  渲染后的预览
- 预览中的链接可点击(通过系统的 URL 处理程序打开),代码块会以带有独
  立背景色的方框展示
- 内容可滚动:较长的便签内容不会超出便签范围,编辑区域会在输入时自动
  滚动以保持光标可见
- 背景颜色:固定的 6 种柔和色调调色板(每个新便签随机分配)或自由选色
- 每个便签可设置名称,可在便签面板中编辑:若未设置,则自动从文本首个
  非空行派生(会去掉开头的 `#` 标题符号)。无论是便签标题栏
  (`#<id> | <名称或默认值>`)还是托盘菜单/面板中,名称都会被截断为
  30 个字符
- 系统托盘图标会列出最近修改的 10 条便签(不分页)——每一行可打开或重
  新聚焦对应便签。同一菜单中的“便签面板”会打开一个包含完整列表(无数
  量限制)的窗口:可打开、重命名和删除(需确认)每条便签
- 便签的 "✕" 按钮只会关闭该窗口——便签本身依然存在,可从托盘菜单重新
  打开。删除便签是另一个独立操作,只能从便签面板执行,且始终需要确认;
  删除时也会一并移除该便签对应的 KWin 窗口规则
- 数据持久化保存在 `~/.stickers/stickers.json`
- 单实例运行:若应用已在运行,再次启动不会打开重复的副本
- 若 KWin 在会话中途重启(崩溃或执行 `kwin_wayland --replace`),位置
  持久化功能会自动重新连接,无需重启应用
- 安装脚本会清理此前会话中已删除便签遗留下来的孤立 KWin 规则
- 通过标准 freedesktop `.desktop` 条目实现开机自启(而非 Plasma 的“后
  台服务”)

<p align="center">
  <img src="../img/Desktop-stickers-markdown.png" alt="渲染后的 Markdown 便签示例:标题、表格和代码块" width="720">
</p>

## 数据存储

便签保存在 `~/.stickers/stickers.json` 中:

```json
{
  "stickers": [
    {
      "id": "001",
      "name": "",
      "text": "Contenido en Markdown",
      "color": "#FFD700",
      "x": 100,
      "y": 200,
      "width": 300,
      "height": 250,
      "pinned": false,
      "created": "2026-08-17T10:30:00Z",
      "modified": "2026-08-17T15:45:00Z"
    }
  ]
}
```

## 许可证

GPL-3.0
