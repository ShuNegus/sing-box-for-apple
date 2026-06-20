# PLAN — статистика TURN-прокси в дашборде

**Ветка (клиент):** `feature/turn-stats` от `dev`. **Ядро:** правки на `bublik-dev` (репо `clients/ios/sing-box`).
**Цель:** при подключении через TURN показывать блок статистики: этап подключения, сколько пиров (TURN-сессий) поднялось из цели, + всего открыто стримов.

## Источник данных (Go)
- `clientcore.Dialer`: `pool.count()` = активные сессии (пиры), `pool.connCounter` = всего открыто стримов. `cfg.NumStreams` = цель (= peers).
- Дилер ленивый (создаётся при первом dial через detour). Только активная нода имеет живой дилер.

## Go-изменения (ядро + clientcore) → пересборка Libbox
1. **clientcore `dialer.go`** (vendored, local replace): экспорт-аксессоры
   - `func (d *Dialer) SessionCount() int { return d.pool.count() }`
   - `func (d *Dialer) OpenedStreams() uint64 { return d.pool.connCounter.Load() }`
2. **`protocol/vkturn/stats.go`** (новый): пакетный реестр outbound'ов (`map[tag]*Outbound`, mutex) + stats-HTTP-сервер на `127.0.0.1:8766` (sync.Once), отдаёт JSON-массив `{tag, peer_addr, target, active, opened, started}`.
3. **`protocol/vkturn/outbound.go`**: регистрировать в `NewOutbound`, снимать в `Close`; метод `Stats()`; старт stats-сервера в `NewOutbound`.

## Swift
- **Новый** `Library/Shared/TurnStats.swift`: модель `TurnStat` + `fetchAll()` (URLSession GET `127.0.0.1:8766/stats`, decode JSON; короткий таймаут).
- **Новый** `ApplicationLibrary/Views/Dashboard/Cards/TurnStatsView.swift`: блок статистики. Поллит ~2с пока TURN активен и туннель connected. Показывает для активного сервера (по выбранному host / `started`): этап, `active/target` пиров, opened.
  - Этапы (по active): 0 → «Подключение…»; 0<active<target → «Установка сессий»; active≥1 → «Активно» (или ≥target → «Активно»).
- Встроить в `TurnProfileControls` (под пикером) либо в `ProfileCard`.

## Гейтинг
Показывать только при `turnEnabled && hasTURN && туннель connected`. Stats-сервер живёт только когда есть vk-turn outbound (TURN on).

## Проверки
- Go: `go build ./...` ядра; пересобрать Libbox; `strings` проверка.
- SFI build.
- Девайс: подключиться через TURN → блок показывает рост пиров и этап.

## Не входит
- Скорость/трафик per-TURN (sing-box уже считает общий трафик; per-detour — позже при желании).
- macOS-специфика (блок общий, должен работать; фокус iOS).
