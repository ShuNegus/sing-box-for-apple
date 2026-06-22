# PLAN — добавление подписки «Вставить из буфера»

**Ветка:** `feature/paste-subscription` от `dev`.
**Цель:** упростить добавление подписки. На экране выбора способа («New Profile» меню) добавить пункт **Paste from Clipboard**: по нажатию читается буфер, крутится прогресс, подписка создаётся; при ошибке — алерт, прогресс скрывается. Без заполнения формы.

## Поведение
- Пункт «Paste from Clipboard» (первым) в `menuContent` (iOS + macOS; tvOS — нет буфера/опускаем).
- Нажатие:
  1. читаем буфер (UIPasteboard/NSPasteboard);
  2. если пусто/не похоже на URL — алерт «Clipboard is empty»/«No valid link», прогресс не показываем;
  3. иначе показываем прогресс (overlay-крутилка, меню disabled);
  4. создаём remote-профиль (переиспущенный `NewProfileViewModel`): `profileType=.remote`, `remotePath=<буфер>`, `profileName=<из URL>`, `createProfile(...)`. Внутри уже: `normalizeURL` (https://), скачивание, валидация (turn-strip), запись.
  5. успех → выбрать профиль (`selectedProfileID`) + `dismiss()`; ошибка → `createProfile` выставит `alert` (через onError) → показываем алерт, прогресс скрываем.

## Реализация
- **Новый** `Library/Shared/Clipboard.swift` — `Clipboard.string` (кросс-платформенный read: iOS `UIPasteboard.general.string`, macOS `NSPasteboard.general.string(forType:.string)`).
- `NewProfileMenuView`:
  - `@State pasting = false`, `@State alert` (есть).
  - `FormButton "Paste from Clipboard"` (icon `doc.on.clipboard`) → `pasteFromClipboard()`.
  - `pasteFromClipboard()`: читает буфер, валидирует непустоту; создаёт локальный `NewProfileViewModel`, заполняет remote-поля, имя из URL host; `pasting=true`; `await vm.createProfile(environments:, onSuccess: {выбрать+dismiss})`; ошибки уже идут в `vm.alert` — пробросить в наш `alert`; `pasting=false`.
  - overlay `ProgressView` поверх `menuContent` при `pasting`, меню `.disabled(pasting)`.
- Имя профиля: из URL (`host` или последний path-компонент); пусто → "Subscription". `ProfileManager.uniqueName` уже обеспечит уникальность.

## Проверки
- SFI build, SFM build.
- Девайс: скопировать ссылку подписки → Paste from Clipboard → прогресс → профиль добавлен/выбран; скопировать мусор → алерт.

## Не входит
- tvOS (нет системного буфера в этом UX).
