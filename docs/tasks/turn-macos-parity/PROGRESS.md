# PROGRESS — macOS-паритет TURN

Статус: реализовано, собирается (SFM). Девайс-тест (mac) за пользователем.

## Сделано
- **Baseline:** SFM собирается as-is — общий TURN-код (тоггл/пикер/настройки/инжект/карточка статистики/webview) компилируется под macOS (macOS-дашборд использует общий OverviewView/ProfileCard).
- **VK-иконка:** `VKTurn.imageset` добавлен в `MacLibrary/Assets.xcassets` (macOS-эквивалент SFI/Assets.xcassets; компилируется в main-бандл SFM). Проверено: VKTurn в собранном Assets.car.
- **ATS loopback:** `NSAppTransportSecurity → NSAllowsLocalNetworking=true` в `SFM/Info.plist` и `SFM.System/Info.plist`. Проверено в собранном Info.plist.
- **Капча-webview авто-показ:** в `MacLibrary/MainView` — `@StateObject TurnCaptchaMonitor`, `setActive(true)` на onAppear, `.sheet($captchaMonitor.showCaptcha){ TurnCaptchaSheet }`. (Монитор self-гейтится по turnEnabled + probe порта, так что показ только при реальной капче.)
- **Флаг переднего плана:** `AppForegroundState.set(controlActiveState != .inactive)` на onAppear + onChangeCompat(controlActiveState). Нужен для пуша из NE.
- Запрос пермишена на уведомления — через общий `TurnProfileControls` (работает на macOS).

## Проверки
- SFM BUILD SUCCEEDED. VKTurn в Assets.car. ATS в Info.plist.

## Девайс-тест (mac, за пользователем)
- Подключиться через TURN → VK-иконка (тоггл/настройки/карточка), карточка статистики, пикер.
- Капча: webview всплывает; пуш при неактивном окне.

## Не закрыто / отметка
- **SFM.System (system extension):** пуш капчи из system-extension через прямой UNUserNotificationCenter (`CaptchaNotifier`) может не доставляться — на standalone уведомления идут через `UserServiceClient`. Для обычного SFM (app-extension) — ок. Проверить/доработать при использовании standalone.
- tvOS (SFT) — отдельно.
- Реальная подпись/нотаризация SFM.System — вне MVP (за пользователем, его Apple-логин).
