# CLAUDE.md — sing-box-for-apple (Bublik VPN client)

Форк iOS/macOS/tvOS-клиента **sing-box-for-apple** (апстрим SagerNet) для **Bublik VPN**.
Цель форка — добавить **TURN-режим** (туннелирование VLESS через `vk-turn-proxy` → реле VK Calls → нода) как обход DPI/шейпа, плюс брендинг Bublik.

> Это подпроект. Корневой проект — `/Users/vsh/Documents/VPN` (см. `../../../CLAUDE.md`): инфраструктура Remnawave, ноды, подписки, TURN-серверная часть.

## Контекст: «на чистовую»
- Это **чистый форк** от `ShuNegus/sing-box-for-apple`, ветка `dev`, **БЕЗ** TURN-интеграции. Здесь TURN переносится заново, пошагово и аккуратно.
- **Ядро sing-box тоже чистовое** — лежит рядом с этим репо: `../sing-box/` (т.е. `clients/ios/sing-box/`). Из него собирается `Libbox.xcframework` (туда вольётся `vk-turn-proxy` clientcore при TURN-фиче).
  - **Состояние ядра:** клон `SagerNet/sing-box` `v1.14.0-alpha.30`, **vanilla**, ветка `bublik-dev` (== тег, без изменений). **vk-turn пока НЕ влит** — это отдельная будущая фича. Отдельный git-репо, от `x-ray/` не зависит.
  - `Libbox.xcframework` уже собран из этого ядра и лежит в клиенте (gitignored). Пересобрать — командой ниже (раздел «Сборка»). Девайс-сборка разблокирована (нужны Libbox + ветка `feature/device-signing`).
- **Каталог `../../../x-ray/` — только референс** (старая «грязная» реализация: `x-ray/sing-box-for-apple/` с TURN вариантов A→B и `x-ray/sing-box/` с влитым vk-turn). Использовать для сверки, **не копировать вслепую**. Цель — чтобы `x-ray/` можно было когда-нибудь удалить: новые чистовые версии не должны от него зависеть.
- Детали интеграции — корневой CLAUDE.md, раздел «iOS/macOS-клиент … + TURN».
- **Формат TURN-в-подписке** (как страница подписки Remnawave отдаёт per-server TURN-инфо, вариант B) — образец/спецификация в `turn-subscription-sample.jsonc` (корень этого репо).

## Git-флоу (ОБЯЗАТЕЛЬНО)
1. **База — `dev`.** На каждую задачу от `dev` заводим отдельную фичеветку: `feature/<краткое-имя>`. Прямо в `dev` не коммитим.
   ```sh
   git checkout dev && git pull
   git checkout -b feature/<имя>
   ```
2. Remote — `origin` (`git@github.com:ShuNegus/sing-box-for-apple.git`). Push фичеветки по запросу/при завершении.
3. **Коммитить/пушить только когда пользователь попросил.**
4. Завершение задачи: удалить артефакты плана/прогресса (см. ниже), затем мердж в `dev`:
   ```sh
   git checkout dev
   git merge --no-ff feature/<имя>
   ```
   Ветку фичи после мерджа можно удалить.

## Рабочий цикл задачи (ОБЯЗАТЕЛЬНО)
1. **Перед работой** — всегда пишем план в `docs/tasks/<имя>/PLAN.md` (формат md): цель, шаги, файлы которые трогаем, критерий готовности.
2. **По ходу** — всегда ведём `docs/tasks/<имя>/PROGRESS.md` (формат md): что сделано, что осталось, грабли, текущий статус сборки.
3. **PLAN.md и PROGRESS.md можно (и нужно) коммитить в фичеветку** — они часть истории работы над задачей.
4. **Когда задача завершена** — удаляем файлы-артефакты (`docs/tasks/<имя>/`), коммитим удаление, и **только потом** мерджим фичеветку в `dev`. В `dev` артефакты плана/прогресса не попадают.

> Итог: `dev` всегда чистый (код + этот CLAUDE.md), вся «рабочая кухня» живёт во временных md внутри фичеветки и исчезает при мердже.

## Сборка
- **Libbox.xcframework** — из чистового ядра `../sing-box/` (форк gomobile `@v0.1.13`):
  ```sh
  # из ../sing-box  (clients/ios/sing-box)
  PATH="$(go env GOPATH)/bin:$PATH" go run ./cmd/internal/build_libbox \
    -target apple -platform ios,iossimulator,macos
  ```
  xcframework копируется в этот репо автоматически.
- **Приложение** (симулятор, без подписи):
  ```sh
  xcodebuild build -scheme SFI -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd
  ```
  Схемы: **SFI** (iOS), **SFM** (macOS), **SFT** (tvOS). `make build_ios` тоже есть.
- `Library`/`ApplicationLibrary` — синхронизированные folder-группы: новые `.swift` подхватываются автоматически, `pbxproj` править не надо.
- **На симуляторе VPN-туннель НЕ работает** (NetworkExtension недоступен) — только UI. Живой трафик — только на девайсе или в SFM (macOS).

## Подпись под девайс (аккаунт claude@smd.su)
- `BASE_PACKAGE_IDENTIFIER=su.smd.sing-box` → app group `group.su.smd.sing-box`, iCloud `iCloud.su.smd.sing-box`, extension `su.smd.sing-box.extension`. Все `PRODUCT_BUNDLE_IDENTIFIER` → `su.smd.sing-box.*`.
- `DEVELOPMENT_TEAM=7G6756ME5J`, `CODE_SIGN_STYLE=Automatic`. Подпись делает Xcode с `-allowProvisioningUpdates`.
- **Грабля:** из `Extension/Extension.entitlements` убрать `com.apple.developer.networking.multicast` — ограниченный entitlement, авто-провижининг с ним падает («Xcode failed to provision»). Для VPN не нужен.

## TURN-интеграция (что переносим, вариант B — нативный outbound)
Целевая архитектура (из старого форка / плана):
- `vk-turn` — **нативный sing-box outbound** (`type: vk-turn`). VLESS ходит через него `detour`-ом, ядро само тоннелирует. Без локального listener'а и подмены адресов.
- **Go-часть** — в чистовом ядре `../sing-box/`: `protocol/vkturn/outbound.go`, `constant.TypeVKTurn`, регистрация в `include/registry.go`. Дилер — `../../../Turn/References/moroka8/vk-turn-proxy/pkg/clientcore/dialer.go`. (Референс старой реализации — `../../../x-ray/sing-box/`.)
- **Swift-часть** (этот репо), ключевые файлы из старого форка:
  - `Library/Shared/TurnConfigInjector.swift` — инжект per-node `vk-turn` outbound + `detour` к прокси-outbound по совпадению host.
  - `Library/Shared/TurnProfile.swift` — модель/парсер deeplink (`bublik://import?data=<base64>`).
  - `Library/Network/ExtensionProfile.swift` — точка инжекта (`prepareStartOptions`).
  - `ApplicationLibrary/Views/Setting/TurnSettingView.swift` — UI (тумблер + VK-ссылка + импорт bundle + список нод).
  - Преференсы в `SharedPreferences`: `turn_enabled` / `turn_vk_link` / `turn_profiles`.
- VK Calls-ссылка — **отдельное поле, вводится вручную** (эфемерна, в бандле её нет). TURN-конфиг нод — отдельный импорт-deeplink, НЕ часть подписки.
- Выбор сервера — штатным селектором (Dashboard → Groups); дилеры ленивые.

## Подписка Remnawave для sing-box
- sing-box-конфиг генерит **backend** по редактируемому шаблону SINGBOX (uuid `2b988295-d4ad-4bdc-9a7c-7fb663135ca6`), формат **1.14**. Детали и грабли миграции — корневой CLAUDE.md.
- Импорт в приложение: Remote-профиль с **базовым** URL `https://sub.bublik.pro/<shortUuid>` (по UA приложения отдаёт sing-box-объект). **НЕ** суффикс `/json` (это xray-json массив → sing-box падает).
- Валидация конфига перед заливкой: CLI из чистового ядра `../sing-box` (`go build -tags "with_utls,with_gvisor,with_quic,with_clash_api" -o /tmp/sb_test ./cmd/sing-box`), затем `sb_test check -c <config>`.

## Конвенции
- Соблюдать стиль окружающего кода (Swift: `.swiftformat`/`.swiftlint.yml` в корне репо).
- Существенные изменения архитектуры/процессов фиксировать в этом файле и в memory корневого проекта.
