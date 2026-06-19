# PROGRESS — Swift-часть TURN

## Фаза 1 — Плумбинг (strip + inject)  ✅ ГОТОВО
- `SharedPreferences`: добавлены `turnEnabled`/`turnVKLink`/`turnPeers(=10)`/`turnCaptchaManual`.
- `Library/Shared/TurnSubscription.swift` (новый): парсер `turn`-блока (defaults + servers{host}), `supportedHosts`/`hasSupported`; `TurnOutbounds.tagToHost`/`proxyTypes`.
- `Library/Shared/TurnConfigInjector.swift` (новый): `transform(configJSON, prefs)` — ВСЕГДА strip `turn`; при on+vk_link инжект `vk-turn` (defaults ⊕ per-server ⊕ {vk_link, num_streams=peers, manual_captcha}) + `detour` на поддерживаемые vless.
- `ExtensionProfile.prepareStartOptions()`: configContent прогоняется через `TurnConfigInjector` перед отдачей в ядро.

### Проверка логики (реальным ядром)
Скомпилировал оба настоящих Swift-файла standalone (`swiftc`) + мини-main, прогнал на синтетическом конфиге формата подписки (jp=supported, ru=supported:false) и через `sing-box check`:
- **OFF:** `turn` вырезан, нет vk-turn/detour → `check` **VALID**.
- **ON:** `turn` вырезан; ровно 1 vk-turn (только jp; ru пропущен); detour `JP→vk-turn-jp...`, `RU→None`; опции слиты верно (peer_addr/wrap_key per-server, wrap_mode/captcha_solver/streams_per_cred/ready_timeout из defaults, vk_link/num_streams=25/manual_captcha из prefs) → `check` **VALID**.

**Важно:** это чинит клиент на live-подписке — `turn` теперь вырезается всегда.

✅ SFI собирается (BUILD SUCCEEDED).

## Фаза 2 — Настройки Turn  ✅ ГОТОВО
- `ApplicationLibrary/Views/Setting/TurnSettingView.swift` (новый): VK-ссылка (TextField), пиры (Picker 1–50, кросс-платформенно вместо Stepper — tvOS), капча (Picker авто/ручной). Грузит/сохраняет prefs паттерном isLoading+loadSettings+onChangeCompat.
- `SettingView.swift`: добавлен `turn` в `SettingsPage`+`Tabs`, во все switch'и (page/title/icon/contentView/destinationView) и ссылку в тело.
- ✅ SFI BUILD SUCCEEDED.
## Фаза 3 — Домашний блок (свич + пикер)  ✅ ГОТОВО
- `Library/Shared/TurnSubscription.swift`: + `TurnOutbounds.selectorGroup` (офлайн-список серверов из selector).
- `SharedPreferences`: + `turnSelectedServer` (выбор сервера офлайн, применяется при появлении групп).
- `ApplicationLibrary/Views/Dashboard/Cards/TurnProfileControls.swift` (новый): показывается когда конфиг имеет `turn` (hasTURN); свич «Connect through TURN» + пикер сервера. Пикер: лайв-группы (`environments.commandClient.$groups` → `GroupListViewModel`/`selectOutbound`) при подключении, иначе офлайн-список из конфига. При TURN on фильтрует сервера по `supportedHosts`; при включении авто-переключает на поддерживаемый; тоггл рестартит туннель если подключено.
- `ProfileCard.swift`: встроен `TurnProfileControls` в блок профиля.
- ✅ SFI BUILD SUCCEEDED.

## Итог
Все 3 фазы собираются. Клиент: вырезает `turn` всегда (чинит live-подписку), при TURN on инжектит `vk-turn`+detour; настройки Turn (ссылка/пиры/капча); домашний блок (свич + пикер с фильтром). Визуальный/боевой тест на девайсе с реальной VK-ссылкой — за пользователем.

## Фикс — валидация конфига при создании/обновлении профиля  ✅
Девайс-тест выявил: `turn` вырезался только на старте туннеля, но Remnawave-конфиг
валидируется ядром (`LibboxCheckConfig`) ещё при СОЗДАНИИ/ОБНОВЛЕНИИ профиля и в
редакторах — на сыром контенте с `turn` → `decode config: turn: unknown field`.
Решение: `TurnConfigInjector.stripped()` — валидируем ВЫРЕЗАННУЮ копию, храним ОРИГИНАЛ
(нужен UI/инжектору). Поправлены 5 мест: NewProfileViewModel (create), Profile+Update
(update), EditProfileContentViewModel + SFI/MacLibrary ProfileEditorWrapperView (редакторы;
+`import Library`). SFI BUILD SUCCEEDED.
