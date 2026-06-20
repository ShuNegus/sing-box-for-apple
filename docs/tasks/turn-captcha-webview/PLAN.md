# PLAN — ручная капча VK через WKWebView

**Ветка:** `feature/turn-captcha-webview` от `dev`.
**Цель:** когда vk-turn в ручном режиме капчи (`captchaManual`) упирается в капчу, показать в приложении **WKWebView**, в котором юзер её решает; после решения TURN-сессия поднимается.

## Архитектура (решение по разведке)
- clientcore в ручном режиме поднимает **локальный HTTP-сервер на фиксированном `127.0.0.1:8765`** (внутри процесса расширения), отдаёт переписанную страницу капчи, **блокирует** до получения токена (ловит сам) и затем **выключается**.
- Логи clientcore (stdlib `log`/`fmt`) в варианте B **НЕ доходят** до лог-стрима приложения (в libbox нет общего захвата stderr) → лог-детект отпадает. Command-канал — чисто, но дорого (Go+Swift+пересборка Libbox).
- **Выбрано (MVP, без изменений Go/Libbox):** приложение **поллит** `http://127.0.0.1:8765`, пока TURN активен и режим капчи ручной. Ответил → показываем WKWebView-шит. Перестал отвечать (капча решена → сервер выключился) → закрываем шит. На iOS loopback общий между процессами, так что app достучится до сервера расширения (ключевое допущение — проверяем на девайсе).

## Файлы
- **Новый** `Library/Shared/TurnCaptcha.swift` — константы (`127.0.0.1:8765`, URL) + `probe()` (URLSession HEAD, короткий таймаут) → доступен ли сервер.
- **Новый** `ApplicationLibrary/Views/Dashboard/TurnCaptchaWebView.swift` — обёртка WKWebView (`UIViewRepresentable` iOS / `NSViewRepresentable` macOS), грузит URL; JS-хук на `window.close`/«Done!» → колбэк закрытия.
- **Новый** `ApplicationLibrary/Views/Dashboard/TurnCaptchaMonitor.swift` — `ObservableObject`: пока (`turnEnabled && captchaManual && tunnel running`) поллит порт; `@Published showCaptcha`. Останавливается при дисконнекте/закрытии.
- `SFI/MainView.swift` (+ macOS-аналог) — смонтировать монитор и `.sheet(isPresented: $monitor.showCaptcha) { TurnCaptchaWebView }`.
- `ApplicationLibrary/Views/Setting/TurnSettingView.swift` — кнопка-фолбэк «Solve captcha» (ручной запуск шита) на случай, если автопул не сработает.
- `SFI/Info.plist` (+ `SFM/Info.plist`) — `NSAppTransportSecurity → NSAllowsLocalNetworking = true` (разрешить http к loopback для WKWebView и URLSession-пробы).

## Детектирование завершения
- Основное: следующий poll после успеха не отвечает (сервер выключился) → закрыть шит.
- Доп.: JS в WKWebView перехватывает `window.close()` / появление «Done!» → сообщение → закрыть (быстрее, чем poll).

## Гейтинг
Поллим/показываем только при `turnEnabled == true && captchaManual == true && статус туннеля ∈ {connecting, connected}`. Иначе не трогаем.

## Проверки
- SFI build (компиляция, ATS, WKWebView).
- Боевой тест на девайсе: TURN on + captcha=Manual + поймать капчу → шит появляется, решаем, TURN встаёт. (За пользователем; капча VK появляется не всегда.)

## Риски
- **Loopback reachability app↔NE** — главное допущение; если не достучимся, MVP невалиден → переходим на command-канал (отдельная фича). Поэтому MVP заодно дёшево проверяет это допущение.
- ATS/http к 127.0.0.1 — лечится `NSAllowsLocalNetworking`.
- Капча в ядре могла быть proxy-режим (VK-страница) — WKWebView грузит её через локальный сервер как есть.

## Не входит
- Command-server канал для авто-сигнала (если поллинг достаточен — не нужен).
- Изменения в clientcore/Go.
