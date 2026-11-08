# Green Haven

Уютный изометрический симулятор агрохозяйства для Android (Godot 4.5+, GDScript).

* Концепция: [docs/GDD.md](docs/GDD.md)
* Архитектура: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
* План: [docs/ROADMAP.md](docs/ROADMAP.md)

## Запуск

1. Установите Godot **4.5 stable** (или новее 4.x).
2. Откройте `GreenHaven/project.godot` в редакторе → F5.

Из командной строки:

```bash
godot --path GreenHaven                       # запустить игру
godot --headless --path GreenHaven --import   # импорт ассетов (первый запуск)
godot --headless --path GreenHaven -s res://tests/run_tests.gd   # тесты
```

## Управление

| Действие | Сенсор | Мышь |
|---|---|---|
| Перемещение камеры | палец + движение | ПКМ/СКМ + движение, или ЛКМ по пустому месту |
| Масштаб | два пальца (pinch) | колесо |
| Выбор объекта | касание | ЛКМ |
| Перемещение объекта | удержание + движение, или кнопка «Переместить» | удержание ЛКМ + движение |
| Назад / закрыть | системная кнопка «Назад» | Esc |

## Временная графика

Всё в `assets/placeholder/` сгенерировано скриптом `tools/generate_placeholder_art.py`
(Python 3 + Pillow) и будет заменено финальной графикой в `assets/sprites/`.
