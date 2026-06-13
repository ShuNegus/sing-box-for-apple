# PLAN — подготовка проекта к сборке на девайс

**Ветка:** `feature/device-signing` (от `dev`)
**Цель:** настроить подпись iOS/macOS под аккаунт `claude@smd.su` (team `7G6756ME5J`), сменить идентификатор приложения на `su.smd.sing-box`, убрать ограниченный entitlement, чтобы `SFI` собирался и подписывался на устройство через автопровижининг Xcode.

## Эталон
Повторяем проверенную конфигурацию старого форка `../../../x-ray/sing-box-for-apple` (он собирался и подписывался на девайс), но **чище** — без остаточных рассинхронов (старый форк оставил битую ссылку на helper-plist).

## Изменения

### 1. `sing-box.xcodeproj/project.pbxproj`
- `DEVELOPMENT_TEAM`: все значения (`287TTNZF8L` и пустые `""`) → `7G6756ME5J`.
- `BASE_PACKAGE_IDENTIFIER`: `io.nekohasekai.sfavt` → `su.smd.sing-box` (2 шт).
- Все литералы `io.nekohasekai.sfavt[.suffix]` (bundle id macOS-таргетов `.application/.system/.standalone/.macapp/.helper`, путь helper-plist) → `su.smd.sing-box…`. **Значения с дефисом обязательно в кавычках** (OpenStep plist).
- `CODE_SIGN_STYLE`: `Manual` → `Automatic` **только** для `.system` и `.standalone` (macOS standalone). `.application` и `.macapp` остаются `Manual` (как в эталоне).

### 2. Entitlements (9 файлов)
`Extension, FileProviderExtension, WidgetExtension, IntentsExtension, SFI, SFM, SFM.System/SFM, SFT, TVExtension`:
- `io.nekohasekai.sfavt` → `su.smd.sing-box` (app group `group.*`, iCloud-контейнер `iCloud.*`).
- В `Extension/Extension.entitlements` **удалить** `com.apple.developer.networking.multicast` (ограниченный entitlement — авто-провижининг с ним падает). В `SystemExtension`/`TVExtension` multicast **оставить** (как в эталоне; не на пути iOS-девайс-сборки).

### 3. Helper-plist (чистим рассинхрон, которого нет в эталоне)
- Переименовать `HelperService/LaunchDaemons/io.nekohasekai.sfavt.helper.plist` → `su.smd.sing-box.helper.plist`.
- Внутри: `Label`, `MachServices` (+ префикс команды `287TTNZF8L`→`7G6756ME5J`), `AssociatedBundleIdentifiers` → новые id.
- Ссылка в pbxproj уже обновится правкой #1.

### 4. Прочее
- `SFMUITests/SnapshotHelper.swift`: `io.nekohasekai.sfavt` → `su.smd.sing-box` (bundle id для UI-тестов).
- `SFM.System/Upload.plist`, `Export.plist` — **не трогаем** (macOS-export only, содержат имена provisioning-профилей аккаунта-апстрима; к iOS-девайс-сборке отношения не имеют). Зафиксировать в PROGRESS как осознанно оставленное.

## Критерий готовности
- `xcodebuild -list` и `-showBuildSettings -scheme SFI` отрабатывают (pbxproj не побит), резолвят `su.smd.sing-box` и team `7G6756ME5J`.
- Сборка SFI под симулятор проходит (проверка целостности pbxproj без подписи).
- В репо не осталось `io.nekohasekai.sfavt` кроме осознанно оставленных `SFM.System/{Upload,Export}.plist`.
- Реальная подпись/установка на девайс — финально проверяет пользователь в Xcode (нужен интерактивный Apple-логин).

## Шаги
1. ✅ Ветка `feature/device-signing`, PLAN.md.
2. Скрипт правок pbxproj (Python, аккуратное кавычение) + entitlements + helper-plist + SnapshotHelper.
3. Удалить multicast из Extension.entitlements.
4. Валидация: `xcodebuild -list`, `-showBuildSettings`, сборка под симулятор.
5. PROGRESS.md, коммит в фичеветку.
6. По готовности: удалить `docs/tasks/device-signing/`, merge в `dev`.
