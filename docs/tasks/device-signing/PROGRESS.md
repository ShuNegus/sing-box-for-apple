# PROGRESS — подготовка к сборке на девайс

Статус: **готово (конфигурация подписи), ждёт финальной проверки на устройстве пользователем.**

## Сделано
- Ветка `feature/device-signing` от `dev`.
- Скрипт `apply.py` (идемпотентный) применил правки:
  - **pbxproj:** `DEVELOPMENT_TEAM` → `7G6756ME5J` (все 34). `BASE_PACKAGE_IDENTIFIER` → `"su.smd.sing-box"`. Все литералы `io.nekohasekai.sfavt[.*]` → `su.smd.sing-box.*` с корректным кавычением (дефис). `CODE_SIGN_STYLE` Manual→Automatic для `.system`/`.standalone` (4 блока); `.application`/`.macapp` остались Manual (как в эталоне). Итог: 30 Automatic / 4 Manual.
  - **Entitlements (9):** app-group `group.*` и iCloud-контейнер `iCloud.*` → `su.smd.sing-box`. Из `Extension/Extension.entitlements` удалён `com.apple.developer.networking.multicast`.
  - **Helper-plist:** файл `git mv` → `su.smd.sing-box.helper.plist`; внутри `Label`/`MachServices`(+префикс команды)/`AssociatedBundleIdentifiers` обновлены. (Старый форк оставлял битую ссылку — здесь согласовано.)
  - **SnapshotHelper.swift:** bundle id для UI-тестов → `su.smd.sing-box`.
- Инициализирован сабмодуль `Frameworks/Runestone` (нужен для резолва пакетов).

## Проверки
- `plutil -lint` — все правленые entitlements + helper-plist: OK.
- `xcodebuild -list` — проект парсится, схема `SFI` на месте (pbxproj не побит).
- `xcodebuild -showBuildSettings -scheme SFI` резолвит: `PRODUCT_BUNDLE_IDENTIFIER=su.smd.sing-box`, `DEVELOPMENT_TEAM=7G6756ME5J`, `CODE_SIGN_STYLE=Automatic`, `APP_GROUP_IDENTIFIER=group.su.smd.sing-box`. ✅

## Осознанно НЕ тронуто
- `SFM.System/Upload.plist`, `Export.plist` — содержат имена provisioning-профилей аккаунта-апстрима, используются только для macOS-export. К iOS-девайс-сборке отношения не имеют. (В них остаётся `io.nekohasekai.sfavt` — это ОК.)

## Не входит в эту задачу / блокеры полного билда
- **`Libbox.xcframework` отсутствует** (gitignored) — собирается из чистового ядра `../sing-box` (отдельная задача). Без него полный билд SFI не слинкуется.
- **Реальная подпись/установка на девайс** — финально делает пользователь в Xcode под Apple-логином (`-allowProvisioningUpdates`, интерактивный вход). Здесь проверено только, что настройки резолвятся.

## Дальше
- Финализация: удалить `docs/tasks/device-signing/`, merge `feature/device-signing` → `dev`.
