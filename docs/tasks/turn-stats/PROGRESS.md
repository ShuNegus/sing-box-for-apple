# PROGRESS — статистика TURN

Статус: реализовано, собирается (ядро + Libbox + SFI). Девайс-тест за пользователем.

## Go (ядро bublik-dev + clientcore) + Libbox  ✅
- clientcore `dialer.go`: `Dialer.SessionCount()` (активные сессии=пиры), `Dialer.OpenedStreams()` (всего стримов).
- `protocol/vkturn/stats.go` (новый): реестр outbound'ов + loopback stats-HTTP `127.0.0.1:8766/stats` (sync.Once), JSON-массив `{tag, peer_addr, target, active, opened, started}`.
- `protocol/vkturn/outbound.go`: `target` (=num_streams/10), `Stats()`, регистрация в `NewOutbound`/снятие в `Close`, дилер под `sync.RWMutex` (читается stats-горутиной).
- `go build ./...` + `go vet` чисто. Libbox пересобран (в бинаре `127.0.0.1:8766` + `/stats`).

## Swift  ✅
- `Library/Shared/TurnStats.swift` (новый): `TurnStat` (Codable) + `TurnStats.fetchAll()` (URLSession GET, таймаут 2с).
- `ApplicationLibrary/Views/Dashboard/Cards/TurnStatsView.swift` (новый): поллит 2с, показывает для активного сервера (по host выбранного / max active) этап (Waiting/Connecting/Establishing/Active), `active/target` пиров, opened streams. Self-gating: пусто пока нет данных.
- `TurnProfileControls`: под пикером `TurnStatsView(activeHost:)` при `turnEnabled`; `activeHost` = host выбранного сервера.

## Проверки
- SFI BUILD SUCCEEDED.

## Девайс-тест
- Подключиться через TURN → под пикером блок: этап + рост пиров (active/target) + opened.

## Не входит
- Скорость/трафик per-TURN (sing-box считает общий; per-detour позже).
