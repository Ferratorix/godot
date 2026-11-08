# Архитектура Green Haven

## Принципы

1. **Модули по ответственности**, взаимодействие через сигналы. Нет «божественного» скрипта.
2. **Data-driven**: всё, что можно описать данными, — `Resource` (`.tres`) + локализационные ключи.
3. **Логика ≠ представление**: чистые классы (`PlacementGrid`, `TimeManager`-математика,
   `TouchGestureHandler`) тестируются без рендера; узлы-представления (`WorldObject`,
   `Hud`) ничего не решают.
4. **Однонаправленные зависимости** (см. схему); UI и мир не знают друг о друге —
   их соединяет `Main`.

## Схема зависимостей (PHASE 1)

```
                    ┌──────────── Autoloads ─────────────┐
                    │ GameManager   TimeManager           │
                    │   │ lifecycle   │ TimeSource ◄─ System/Manual
                    └───┼─────────────┼───────────────────┘
                        │ signals     │ now()
 scenes/main/main.tscn  ▼             ▼
 Main (scripts/main/main.gd) ── wires ──┐
   ├── FarmWorld (farm_world.gd)        │      ├── UI (CanvasLayer)
   │     ├── Room: FarmRoom ◄── RoomLayoutData (.tres)
   │     │     ├── Floor: TileMapLayer (iso, 32×16)       └── Hud (hud.gd)
   │     │     ├── Walls (Sprite2D slices)                    сигналы намерений:
   │     │     ├── FloorOverlay: CellHighlight                zoom / move / back
   │     │     ├── Objects (y_sort) → WorldObject ◄─ PlaceableData
   │     │     ├── Ambience → WindowLight
   │     │     └── PlacementGrid (RefCounted, логика занятости)
   │     ├── Camera: IsoCamera
   │     └── Gestures: TouchGestureHandler
```

## Модули

| Модуль | Файл | Ответственность |
|---|---|---|
| GameManager (autoload) | `scripts/core/game_manager.gd` | жизненный цикл (pause/resume/back/quit), локаль, текущий этап |
| TimeManager (autoload) | `scripts/core/time_manager.gd` | санированное реальное время, защита от отката часов, тик UI раз в секунду |
| TimeSource и наследники | `scripts/core/*time_source.gd` | источник Unix-времени (системный / ручной для тестов) |
| PlaceableData | `scripts/data/placeable_data.gd` | описание размещаемого объекта |
| RoomLayoutData / RoomObjectPlacement | `scripts/data/room_*.gd` | описание комнаты и стартовой расстановки |
| PlacementGrid | `scripts/world/placement_grid.gd` | занятость клеток, проверка/перемещение, сериализация |
| FarmRoom | `scripts/world/farm_room.gd` | построение комнаты из данных, координаты, выбор, drag&drop |
| WorldObject | `scripts/world/world_object.gd` | визуал объекта, анимации выбора/установки, pixel hit-test |
| CellHighlight | `scripts/world/cell_highlight.gd` | подсветка клеток |
| WindowLight | `scripts/world/window_light.gd` | декоративный луч света и пылинки |
| IsoCamera | `scripts/world/iso_camera.gd` | плавная камера, инерция, границы, pixel-perfect zoom |
| TouchGestureHandler | `scripts/world/touch_gesture_handler.gd` | жесты: tap, long press, pan, pinch, drag; мышь |
| FarmWorld | `scripts/world/farm_world.gd` | политика взаимодействия: жесты → камера/комната |
| Hud | `scripts/ui/hud.gd` | интерфейс, сигналы намерений игрока |
| Main | `scripts/main/main.gd` | связывание мира и UI |

## Ключевые правила

### Ввод
* `emulate_mouse_from_touch = true` — чтобы кнопки UI работали от касаний;
  `TouchGestureHandler` игнорирует эмулированные события мыши
  (`device == DEVICE_ID_EMULATION`), поэтому касание не обрабатывается дважды.
* Мир получает ввод в `_unhandled_input`: касания поверх панелей UI до мира не доходят.
* Корень HUD имеет `mouse_filter = IGNORE`, панели — `STOP`.

### Pixel-perfect
* Базовое разрешение 640×360, `stretch_mode = canvas_items`, `aspect = expand`.
* Фильтрация текстур — Nearest; привязка трансформаций и вершин к пикселям.
* После жеста масштаба камера снапится к уровню, где `zoom × stretch_scale` —
  целое число (каждый пиксель арта = N×N экранных пикселей).

### Изометрия и сортировка
* `TileSet`: `tile_shape = ISOMETRIC`, `tile_layout = DIAMOND_DOWN`, 32×16.
* Позиция объекта = центр клетки; родитель `Objects` с `y_sort_enabled`.
* Стены строятся по соседям клеток (`get_neighbor_cell`), т.е. не зависят от раскладки.
* Все преобразования клетка↔мир — только через `FarmRoom.cell_to_world/world_to_cell`.

### Время (контракт для PHASE 2–3)
* Игровые системы **никогда** не вызывают `Time.get_unix_time_from_system()` —
  только `TimeManager.now()/seconds_until()/progress()`.
* Состояние процессов хранится метками начала/окончания и вычисляется по запросу.
* Параметры цикла фиксируются при старте цикла.

## Планируемые модули (не реализованы)

| Фаза | Модуль | Тип | Связь |
|---|---|---|---|
| 2 | `PlantData`, `PlantInstance`, `GrowSlot` | Resource / RefCounted | `TimeManager` |
| 4 | `EconomyManager` | autoload | единственная точка изменения баланса |
| 4 | `InventoryManager` | autoload | склад, сигнал `item_changed` |
| 4 | `EquipmentData` + модификаторы | Resource | влияет на новые циклы `PlantInstance` |
| 5 | `ProgressionManager` | autoload | XP, уровни, навыки, открытия |
| 6 | `SaveManager` | autoload | JSON, версии, миграции, бэкап, атомарная запись |

Autoload добавляются только по мере реальной реализации — пустых заглушек нет.

## Структура каталогов

```
GreenHaven/
├── project.godot, export_presets.cfg, icon.png
├── assets/
│   ├── placeholder/   ← временная генерируемая графика (заменяемая)
│   └── sprites/…, tilesets/, ui/, fonts/, audio/   ← финальные ассеты
├── scenes/  main/ farm/ greenhouse/ objects/ ui/
├── scripts/ core/ data/ world/ main/ ui/ farming/ economy/ progression/ equipment/
├── resources/ placeables/ rooms/ plants/ equipment/ products/ buildings/
├── data/    balance/ localization/ (*.po)
├── tests/   run_tests.gd + test_*.gd
├── tools/   generate_placeholder_art.py
└── docs/
```

Отличия от исходной структуры: добавлены `scripts/data` (классы ресурсов),
`scripts/world` (изометрический мир; общий для фермы/теплицы), `scripts/main`,
`resources/placeables`, `resources/rooms`, `assets/placeholder`, `tools`.
