# Архитектура Green Haven

## Принципы

1. **Модули по ответственности**, взаимодействие через сигналы. Нет «божественного» скрипта.
2. **Data-driven**: всё, что можно описать данными, — `Resource` (`.tres`) + локализационные ключи.
3. **Логика ≠ представление**: чистые классы (`PlacementGrid`, `TimeManager`-математика,
   `TouchGestureHandler`) тестируются без рендера; узлы-представления (`WorldObject`,
   `Hud`) ничего не решают.
4. **Однонаправленные зависимости** (см. схему); UI и мир не знают друг о друге —
   их соединяет `Main`.

## Слои и зависимости (v0.2)

```
 Данные (Resource .tres)      PlantData · ProductData · EquipmentData · PlaceableData
                              RoomLayoutData · CatalogData (resources/catalog.tres)
        ▲ GameCatalog (статический кэш, только чтение)
        │
 Autoload (состояние)         TimeManager ◄─ TimeSource
                              InventoryManager      (ни от кого не зависит)
                              EconomyManager    ──► InventoryManager, GameCatalog
                              ProgressionManager──► GameCatalog
                              GameManager       ──► все выше: связывает правила между ними,
                                                    владеет FarmState, boot/new_game
                              SaveManager       ──► собирает/применяет состояние всех
        ▲
 Модель фермы (RefCounted)    FarmState ─► PlacementGrid, PlantInstance, ProductionModifiers
                              (вызывает Inventory/Economy/Progression/TimeManager)
        ▲ сигналы: slot_changed, object_added, equipment_changed, state_changed
        │
 Представление (узлы)         FarmWorld ─► FarmRoom ─► WorldObject (растения, LED, маркер)
                              IsoCamera, TouchGestureHandler
                              Hud ─► Shop / Storage / Skills / SeedPicker / Settings panels
                              SoundPlayer (только слушает сигналы)
                              Main связывает FarmWorld, Hud и SoundPlayer
```

Правила:
* Зависимости только сверху вниз по схеме; autoload-ы не знают о сценах.
* Перекрёстные правила (навык «Торговля» → цена продажи, продажа → опыт) подключает
  `GameManager._wire_systems()`, поэтому Economy и Progression не ссылаются друг на друга.
* UI не меняет поля состояния: только вызывает публичные API (`EconomyManager.buy_item`,
  `FarmState.plant`, `FarmState.purchase_equipment`, `ProgressionManager.upgrade_skill`).
* Каждая система имеет `get_state()/apply_state()` (или `to_dict()/from_dict()`), а
  `apply_state` сама очищает некорректные значения.

## Модули

| Модуль | Файл | Ответственность |
|---|---|---|
| GameManager | `scripts/core/game_manager.gd` | жизненный цикл, boot/new_game, текущая FarmState, связывание систем, сводка возвращения |
| TimeManager | `scripts/core/time_manager.gd` | санированное время, защита от отката, UI-тик |
| SaveManager | `scripts/core/save_manager.gd` | файлы сохранений, целостность, миграции, автосохранение |
| InventoryManager | `scripts/economy/inventory_manager.gd` | количества предметов |
| EconomyManager | `scripts/economy/economy_manager.gd` | монеты, цены, покупки/продажи, журнал |
| ProgressionManager | `scripts/progression/progression_manager.gd` | опыт, уровни, навыки, открытия |
| FarmState | `scripts/farming/farm_state.gd` | размещение, посадочные места, посадка/сбор, оборудование, модификаторы |
| PlantInstance | `scripts/farming/plant_instance.gd` | одна посадка: метки времени, стадия, прогресс |
| ProductionModifiers | `scripts/farming/production_modifiers.gd` | итоговые множители с лимитами |
| GameCatalog / *Data | `scripts/data/` | контент и баланс |
| PlacementGrid | `scripts/world/placement_grid.gd` | занятость клеток, сериализация |
| FarmRoom / WorldObject | `scripts/world/` | отображение комнаты, объектов и растений; выбор и перетаскивание |
| IsoCamera / TouchGestureHandler / FarmWorld | `scripts/world/` | камера, жесты, политика взаимодействия |
| Hud + панели | `scripts/ui/` | интерфейс, карточка задания, настройки |
| GoalTracker / GoalData | `scripts/progression/goal_tracker.gd`, `scripts/data/goal_data.gd` | цепочка заданий (обучение), награды |
| GameSettings | `scripts/core/game_settings.gd` | язык, громкость, лимит FPS; `user://settings.cfg` |
| SoundPlayer | `scripts/audio/sound_player.gd` | звуки по сигналам, музыка; пул из 6 голосов |

## Рост растений
* При посадке: `planted_at = now`, `ready_at = now + base × time_multiplier`,
  `yield = base × (1 + bonus)` — модификаторы берутся **в момент посадки**.
* Стадия: 4 равных отрезка роста (семя → прорастание → молодое → взрослое), «созревшее»
  только при `now ≥ ready_at`. Ничего не тикает — всё вычисляется по запросу.
* Сбор сначала очищает место, затем выдаёт урожай → повторный сбор невозможен.
* Дробная часть бонуса урожая копится по продукту (`yield_carry`).

## Сохранения
```
save.json   строка 1: {"format_version":2,"game_version":"0.3.0","saved_at":…,"checksum":"<sha256 строки 2>"}
            строка 2: {"time":{…},"progression":{…},"inventory":{…},"economy":{…},"farm":{…},"goals":{…}}
```
Запись: `save.tmp` → проверка чтением → `save.json` переименовывается в `save.bak` →
`save.tmp` → `save.json`. Загрузка: `save.json` → `save.tmp` → `save.bak` → новая игра.
Повреждённый основной файл сохраняется как `save.corrupt`.
История форматов: v0 — прототип (плоский словарь), v1 — 0.2.0, v2 — 0.3.0 (+ `goals`).
Настройки хранятся отдельно (`settings.cfg`) и не сбрасываются вместе с прогрессом.

## Лаборатория разработчика (`scripts/dev/dev_lab.gd`)
`enter()`: сохранить игру → снимок `SaveManager.build_save_data()` → `SaveManager.suspended`
→ часы `OffsetTimeSource` поверх текущего источника → песочница (своя FarmState из
`resources/rooms/dev_lab.tres`). `exit()`: вернуть источник времени и применить снимок.
Читы — статические функции `DevLab`, UI — `DevPanel`. Если приложение убить в лаборатории,
при запуске загрузится реальное сохранение, записанное в `enter()`.

## Звук
`SoundPlayer` — не autoload, а узел главной сцены: он только подписывается на сигналы
(`FarmState`, `EconomyManager`, `ProgressionManager`, `Hud`, `FarmRoom`) и на каждую кнопку
через `SceneTree.node_added`. Игровая логика о звуке не знает. Один и тот же звук не
перезапускается чаще чем раз в 70 мс (массовый сбор). Новая версия формата добавляется
шагом в `SaveManager._migrate()`.

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

## Планируемые модули (следующие этапы)

| Этап | Модуль | Связь |
|---|---|---|
| 2 «Умная гидропоника» | ветка «Технологии», автоматический сбор | `FarmState`, `ProgressionManager` |
| 3 «Теплица» | второй `RoomLayoutData`, переход между локациями, `SlotType.GREENHOUSE/SOIL` | `GameManager` хранит несколько FarmState |
| 4+ | рынок/спрос (`EconomyManager.get_sell_price`), контракты, переработка (`ProductData`) | — |

Все 6 запланированных Autoload реализованы. Новые добавляются только при реальной необходимости.

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
