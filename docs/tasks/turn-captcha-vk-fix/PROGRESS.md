# PROGRESS — фикс капчи VK (обновление VK)

Статус: применено, Libbox пересобран, SFI+SFM собираются. Девайс-тест за пользователем.

## Что было
VK обновил captcha-флоу. Референс-фикс — `samosvalishe/vk-turn-proxy` коммит `b34e1a7 fix: captcha`.
ВАЖНО: `samosvalishe` — РАЗОШЕДШИЙСЯ форк (wrap→SRTP mimicry, серверно-несовместим с нашими нодами на moroka8).
Поэтому взят ТОЛЬКО точечный фикс капчи, не весь форк.

## Применено к нашему vendored `moroka8/vk-turn-proxy/pkg/clientcore/main.go` (go.mod replace)
1. `ParseError`: `captcha_sid` и `captcha_img` теперь ОПЦИОНАЛЬНЫ (раньше отсутствие → return nil = капча не распознавалась). VK иногда шлёт ошибку без них.
2. `getTokenChain` блок отправки: добавлена ветка `captchaErr.CaptchaSid == ""` — новый VK-флоу без captcha_sid: отправляем `success_token` напрямую (`vk_join_link=...&name=...&success_token=...&access_token=...`).
Серверы/ноды НЕ трогаются — фикс чисто клиентский (VK-авторизация в clientcore → Libbox).

## Проверки
- `go build ./...` + `go vet` ядра — чисто.
- Libbox пересобран; строка `name=%s&success_token=%s&access_token=%s` присутствует в бинаре.
- SFI BUILD SUCCEEDED, SFM BUILD SUCCEEDED.

## Девайс-тест
- Подключиться через TURN (где раньше капча ломалась) → авторизация проходит.

## NB
- Изменение в vendored-репо (`Turn/References/moroka8/...`) — рабочее дерево; в Libbox влито через replace. Клиентский коммит — только доки (Libbox gitignored).

## Расширение логов (диагностика "не работает")
- `protocol/vkturn/logbridge.go` (новый, ядро): мост stdlib `log` → sing-box ContextLogger (префикс `vk-turn:`). Подключён в `NewOutbound` (`setupLogForwarding`).
- Теперь строки clientcore `[VK Auth]`/`[Captcha]`/`[STREAM]`/`VK API error`/`FATAL` видны в **Logs приложения** (раньше libbox их не пробрасывал). Большинство — не под isDebug, точка отказа видна без debug-флага.
- Ядро собрано, Libbox пересобран, SFI BUILD SUCCEEDED.

### Что искать в Logs (mac/iOS) после переподключения через TURN:
- `vk-turn: [STREAM N] [VK Auth] ...` — этап авторизации/ошибки.
- `vk-turn: [STREAM N] [Captcha] Solving... / Success! / Auto captcha failed / Triggering manual ...`
- `vk-turn: ... VK API error: ...` или `FATAL` — финальный сбой.
- DNS-сбои всплывут как ошибки dial при попытке коннекта.

## DNS-фоллбеки (устойчивость на будущее)
Проблема: clientcore резолвил только через UDP:53 к 6 IP, причём `net.Dial("udp")` всегда «успешен» (нет рукопожатия) → реального фоллбека нет, при блокировке UDP:53 DNS отваливался. Нет DoH/TCP.

Сделано (vendored `moroka8/pkg/clientcore/resolver_fallback.go`, новый):
- **`newFallbackResolver`** — `net.Resolver`, чей Dial возвращает синтетический **`net.PacketConn`** (важно: без PacketConn `net.Resolver` использует stream-режим с 2-байтным length-префиксом → «unexpected EOF»; PacketConn = датаграммный фрейминг без префикса).
- **UDP-фастпас конкурентно**: все UDP-серверы опрашиваются параллельно (`udpFanout`), первый валидный ответ выигрывает, общий дедлайн 1.5с (раньше мёртвый сервер вис 2с последовательно).
- **DoH-фоллбек (HTTPS/443)** когда UDP недоступен: wireformat POST по IP (без bootstrap-DNS), SNI = провайдер. Порядок: **Yandex** (77.88.8.8) → Google (8.8.8.8) → Cloudflare (1.1.1.1).
- Грабля Cloudflare: 400 без явного `Content-Length` → проставлен `req.ContentLength` + `GetBody`.
- Установлен в `setupGlobalResolver` (net.DefaultResolver) и `getCustomNetDialer`.

Yandex — первый и в UDP-списке, и в DoH (наиболее доступен в РФ).

Тесты (go test, реальная сеть):
- real-udp LookupHost: ок, 1.4мс.
- DoH end-to-end (UDP-список пуст → чистый DoH): vk.com/api.vk.com/dns.google/cloudflare.com → реальные IPv4+IPv6, 100–530мс.
- Yandex DoH wireformat: 4/4 на 77.88.8.8 и 77.88.8.1. Google 4/4, Cloudflare 3/3 (после Content-Length фикса).
- Ядро + Libbox пересобраны; SFI + SFM BUILD SUCCEEDED.
