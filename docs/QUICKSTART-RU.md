# KDE Stickers - Быстрый старт

<p align="center">
  <a href="QUICKSTART-SP.md"><img alt="ES" src="https://img.shields.io/badge/lang-ES-red.svg"></a>
  <a href="QUICKSTART-IT.md"><img alt="IT" src="https://img.shields.io/badge/lang-IT-green.svg"></a>
  <a href="QUICKSTART-EN.md"><img alt="EN" src="https://img.shields.io/badge/lang-EN-blue.svg"></a>
  <a href="QUICKSTART-DE.md"><img alt="DE" src="https://img.shields.io/badge/lang-DE-orange.svg"></a>
  <a href="QUICKSTART-RU.md"><img alt="RU" src="https://img.shields.io/badge/lang-RU-blueviolet.svg"></a>
  <a href="QUICKSTART-CN.md"><img alt="CN" src="https://img.shields.io/badge/lang-CN-yellow.svg"></a>
  <a href="QUICKSTART-JP.md"><img alt="JP" src="https://img.shields.io/badge/lang-JP-lightgrey.svg"></a>
</p>

## Установка

```bash
cd <путь-к-репозиторию>  # перейдите в каталог, куда вы клонировали репозиторий
chmod +x scripts/install.sh
./scripts/install.sh
```

Собирает бинарный файл Qt6 (`build/kde-stickers`), устанавливает его в
`~/.local/bin/kde-stickers` и регистрирует автозапуск в
`~/.config/autostart/org.kde.stickers.desktop`.

## Первый запуск

Приложение запустится автоматически при следующем входе в сеанс Plasma.
Чтобы попробовать его прямо сейчас без выхода из сеанса:

```bash
~/.local/bin/kde-stickers &
```

Вы должны увидеть значок в системном трее ("KDE Stickers"), и если у
вас уже есть сохранённые стикеры в `~/.stickers/stickers.json`, их окна
появятся в их последнем реальном положении (сохранённом через правило
KWin для каждого стикера — см. `QA_CHECKLIST.md`).

## Создание первого стикера

- Клик по значку в трее → "Nuevo sticker", или
- Клик по кнопке "+" на любом существующем стикере

## Редактирование

Клик внутри стикера открывает редактирование в Markdown. Клик снаружи
возвращает к отрисованному предпросмотру.

## Закрепление (все рабочие столы) и изменение размера

- Кнопка 📍/📌 в заголовке: переключает, виден ли стикер на всех
  виртуальных рабочих столах (📌) или только на своём (📍). По
  умолчанию новый стикер создаётся без закрепления.
- Перетащите за нижний правый угол, чтобы изменить размер.

## Тестовые данные

⚠️ Этот скрипт **перезаписывает** `~/.stickers/stickers.json` — если у
вас уже есть созданные стикеры, они будут потеряны. Используйте его
только при новой установке, или если не жаль потерять текущие данные.

```bash
chmod +x scripts/test-sticker.sh
./scripts/test-sticker.sh
```

Создаёт 3 примера стикеров в `~/.stickers/stickers.json`.

## Полная проверка

См. `QA_CHECKLIST.md` — чек-лист ручной проверки всех функций.

## Устранение неполадок

**Бинарный файл не собирается:**
- Проверьте, что установлен Qt6 (`Core`, `Gui`, `Qml`, `Quick`, `Widgets`, `DBus`)
- Посмотрите вывод `cmake -B build -S .`, чтобы найти недостающий пакет

**Стикер не отображается на всех рабочих столах:**
- "Все рабочие столы" — это опция, включаемая **для каждого стикера**
  отдельно через кнопку закрепления (📍/📌) в заголовке, а не
  общеприложенческое правило — сначала проверьте, что у данного стикера
  закрепление активно (📌).
- Если закрепление активно, но стикер всё равно не следует за вами
  между рабочими столами, проверьте конкретное правило KWin этого
  стикера:
  `kreadconfig6 --file kwinrulesrc --group kdestickers-sticker-<id> --key desktopsrule`
  должно вернуть `2` (Force). Если возвращает `1` или пусто, значит
  закрепление не записалось — повторите клик по 📌.
- Также проверьте, что группа указана в списке:
  `kreadconfig6 --file kwinrulesrc --group General --key rules` должно
  включать `kdestickers-sticker-<id>`.
- Если значения верны, но изменения не применяются на лету, принудите
  перезагрузку: `qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure`
- Полное описание механизма (одно правило KWin на стикер, общее для
  закрепления и положения) — в файле
  `superpowers/specs/2026-08-18-sticker-pin-position-resize-design.md`,
  раздел "Arquitectura: de regla global a reglas por-ventana"

**Логи:**
```bash
journalctl --user -f
```
(приложение — самостоятельный процесс, а не часть plasmashell, поэтому
его сообщения попадают в лог пользовательского сеанса; запуск
`~/.local/bin/kde-stickers` напрямую из терминала для просмотра вывода
консоли в реальном времени остаётся самым надёжным способом)
