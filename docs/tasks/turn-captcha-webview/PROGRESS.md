# PROGRESS — ручная капча через WKWebView

Статус: реализовано, собирается (iOS). Боевой тест на девайсе — за пользователем.

## Сделано (MVP, без изменений Go/Libbox)
- `Library/Shared/TurnCaptcha.swift` (новый): константы `127.0.0.1:8765` + `probe()` — чистая TCP-проба через `NWConnection` (без HTTP-побочек), таймаут 1с.
- `ApplicationLibrary/Views/Dashboard/TurnCaptchaMonitor.swift` (новый): `ObservableObject`, поллит порт (1.5с) пока `turnEnabled && captchaManual && туннель активен`; показ по переходу down→up (`showCaptcha`), авто-скрытие когда сервер пропал (капча решена), подавление после ручного закрытия до следующего цикла.
- `ApplicationLibrary/Views/Dashboard/TurnCaptchaWebView.swift` (новый, `#if !os(tvOS)`): `TurnCaptchaSheet` + кросс-платформенная обёртка WKWebView (UI/NSViewRepresentable), грузит `http://127.0.0.1:8765`.
- `SFI/MainView.swift`: `@StateObject` монитор; `setActive` по статусу туннеля (connecting/connected/reasserting) в `updateButtonVisibility`; `.sheet($captchaMonitor.showCaptcha, onDismiss: userDismissed)`.
- `ApplicationLibrary/Views/Setting/TurnSettingView.swift`: фолбэк-кнопка «Solve Captcha» (ручной запуск шита) при manual-режиме + футер капчи обновлён.
- `SFI/Info.plist`: `NSAppTransportSecurity → NSAllowsLocalNetworking=true` (http к loopback для WKWebView).

## Как работает
captcha=Manual → инжектор ставит `manual_captcha:true` → clientcore в расширении поднимает локальный сервер `127.0.0.1:8765` при капче → монитор приложения детектит → показывает WKWebView → юзер решает → токен ловит локальный сервер → сервер выключается → монитор скрывает шит → TURN-сессия встаёт.

## Проверки
- SFI BUILD SUCCEEDED.
- tvOS (SFT) локально не собран — платформа tvOS не установлена; WebKit/iOS-only места закрыты `#if !os(tvOS)`.

## Риск (проверить на девайсе)
- **Достучится ли приложение до loopback расширения** (`127.0.0.1:8765`) — главное допущение. Если нет — MVP невалиден, нужен command-канал (отдельная фича).
- Капча VK появляется не всегда — для теста надо поймать.

## Фикс — капча показывалась многократно (девайс)
Webview/loopback работают (шит появляется и закрывается = токен доходит до ядра). Но капча
повторялась: vk-turn просит **по капче на каждый credential**, число credential =
`num_streams / streams_per_cred`. Шаблон забил `streams_per_cred: 2` при `num_streams=10` (peers)
→ 5 credential → 5 капч. (Кэш по `cacheKey=streamID/streams_per_cred`, потоки одного cacheKey
переиспользуют credential — `getVkCredsCached`.) **Фикс:** инжектор ставит
`streams_per_cred = num_streams` (peers) → 1 credential = **1 капча** (дефолтное поведение референса).
Только Swift, без пересборки Libbox. Проверено standalone: num_streams=20/streams_per_cred=20 → 1.
