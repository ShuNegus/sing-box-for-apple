# PROGRESS — fallback webview + локальный пуш

Статус: реализовано, собирается (SFI + Extension). Девайс-тест за пользователем.

## A. Fallback webview (авто провал → webview)  ✅
- `TurnCaptchaMonitor`: снят гейт `captchaManual` — поллит при `turnEnabled` (любой режим капчи); сервер `:8765` появляется только когда ручное решение реально нужно (ручной режим ИЛИ авто эскалировал auto→sliderPOC→manual). Логика показа: «показывать пока reachable && !suppressed» (не rising-edge) → webview всплывает и после возврата из фона с поднятым сервером.

## B. Локальный пуш когда приложение не на переднем плане  ✅
- `Library/Shared/AppForegroundState.swift` (новый): Bool-флаг в app-group UserDefaults (`app_foreground`); дефолт true (нет ложных пушей на платформах без записи флага).
- `SFI/MainView.swift`: пишет флаг по `scenePhase` (.active→true, иначе false) + true на onAppear.
- `Library/Network/CaptchaNotifier.swift` (новый): крутится в NE-процессе; поллит `:8765`, на rising-edge при `!isForeground` постит локальный пуш (`UNUserNotificationCenter`, timeSensitive); снимает пуш когда сервер пропал.
- `Library/Network/ExtensionProvider.swift`: `captchaNotifier.start()` после «Here I stand», `.stop()` в `stopTunnel`.
- `TurnProfileControls.setTurnEnabled(true)`: запрашивает разрешение на уведомления (`requestAuthorization([.alert,.sound])`, `#if !os(tvOS)`).
- Тап по пушу → дефолт открывает приложение → foreground-монитор детектит сервер → webview.

## Проверки
- SFI BUILD SUCCEEDED; Extension target BUILD SUCCEEDED (NE линкует CaptchaNotifier/AppForegroundState).
- tvOS — UserNotifications под `#if !os(tvOS)`.

## Девайс-тест (за пользователем)
- A: captcha=Auto, поймать провал авто → webview всплывает сам.
- B: при коннекте свернуть приложение → прилетает пуш → тап → webview.

## Не входит
- Запись флага переднего плана на macOS (дефолт true → пуши на macOS не шлются; foreground-webview работает). Доделать при необходимости.

## Фикс — пермишен не запрашивался (девайс)
Запрос разрешения висел только на `setTurnEnabled(true)`, но TURN уже был включён → свич не
переключался → промпт не вызывался → без разрешения NE-пуши молча не доставлялись.
Фикс: `Library/Shared/TurnNotifications.requestAuthorizationIfNeeded()` (проверяет `.notDetermined`)
и вызов в надёжных контекстных местах: при загрузке домашних контролов (`TurnProfileControls.load`,
если `hasTURN`) и при включении свича. tvOS под `#if !os(tvOS)`.
