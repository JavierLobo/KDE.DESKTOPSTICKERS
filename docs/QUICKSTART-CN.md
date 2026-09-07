# Desktop Stickers - 快速开始

<p align="center">
  <a href="QUICKSTART-SP.md"><img alt="ES" src="https://img.shields.io/badge/lang-ES-red.svg"></a>
  <a href="QUICKSTART-IT.md"><img alt="IT" src="https://img.shields.io/badge/lang-IT-green.svg"></a>
  <a href="QUICKSTART-EN.md"><img alt="EN" src="https://img.shields.io/badge/lang-EN-blue.svg"></a>
  <a href="QUICKSTART-DE.md"><img alt="DE" src="https://img.shields.io/badge/lang-DE-orange.svg"></a>
  <a href="QUICKSTART-RU.md"><img alt="RU" src="https://img.shields.io/badge/lang-RU-blueviolet.svg"></a>
  <a href="QUICKSTART-CN.md"><img alt="CN" src="https://img.shields.io/badge/lang-CN-yellow.svg"></a>
  <a href="QUICKSTART-JP.md"><img alt="JP" src="https://img.shields.io/badge/lang-JP-lightgrey.svg"></a>
</p>

## 安装

```bash
cd <仓库路径>  # 进入你克隆仓库的目录
chmod +x scripts/install.sh
./scripts/install.sh
```

这会编译 Qt6 二进制文件(`build/desktop-stickers`),将其安装到
`~/.local/bin/desktop-stickers`,并在
`~/.config/autostart/io.github.javierlobo.desktopstickers.desktop` 注册开机自启。

## 首次启动

应用会在你下次 Plasma 会话中自动启动。若想现在立即体验,无需重新登
录:

```bash
~/.local/bin/desktop-stickers &
```

你应该会在系统托盘看到一个图标("Desktop Stickers"),如果
`~/.stickers/stickers.json` 中已经保存了便签,它们的窗口会出现在各自
最后的真实位置(通过每个便签专属的 KWin 规则持久化——参见
`QA_CHECKLIST.md`)。

## 创建你的第一个便签

- 点击托盘图标 → "Nuevo sticker",或
- 点击任意已存在便签的 "+" 按钮

## 编辑

点击便签内部即可进入 Markdown 编辑模式。点击外部则返回渲染后的预览。

## 置顶(所有桌面)与调整大小

- 标题栏的 📍/📌 按钮:切换该便签是显示在所有虚拟桌面上(📌)还是仅显示
  在其所属桌面上(📍)。新建便签默认不置顶。
- 从右下角拖拽即可调整大小。

## 测试数据

⚠️ 该脚本会**覆盖** `~/.stickers/stickers.json` —— 如果你已经创建了便
签,它们将会丢失。只在全新安装时使用,或者你不介意丢失当前数据时再
使用。

```bash
chmod +x scripts/test-sticker.sh
./scripts/test-sticker.sh
```

在 `~/.stickers/stickers.json` 中创建 3 个示例便签。

## 完整验证

完整功能的手动检查清单请参见 `QA_CHECKLIST.md`。

## 故障排除

**二进制文件无法编译:**
- 确认已安装 Qt6(`Core`、`Gui`、`Qml`、`Quick`、`Widgets`、`DBus`)
- 查看 `cmake -B build -S .` 的输出,找出缺失的软件包

**某个便签没有出现在所有桌面上:**
- "所有桌面"是通过标题栏的置顶按钮(📍/📌)**按便签单独**开启的选项,
  而非应用级的全局规则——先确认该便签的置顶是否已激活(📌)。
- 如果置顶已激活,但便签仍然不会随你切换桌面,请检查该便签具体的
  KWin 规则:
  `kreadconfig6 --file kwinrulesrc --group desktopstickers-sticker-<id> --key desktopsrule`
  应返回 `2`(Force)。如果返回 `1` 或为空,说明置顶没有成功写入——
  再次点击 📌 重试。
- 同时确认该分组已被列出:
  `kreadconfig6 --file kwinrulesrc --group General --key rules` 应包含
  `desktopstickers-sticker-<id>`。
- 如果这些值都正确但没有实时生效,强制重新加载:
  `qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure`
- 该机制(每个便签一条 KWin 规则,置顶与位置共用)的完整说明见
  `superpowers/specs/2026-08-18-sticker-pin-position-resize-design.md`
  中的 "Arquitectura: de regla global a reglas por-ventana" 一节

**日志:**
```bash
journalctl --user -f
```
(该应用是独立进程,不属于 plasmashell,所以其日志信息会输出到用户会
话日志中;直接在终端里运行 `~/.local/bin/desktop-stickers` 以查看实时控
制台输出,仍然是最可靠的方式)
