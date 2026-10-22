# DECISIONS — самостоятельные решения сборки v0

## D-001. Нет Xcode 26 на машине сборки
На машине сборки только Xcode 16.4 (iOS 18.5 SDK, рантайм iOS 18.6); симулятора iPhone 17 Pro нет. Промпт требует задать вопрос, но владелец машины ушёл и попросил работать без вопросов. Решение:
- проект настроен под **Xcode 26.3 / iOS 26.0** (`IPHONEOS_DEPLOYMENT_TARGET = 26.0` в `Config/Shared.xcconfig`);
- строка `IPHONEOS_DEPLOYMENT_TARGET[sdk=iphonesimulator18*] = 18.0` срабатывает только на SDK iOS 18 и позволила собрать и проверить v0 на iOS 18.6; в Xcode 26 она ничего не делает (её можно удалить);
- код использует только API, доступные в iOS 18.0, без `#available`, чтобы при target 26.0 не было предупреждений «unnecessary check»; избегаются API, устаревшие в iOS 26 (например, `Text + Text`);
- симулятор — «SuperPooper Test» на iPhone 16 Pro / iOS 18.6;
- **не проверено вживую:** сборка именно в Xcode 26.3 (Swift 6.2, iOS 26 SDK), внешний вид Liquid Glass. Риск — новые предупреждения SDK 26; чинятся точечно.

## D-002. Проект без XcodeGen
`.xcodeproj` написан вручную в формате Xcode 16 (objectVersion 77) с синхронизируемыми папками (`PBXFileSystemSynchronizedRootGroup`). Новый файл в папке автоматически попадает в нужные таргеты, `project.pbxproj` править не нужно. Xcode 26.3 этот формат открывает. На машину ничего не ставилось.

Членство папок в таргетах:
- приложение: `App`, `Features`, `Data`, `Debug`, `AppResources` + общие;
- виджеты: `Widgets` + общие;
- общие (приложение и виджеты): `Domain`, `Core`, `DesignSystem`, `Resources`;
- тесты: `Tests` (`@testable import SuperPooper`).

## D-003. Swift 5 language mode, минимальная проверка concurrency
Чтобы один и тот же код без ошибок собирался и в Swift 6.1 (Xcode 16.4), и в Swift 6.2 (Xcode 26.3) с другими аннотациями SDK. Переход на Swift 6 mode — задача v1.

## D-004. Git
Репозиторий локальный. `master` — первый коммит с исходными материалами; работа идёт в ветке `build-v0`, в конце она вливается в `master` (`--no-ff`) и ставится тег `v0`.
