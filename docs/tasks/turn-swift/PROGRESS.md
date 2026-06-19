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

## Фаза 2 — Настройки Turn  — TODO
## Фаза 3 — Домашний блок (свич + пикер)  — TODO
