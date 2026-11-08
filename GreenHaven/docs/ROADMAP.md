# Roadmap

Легенда: ✅ готово и проверено · 🟡 частично · ⬜ не начато

## PHASE 0 — Project Setup ✅
- ✅ Проект Godot 4.5 (Compatibility renderer), структура каталогов
- ✅ Настройки Android: ландшафт (sensor), базовое разрешение 640×360, pixel-perfect
- ✅ `export_presets.cfg` (Android, arm64-v8a + armeabi-v7a)
- 🟡 Android-сборка: шаблоны экспорта и Android SDK в среде разработки отсутствуют — APK не собирался
- ✅ Документация (GDD, ARCHITECTURE, ROADMAP, CHANGELOG, TESTING, ASSET_GUIDE, ECONOMY)
- ✅ Автотесты (headless runner) и проверка запуска
- ✅ Autoload: GameManager, TimeManager

## PHASE 1 — Isometric World ✅
- ✅ Изометрическая комната из данных (`RoomLayoutData`): TileMapLayer пола, стены, окно, постер
- ✅ Временная pixel-art графика в едином стиле (генератор)
- ✅ Камера: pan, инерция, pinch/колесо, границы, pixel-perfect zoom, кнопки +/−/центр
- ✅ Сенсорное управление: tap / long press / drag / pinch, мышь для десктопа
- ✅ Интерактивные объекты: выбор, инфо-панель, перемещение по сетке с проверкой занятости
- ✅ Сортировка по глубине (Y-sort), анимации выбора/установки, свет из окна
- ⬜ Перемещённые объекты не сохраняются между запусками (→ PHASE 6, сериализация уже есть)

## PHASE 2 — Farming ⬜
- ⬜ `PlantData` + 8 культур (.tres), 5 стадий со спрайтами
- ⬜ `PlantInstance`, посадочные места стеллажа, посадка/рост/сбор/повторная посадка

## PHASE 3 — Real Time 🟡
- ✅ `TimeManager`: источник времени, защита от отката часов и некорректных меток, clamp
- ⬜ Офлайн-расчёт роста при запуске, модификаторы ускорения с лимитом

## PHASE 4 — Economy ⬜
- ⬜ EconomyManager, InventoryManager, магазин семян и оборудования, продажа

## PHASE 5 — Progression ⬜
- ⬜ ProgressionManager: опыт, уровни, ветки «Агрономия» и «Торговля», открытия культур

## PHASE 6 — Save System ⬜
- ⬜ SaveManager: JSON, версии/миграции, атомарная запись, бэкап, автосохранение

## PHASE 7 — Polish ⬜
- ⬜ Финальная графика, пиксельный шрифт, звук, анимации растений

## PHASE 8 — Release Build ⬜
- ⬜ Подписанный AAB/APK, профилирование на устройстве, релизная документация

## Известные проблемы и ограничения

1. Android APK не собран: в среде разработки нет export templates и Android SDK.
   Нужно: Godot 4.5 → Editor → Manage Export Templates; указать Android SDK и debug keystore.
2. Проверка выполнялась на Godot 4.8-dev (собран из исходников), а не на 4.5 stable.
   Перед релизом — прогнать тесты на 4.5 stable.
3. Расстановка объектов не сохраняется между запусками (SaveManager — PHASE 6).
4. Шрифт — встроенный (не пиксельный); вся графика — временная (`assets/placeholder/`).
5. Мультитач и жизненный цикл приложения проверены только синтетическими тестами.
