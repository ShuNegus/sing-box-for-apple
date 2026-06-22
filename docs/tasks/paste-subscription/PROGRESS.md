# PROGRESS — Paste from Clipboard

Статус: реализовано, собирается (SFI + SFM). Девайс-тест за пользователем.

## Сделано
- `Library/Shared/Clipboard.swift` (новый): кросс-платформенное чтение буфера (UIPasteboard/NSPasteboard).
- `NewProfileMenuView`: пункт **Paste from Clipboard** (первым, `#if !os(tvOS)`, icon doc.on.clipboard) + overlay-крутилка прогресса (`pasting`) с `.disabled(pasting)`.
- `pasteFromClipboard()`: читает буфер → пусто → алерт «Clipboard is empty»; иначе создаёт remote-профиль через переиспользованный `NewProfileViewModel` (type=.remote, remotePath=буфер, name=host из URL). Прогресс on; по завершении: ошибка `vm.alert` → наш alert (крутилка скрыта), успех → выбрать профиль + dismiss.
- Имя профиля из URL host (нормализованного), иначе "Subscription". Уникальность — `ProfileManager.uniqueName`.
- Переиспользована существующая логика create: normalizeURL (auto https), скачивание, валидация (turn-strip), запись.

## Проверки
- SFI BUILD SUCCEEDED, SFM BUILD SUCCEEDED.

## Девайс-тест
- Скопировать ссылку подписки → + → Paste from Clipboard → крутилка → профиль добавлен и выбран.
- Скопировать мусор/пусто → алерт, крутилка скрыта.

## Не входит
- tvOS (нет системного буфера в этом UX).
