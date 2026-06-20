# PLAN — fallback webview при провале авто-капчи + локальный пуш в фоне

**Ветка:** `feature/turn-captcha-fallback-push` от `dev`.
**Цель:**
1. Если **авто**-решение капчи провалилось — показать webview (как в ручном режиме).
2. Если приложение **не на переднем плане** в момент появления капчи — прислать локальный пуш; тап открывает приложение → webview.

Только Swift, без Go/Libbox (пересборка Libbox не нужна).

## Факты (из кода ядра/клиента)
- Ядро само эскалирует капчу: auto → sliderPOC → **manual** (`captchaSolveModeForAttempt`). На manual-ветке `solveCaptchaViaProxy/HTTP` поднимает локальный сервер `127.0.0.1:8765` и ждёт до 3 мин. → **сервер появляется и в авто-режиме при провале**.
- NE-процесс (`ExtensionProvider`) жив, пока туннель работает; сервер капчи — в нём же. NE уже умеет `UNUserNotificationCenter` (`ExtensionPlatformInterface.sendNotification`). Логи NE доходят в приложение (`writeMessage`).
- App уже `UNUserNotificationCenterDelegate` (`SFI/ApplicationDelegate`), есть app-group (`AppConfiguration.appGroupID`).

## A. Fallback webview (авто провал → webview)
- `TurnCaptchaMonitor`: **снять гейт `captchaManual`** — поллить при `turnEnabled && туннель активен` (режим капчи не важен; сервер появляется только когда ручное решение реально нужно).
- Переписать логику показа на «показывать пока reachable && !suppressed» (а не только rising-edge), чтобы после возврата из фона (сервер уже поднят) webview показался. `suppressed` сбрасывается, когда сервер пропал.

## B. Локальный пуш в фоне (источник — NE)
- **Флаг переднего плана:** `Library/Shared/AppForegroundState.swift` — read/write Bool в `UserDefaults(suiteName: AppConfiguration.appGroupID)`, ключ `app_foreground`. Дефолт при отсутствии — `true` (безопасно: нет ложных пушей).
- **App пишет флаг:** `SFI/MainView` по `scenePhase` (.active → true; .background/.inactive → false). Инициализировать true при `.onAppear`.
- **NE поллит и шлёт пуш:** новый `Library/Network/CaptchaNotifier.swift` — поллит `127.0.0.1:8765` (1.5с); на rising-edge (сервер появился), если `app_foreground == false`, постит локальное уведомление через `UNUserNotificationCenter` («Solve captcha to connect through TURN»). Дебаунс (один пуш на появление). Старт — в `ExtensionProvider` после «Here I stand»; стоп — в `stopTunnel`.
- **Пермишен:** запрашивать в приложении при включении TURN-свича (`TurnProfileControls.setTurnEnabled(true)`) — `UNUserNotificationCenter.requestAuthorization([.alert, .sound])`. Если не выдан — работает только foreground-webview (graceful).
- **Тап по пушу:** без OPEN_URL → дефолт открывает приложение → монитор (foreground) детектит сервер → webview.

## Гейтинг NE-нотификатора
Поллить только если в конфиге реально есть vk-turn (TURN активен). Простее: NE стартует нотификатор всегда при запуске туннеля, но поллинг порта дёшев и сервер появляется лишь при капче — ложных срабатываний нет. Оставляем безусловный старт при туннеле, дебаунс по rising-edge.

## Файлы
- `ApplicationLibrary/Views/Dashboard/TurnCaptchaMonitor.swift` — снять гейт, логика показа.
- **Новый** `Library/Shared/AppForegroundState.swift` — флаг в app-group.
- **Новый** `Library/Network/CaptchaNotifier.swift` — NE-поллер + пуш.
- `Library/Network/ExtensionProvider.swift` — старт/стоп нотификатора.
- `SFI/MainView.swift` — писать флаг переднего плана по scenePhase.
- `ApplicationLibrary/Views/Dashboard/TurnProfileControls.swift` — запрос пермишена при включении TURN.

## Проверки
- SFI build. (tvOS — guards, как в прошлой фиче.)
- Девайс: (A) captcha=Auto, поймать провал → webview. (B) свернуть приложение при коннекте → пуш → тап → webview.

## Не входит
- macOS-специфика записи флага (флаг по умолчанию true → на macOS пуши не шлются; foreground-webview работает). Доделать позже при необходимости.
- Go/Libbox изменения.
