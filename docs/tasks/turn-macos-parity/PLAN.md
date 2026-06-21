# PLAN — macOS-паритет TURN (SFM)

**Ветка:** `feature/turn-macos-parity` от `dev`.
**Цель:** довести TURN на macOS (SFM) до уровня iOS. Общая часть (тоггл/пикер/настройки/инжект/карточка статистики/webview-компонент) уже в `ApplicationLibrary`/`Library` и работает на macOS, т.к. macOS-дашборд использует общий `OverviewView`/`ProfileCard`. Закрыть macOS-специфичные пробелы.

## Шаги
0. **Baseline-сборка SFM** as-is — убедиться, что компилируется (фикс при необходимости).
1. **VK-иконка:** добавить `VKTurn.imageset` в `SFM/Assets.xcassets` (как в SFI; ассет в main-бандле каждого app-таргета).
2. **ATS loopback:** добавить `NSAppTransportSecurity → NSAllowsLocalNetworking=true` в `SFM/Info.plist` (для URLSession/WKWebView к `127.0.0.1` — статы + капча).
3. **Капча-webview авто-показ:** в `MacLibrary/MainView` смонтировать `TurnCaptchaMonitor` + `.sheet($monitor.showCaptcha){ TurnCaptchaSheet }`, драйвить `setActive` по статусу туннеля.
4. **Флаг переднего плана:** в `MacLibrary/MainView` писать `AppForegroundState.set(...)` по `controlActiveState` (.key→true, иначе false) + true на onAppear. Нужен для пуша из NE.
5. **Пуш в фоне:** `CaptchaNotifier` уже стартует в общем `ExtensionProvider` (работает и на macOS app-extension). Для **SFM.System** (system extension) — уведомления идут через `UserServiceClient.sendNotification`; проверить путь `CaptchaNotifier` (прямой `UNUserNotificationCenter`) на standalone; при необходимости — маршрутизировать через UserService. Если сложно — для SFM (app-extension вариант) пуш ок, standalone отметить.
6. **Подпись/сборка:** добиться зелёной SFM build; реальный запуск/подпись — пользователь (его Apple-логин). Нотаризация system-extension — вне MVP.

## Проверки
- SFM build (после каждого шага по возможности).
- Девайс (mac): подключиться через TURN → иконка, карточка статистики, тоггл; капча webview; пуш при сворачивании.

## Не входит
- tvOS (SFT) — отдельно.
- Нотаризация/дистрибуция SFM.System.
