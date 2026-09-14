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

你应该会在系统托盘看到一个图标("Desktop Stickers"),如果你已经保存
过便签,它们的窗口会出现在各自最后的真实位置(通过每个便签专属的
KWin 规则持久化——参见 `QA_CHECKLIST.md`)。数据保存在
`$XDG_DATA_HOME/desktop-stickers/stickers.json`(通常为
`~/.local/share/desktop-stickers/`)下,而不是主目录中单独的一个杂乱
文件夹里。

界面语言会跟随设置中保存的选项(默认是西班牙语)。要更改语言:右键点
击托盘图标 → **选项 → 设置 → 语言**。

## 创建你的第一个便签

- 点击托盘图标 → "Nuevo sticker",或者
- 点击任意已有便签上的 "+" 按钮

## 编辑

点击便签内部即可进入 Markdown 编辑模式——格式化工具栏(粗体、标题、
列表、表格、链接等)会出现在文本区域上方。点击外部则返回渲染后的预
览。

## 置顶(所有桌面)与调整大小

- 标题栏的 📍/📌 按钮:切换该便签是显示在所有虚拟桌面上(📌)还是仅显示
  在其所属桌面上(📍)。新建便签默认不置顶(可在设置中配置)。
- 从右下角拖拽即可调整大小。

## 设置面板

右键点击托盘图标 → **选项 → 设置**打开设置面板,共有四个部分:

- **外观**:新建便签的默认颜色(随机、系统强调色或固定颜色)、字体优
  先级列表,以及字号
- **行为**:Markdown 工具栏默认可见性、删除确认、托盘左键点击动作
- **系统**:开机自启开关、数据路径(带"打开文件夹"按钮)、备份导出/
  导入
- **语言**:界面语言选择器

"选项"子菜单中的其余项目还有帮助(GitHub 上的文档)、捐赠(支持开发
者)、查看许可证,以及关于。

## 便签面板

左键点击托盘图标(或在菜单中选择 "Panel de Stickers")会打开完整列
表:支持按文本搜索,按最近修改/字母/颜色排序,点击打开便签,右键菜单
(打开、重命名、复制),以及多选批量删除。

## 测试数据

⚠️ 该脚本会**覆盖**你的 `stickers.json` —— 如果你已经创建了便签,它
们将会丢失。只在全新安装时使用,或者你不介意丢失当前数据时再使用。

```bash
chmod +x scripts/test-sticker.sh
./scripts/test-sticker.sh
```

创建 3 个示例便签。

## 完整验证

完整功能的手动检查清单请参见 `QA_CHECKLIST.md`。

## 故障排除

**二进制文件无法编译:**
- 确认已安装 Qt6(`Core`、`Gui`、`Qml`、`Quick`、`Widgets`、`DBus`)
- 查看 `cmake -B build -S .` 的输出,找出缺失的软件包

**某个便签没有出现在所有桌面上:**
- "所有桌面"是通过标题栏的置顶按钮(📍/📌)**按便签单独**开启的选项,
  而非应用级的全局规则——请先确认该便签的置顶是否已激活(📌)。
- 如果置顶已激活,但便签仍然不会随你切换桌面,请检查该便签具体的
  KWin 规则:
  `kreadconfig6 --file kwinrulesrc --group desktopstickers-sticker-<id> --key desktopsrule`
  应返回 `2`(Force)。如果返回 `1` 或为空,说明置顶没有成功写入——
  请再次点击 📌 重试。
- 同时确认该分组已被列出:
  `kreadconfig6 --file kwinrulesrc --group General --key rules` 应包含
  `desktopstickers-sticker-<id>`。
- 如果这些值都正确但没有实时生效,强制重新加载:
  `qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure`

**我在 `src/i18n/` 中新增的语言没有显示出来:**
- 该语言文件需要与 `src/i18n/es.json` 拥有完全相同的键(包括
  `Language.name` 和 `Language.flag`)。
- 需要重新编译(`cmake --build build`)——语言字典列表只会在配置/编译
  时重新检测,已安装的应用启动时不会重新扫描。

**日志:**
```bash
journalctl --user -f
```
(该应用是独立进程,不属于 plasmashell,所以其日志信息会输出到用户会
话日志中;直接在终端里运行 `~/.local/bin/desktop-stickers` 以查看实时控
制台输出,仍然是最可靠的方式)
