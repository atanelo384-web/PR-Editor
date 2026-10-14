# PR — iPhone Photo + Video Editor

**Язык:** Swift / SwiftUI. **Цель:** iOS 17+ (только iPhone).  
**Дизайн:** тёмный минимализм в духе редакторов 2011 года; собственные векторные Aero-кнопки на SwiftUI.  
**Значок приложения:** предоставленная пользователем глянцевая иконка PR.

## Функции версии 1.0

| Редактор фото | Редактор видео |
|---|---|
| Импорт из «Фото» и «Файлы» | Импорт из «Фото» и «Файлы» |
| Экспозиция, контраст, насыщенность | Встроенный просмотр и воспроизведение |
| Фильтры моно / плёнка / хром | Обрезка начала и конца клипа по времени |
| Поворот, отражение, пропорции 1:1, 4:5, 16:9 | Регулировка громкости итоговой дорожки |
| Простая текстовая надпись | Экспорт отрезка в MP4 |
| Отмена / повтор и полный сброс | Отображение диапазона таймлайна |
| Экспорт JPEG в полном разрешении | Поделиться полученным файлом |

Экспорты автоматически сохраняются в `Documents/Exports`, доступны через панель истории и системное меню «Поделиться». Фотография при редактировании не перезаписывается. Для предпросмотра создаётся уменьшенная копия, для JPEG рендерятся исходные пиксели.

**Границы функционала:** пока нет нескольких видео-/аудиодорожек, масок, кистей, стикеров, переходов, кривых, покадровой графики и свободной рамки кадрирования. Пропорциональная обрезка фото выполняется **по центру**. Это работающий базовый редактор, не полноценная замена Photoshop или CapCut. Отсутствуют облачные сервисы и реклама.

## Проект для macOS + Xcode

1. Установите Xcode и [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`.
2. Выполните в корне: `xcodegen generate --spec project.yml`.
3. Откройте `PR.xcodeproj`, выберите схему **PR** и iPhone/simulator.
4. Для запуска на своём iPhone выберите **Signing & Capabilities → Team**, при необходимости измените `PRODUCT_BUNDLE_IDENTIFIER`.
5. Нажмите **Run**. Для распространения IPA потребуется Apple Developer distribution signing и соответствующий профиль.

**Почему в архиве исходники, а не установленный IPA:** iOS требует сборку Xcode на macOS. Установочный IPA также требует подходящей подписи и provisioning profile. Linux/Windows не заменяют эти требования.

## GitHub Actions — сборка без Mac у вас

1. Создайте GitHub-репозиторий. Загрузите **содержимое** папки `PR-iPhone` в корень репозитория вместе с `.github/workflows/build-ios.yml` (скрытую папку тоже).
2. Откройте **Actions → Build PR for iPhone → Run workflow**. При push в `main` или `master` сборка запускается автоматически.
3. GitHub выдаст `PR-unsigned-not-installable`: `.ipa` **БЕЗ ПОДПИСИ**, а также `.app` в ZIP. Такой IPA нельзя просто установить на обычный iPhone. Это заготовка для последующей подписи.
4. Для **устанавливаемого IPA** задайте в GitHub: **Settings → Secrets and variables → Actions → Secrets → New repository secret**:

| Secret | Что вставить |
|---|---|
| `IOS_SIGNING_CERT_BASE64` | Base64 от вашего Apple Distribution сертификата `.p12` |
| `IOS_CERT_PASSWORD` | Пароль к `.p12` |
| `IOS_PROVISIONING_PROFILE_BASE64` | Base64 от `.mobileprovision` (App ID `io.prstudio.editor`) |
| `IOS_TEAM_ID` | Apple Developer Team ID |

На Windows кодировать файл можно через PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\path\to\distribution.p12'))
[Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\path\to\PR.mobileprovision'))
```

В профиле регистрации устройства (Ad Hoc) UDID вашего iPhone должен присутствовать, иначе установка будет отклонена. Профиль и сертификат должны принадлежать одной команде, а App ID должен совпадать с `io.prstudio.editor` (можно заменить в `project.yml` и workflow одновременно).

По умолчанию export method — `ad-hoc`. Если нужен другой тип, создайте GitHub **Actions variable** `IOS_EXPORT_METHOD` со значением `app-store-connect` или `development` (и предоставьте профиль и сертификат соответствующего типа; для development может потребоваться поменять `CODE_SIGN_IDENTITY`). Итоговый подписанный артефакт: `PR-signed-iPhone-IPA`.

> **Без действительных Apple signing-данных GitHub не создаст устанавливаемый IPA**. Для публикации в App Store необходимы отдельные шаги App Store Connect и соблюдение требований Apple.

## Структура

```text
PR-iPhone/
├── .github/workflows/build-ios.yml   # Mac runner, unsigned + signed IPA
├── project.yml                       # Генерация Xcode-проекта
├── PR/
│   ├── PRApp.swift
│   ├── Models/                      # Состояние фото, проект, импорт видео
│   ├── Engine/                      # Core Image, AVFoundation
│   ├── UI/                          # Тёмный UI и Aero-кнопки
│   └── Assets.xcassets/AppIcon.appiconset/   # Ваша иконка
└── README.md
```

## Примечания

- Работа с фото выполняется через системный PhotosPicker без необходимости полного доступа к медиатеке.
- Видео для редактирования копируется во временный каталог приложения. Важно оставить достаточно свободного места.
- Поддержка кодеков и возможности экспортирования зависят от AVFoundation и исходного файла.
- Swift синтаксически проверен инструментом Swift compiler parser на Linux, но компиляцию для iOS и реальную установку необходимо выполнить на macOS/GitHub Actions.
