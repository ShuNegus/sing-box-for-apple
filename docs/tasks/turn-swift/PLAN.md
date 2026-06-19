# PLAN — Swift-часть TURN (вариант B, встроенный в подписку)

**Ветка:** `feature/turn-swift` от `dev`.
**Цель:** оживить TURN в приложении: читать `turn`-блок из подписки → инжектить `vk-turn`+`detour` → вырезать `turn` перед ядром; UI — свич TURN и пикер сервера в домашнем блоке + раздел настроек Turn. Это же чинит клиент на текущей live-подписке (которая уже отдаёт `turn`).

## Решения (из обсуждения)
- **Свич TURN = фильтр пикера.** OFF → пикер показывает все сервера. ON → прячем сервера без TURN. Если включили TURN, а текущий выбор не поддерживает — авто-переключаем на первый поддерживающий.
- **Капча:** в настройках выбор авто/ручной; пробрасываем `manual_captcha`. Реальная ручная (WKWebView) — позже. Авто работает.
- **Пикер в домашнем блоке**, штатный экран Groups остаётся; пикер дёргает тот же selector (`selectOutbound` RPC).
- **Пиры:** настройка `num_streams`, дефолт 10, диапазон 1–50.
- **VK-ссылка:** одна, в настройках. Нет ссылки + TURN on → инжект не делаем, UI подсказывает.
- **Strip всегда:** `turn`-ключ вырезаем из конфига ВСЕГДА (иначе ядро отвергает), инжект — только при TURN on.

## Архитектура / привязка к данным
Конфиг (stored subscription JSON) парсим в модель:
- `turn` блок: `defaults` + `servers{ host → {supported, peer_addr, wrap_key_hex, ...} }`.
- proxy-outbounds: `{tag, type, server(host)}` → карта `tag→host`.
- Производное: `supportedTags` (host ∈ turn.servers && supported), `hasTURN`.
Маппинг тег↔хост: `turn.servers` ключ = `outbound.server` (домен). Пикер фильтрует по host выбранного тега.

**Инжект (`vk-turn` lazy, активна только выбранная нода):** при TURN on для каждого vless-outbound с поддерживаемым host — создать `vk-turn` outbound `{tag: "vk-turn-<host>", ...(defaults ⊕ per-server ⊕ {vk_link, num_streams=peers, manual_captcha})}`, проставить этому vless `detour` на него, добавить в `outbounds`. `vk-turn`-аутбаунды в selector НЕ кладём.

## Файлы
- **Новый** `Library/Shared/TurnSubscription.swift` — парсер `turn`-блока + tag/host карта + `supportedTags`/`hasTURN`. Чистые функции, тестируемо.
- **Новый** `Library/Shared/TurnConfigInjector.swift` — `transform(configJSON, prefs) -> configJSON`: всегда strip `turn`; при on — инжект. Pure.
- `Library/Network/ExtensionProfile.swift` — в `prepareStartOptions()` после `readAsync()` прогнать через `TurnConfigInjector` перед `options["configContent"]`.
- `Library/Database/SharedPreferences.swift` — ключи: `turnEnabled:Bool=false`, `turnVKLink:String=""`, `turnPeers:Int=10`, `turnCaptchaManual:Bool=false`.
- **Новый** `ApplicationLibrary/Views/Setting/TurnSettingView.swift` — раздел настроек: VK-ссылка (TextField), пиры (Stepper/Slider 1–50), капча (Picker авто/ручной).
- `ApplicationLibrary/Views/Setting/SettingView.swift` — `SettingsPage`+`Tabs` добавить `case turn` (title/icon/contentView).
- **Новый** `ApplicationLibrary/Views/Dashboard/Cards/TurnProfileControls.swift` — свич TURN + пикер сервера; рендерим внутри `ProfileCard` когда `hasTURN`.
- `ApplicationLibrary/Views/Dashboard/Cards/ProfileCard.swift` — встроить `TurnProfileControls`.
- `Localizable.xcstrings` — строки добавятся авто при сборке (`String(localized:)`).

## Фазы (сборка+проверка после каждой)
**Ф1 — Плумбинг (ядро работы, чинит клиент на live-подписке):**
- `SharedPreferences` ключи; `TurnSubscription` парсер; `TurnConfigInjector` (strip+inject); врезка в `prepareStartOptions`.
- Проверка: SFI build; юнит-логика инжекта прогнать на семпле (`turn-subscription-sample.jsonc`) скриптом/CLI — на выходе валидный sing-box (strip), и при on — `vk-turn`+detour, `check` проходит.

**Ф2 — Настройки Turn:**
- `TurnSettingView` + регистрация в `SettingView`. Биндинг к prefs.
- Проверка: SFI build; визуально таб появляется (симулятор UI).

**Ф3 — Домашний блок:**
- `TurnProfileControls` (свич + пикер), фильтрация пикера по `supportedTags` при on, авто-переключение сервера, рестарт туннеля при тоггле если подключено. Встройка в `ProfileCard`.
- Проверка: SFI build; визуально.

## Критерий готовности
- TURN off: клиент принимает live-подписку (turn вырезан), всё как раньше.
- TURN on + VK-ссылка: выбранный сервер ходит через `vk-turn` (detour), пикер показывает только поддерживающие.
- Настройки Turn: ссылка/пиры(1–50)/капча сохраняются и применяются.
- SFI собирается; финальный девайс-тест с реальной VK-ссылкой — за пользователем.

## Не входит
- WKWebView для ручной капчи (отдельная задача).
- `experimental/libbox/turn.go` (не нужен для варианта B).
- macOS/tvOS-специфика сверх того, что собирается из общих folder-групп.
