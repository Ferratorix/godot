# Changelog

Формат: [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/), версии — SemVer.

## [0.1.0] — 2026-11-08 — PHASE 0 + PHASE 1

### Добавлено
- Проект Godot 4.5 `GreenHaven/` (Compatibility renderer, ландшафт, 640×360, pixel-perfect).
- Autoload `GameManager` (жизненный цикл Android: pause/resume/back/quit, локаль, этапы).
- Autoload `TimeManager` + `TimeSource`/`SystemTimeSource`/`ManualTimeSource`:
  санированное время, защита от отката часов и некорректных меток, clamp, UI-тик.
- Data-классы `PlaceableData`, `RoomLayoutData`, `RoomObjectPlacement`; 5 объектов и
  комната «Домашняя ферма» как `.tres`.
- Изометрический мир: `FarmRoom` (TileMapLayer, стены, декор, Y-sort), `PlacementGrid`,
  `WorldObject`, `CellHighlight`, `WindowLight`.
- `IsoCamera` (плавность, инерция, границы, pixel-perfect zoom) и
  `TouchGestureHandler` (tap, long press, pan, pinch, drag, мышь/колесо).
- HUD: заголовок этапа, кнопки камеры, подсказка, инфо-панель объекта,
  режим перемещения, обработка «Назад».
- Локализация RU (основная) и EN через `.po`.
- Генератор временной pixel-art графики `tools/generate_placeholder_art.py`.
- Headless-тесты `tests/` и инструмент скриншотов `tools/screenshot.gd`.
- Android export preset, документация в `docs/`.
