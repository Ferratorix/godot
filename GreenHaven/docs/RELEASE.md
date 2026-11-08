# Сборка и выпуск (PHASE 8)

## 1. Автоматическая сборка APK (GitHub Actions)

Файл: `.github/workflows/green_haven.yml` в корне репозитория.

Запускается при каждом push, который меняет `GreenHaven/**`, или вручную
(Actions → «🌱 Green Haven» → Run workflow; ручной запуск доступен для workflow в ветке по умолчанию).

Что делает:
1. Скачивает официальный **Godot 4.5.1 stable** (Linux).
2. Импортирует проект и запускает все автотесты (`tests/run_tests.gd`) — сборка падает при ошибке.
3. Ставит Java 17, Android SDK (build-tools 35, platform 35) и Android-шаблоны экспорта.
4. Создаёт debug-ключ и экспортирует **debug APK**.
5. Если настроены секреты подписи — дополнительно **release APK**.
6. Публикует APK как артефакт `GreenHaven-android` (хранится 14 дней):
   страница запуска → раздел Artifacts → скачать zip → `GreenHaven-debug.apk`.

### Секреты для release-подписи (Settings → Secrets and variables → Actions)

| Секрет | Значение |
|---|---|
| `ANDROID_RELEASE_KEYSTORE_BASE64` | `base64 -w0 release.keystore` |
| `ANDROID_RELEASE_KEYSTORE_USER` | alias ключа |
| `ANDROID_RELEASE_KEYSTORE_PASSWORD` | пароль |

Создание ключа (один раз, хранить в надёжном месте — без него нельзя выпускать обновления):
```bash
keytool -genkeypair -v -keystore release.keystore -alias greenhaven \
  -keyalg RSA -keysize 2048 -validity 10000
```
**Никогда не коммитьте keystore** (`*.keystore`, `*.jks` в `.gitignore`).

## 2. Локальная сборка

1. Godot 4.5.1 → Editor → Manage Export Templates → Download and Install.
2. Editor Settings → Export → Android: путь к Android SDK, Java SDK (17), debug keystore
   (Godot может создать его сам).
3. Project → Export → Android → Export Project (APK) или «Remote Debug» для запуска на
   подключённом по USB телефоне.

Из командной строки:
```bash
godot --headless --path GreenHaven --export-debug Android build/GreenHaven-debug.apk
adb install -r GreenHaven/build/GreenHaven-debug.apk
```

## 3. Google Play

* Для Play Store нужен **AAB**: в пресете Android включить `gradle_build/use_gradle_build`
  и `gradle_build/export_format = AAB`, установить Android Build Template
  (Project → Install Android Build Template). Целевой API — актуальный требованиям Play.
* Политика конфиденциальности: [PRIVACY_POLICY.md](PRIVACY_POLICY.md) (разместить по публичному URL).
* Перед каждым обновлением увеличивать `version/code` в `export_presets.cfg`;
  `package/unique_name` (`com.greenhaven.game`) **не менять никогда** — иначе это будет
  другое приложение, и сохранения игроков не перенесутся.

## 4. Чек-лист проверки на устройстве

Отмечать результат в [TESTING.md](TESTING.md).

**Запуск и экран**
- [ ] Установка APK, иконка (адаптивная) выглядит корректно в лаунчере
- [ ] Старт в ландшафте; поворот на 180° работает (sensor landscape)
- [ ] Нет вырезов/наложения на «чёлку» и системные панели (immersive mode)
- [ ] Пиксели чёткие на 2–3 разных разрешениях (16:9, 20:9, планшет)

**Управление**
- [ ] Касание выбирает объект, удержание — перенос, pinch — масштаб, свайп — камера с инерцией
- [ ] Кнопки не срабатывают «сквозь» панели; прокрутка списков пальцем
- [ ] Системная кнопка/жест «Назад»: закрывает окно → снимает выбор → выход
- [ ] Вибрация при начале переноса

**Время и сохранения**
- [ ] Посадить микрозелень, свернуть на 6 мин, вернуться: «Пока вас не было…», урожай готов
- [ ] Полностью закрыть приложение (смахнуть), открыть: прогресс на месте
- [ ] Перезагрузить телефон: прогресс на месте
- [ ] Перевести часы на день назад: растения не «откатываются», повторного сбора нет
- [ ] Режим полёта: игра работает полностью
- [ ] Установить новую сборку поверх старой (`adb install -r`): сохранение не потеряно

**Звук и настройки**
- [ ] Звук и музыка слышны, громкость регулируется, после сворачивания звук останавливается
- [ ] Смена языка RU/EN на лету
- [ ] Экономия батареи: 30 FPS, плавность приемлема

**Производительность** (Android Studio Profiler или `adb shell dumpsys gfxinfo`)
- [ ] Стабильные 60 FPS на среднем устройстве при полной ферме
- [ ] Память < 200 МБ, нет роста за 15 минут игры
- [ ] Нагрев/расход батареи за 15 минут — в норме

## 5. Измерения на ПК (`tools/benchmark.gd`)

```bash
xvfb-run -a godot --path GreenHaven -s res://tools/benchmark.gd -- seconds=10 mode=max
```

Результаты 2026-11-08, программный рендер llvmpipe (без GPU — заведомо хуже телефона):

| Сценарий | Стеллажи / растения | Кадр (ср. / p95) | Draw calls | Узлы | Память | Сохранение |
|---|---|---|---|---|---|---|
| `max` — максимум этапа 1 | 13 / 57 | 16,7 / 16,8 мс (60 FPS) | 145 | 298 | 40 МБ | 3 мс, 10,6 КБ |
| `stress` — ×4 сверх лимита | 52 / 309 | 29 / 34 мс (34 FPS) | 514 | 700 | 44 МБ | 9 мс, 43 КБ |

Резерв для оптимизации (если понадобится на слабых устройствах): объединить ленты
стадий растений в один атлас (меньше переключений текстур), заменить полупрозрачную
подсветку LED на вариант спрайта стеллажа, отключить шейдер покачивания в режиме экономии.
