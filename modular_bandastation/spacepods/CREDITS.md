# Источники подов и челнок-инженера

Основа порта — [ss220-space/Paradise](https://github.com/ss220-space/Paradise/tree/38015e8f1ad32d0812874a7b06090d7d09a5888c),
коммит `38015e8f1ad32d0812874a7b06090d7d09a5888c`.
Авторы исходного кода и ресурсов — участники Goonstation, ParadiseSS13/Paradise и
ss220-space/Paradise. Индивидуальные вклады доступны в истории исходных файлов;
ссылки на зафиксированные версии приведены в [ASSETS.json](ASSETS.json).

Код подов, их оборудования, деталей и сборки, роль из `code/game/jobs/job/science.dm`,
исследования из `code/modules/research/designs/spacepod_designs.dm` и консоль из
`code/game/machinery/computer/pod_tracking_console.dm` перенесены с адаптацией под
native API tg/BandaStation: транспорт, атмосфера, взаимодействия, действия,
исследования, профессии и переводы. Лицензия исходного кода — **AGPL-3.0**;
полный исходный текст сохранён в [LICENSE-CODE.txt](LICENSE-CODE.txt).

Непрерывная физика полёта в `code/spacepod_flight.dm` адаптирована из
[ветки spacepods MrRomainzZ/Paradise-SS220-R](https://github.com/MrRomainzZ/Paradise-SS220-R/tree/e83c7f88dddbc5f5c7988b3601cb39265198342f),
коммит `e83c7f88dddbc5f5c7988b3601cb39265198342f`, файлы
`code/modules/spacepods/spacepod_physics.dm` и `spacepods.dm`.
Исходная реализация — Yogstation; адаптация для Paradise и разделение файлов —
MrRomainzZ. На код распространяется AGPL-3.0 согласно README исходного репозитория.
Ресурсы из этой ветки не копировались.

Графика скопирована побайтово. Исходные лицензии сохранены согласно
[README донора](https://github.com/ss220-space/Paradise/blob/38015e8f1ad32d0812874a7b06090d7d09a5888c/README.md#license).

| Файл модуля | Исходный путь в Paradise | Лицензия |
| --- | --- | --- |
| `icons/locator.dmi` | `icons/spacepods_paradise/locator.dmi` | CC-BY-SA-3.0 |
| `icons/spacepod.dmi` | `icons/obj/spacepod.dmi` | CC-BY-SA-3.0 |
| `icons/pods.dmi` | `icons/goonstation/48x48/pods.dmi` | CC-BY-NC-SA-3.0 |
| `icons/pod_construction.dmi` | `icons/goonstation/48x48/pod_construction.dmi` | CC-BY-NC-SA-3.0 |
| `icons/pod_parts.dmi` | `icons/goonstation/pods/pod_parts.dmi` | CC-BY-NC-SA-3.0 |
| `icons/ship.dmi` | `icons/goonstation/pods/ship.dmi` | CC-BY-NC-SA-3.0 |

Полные тексты лицензий ресурсов:
[CC-BY-SA-3.0](LICENSE-ASSETS-CC-BY-SA-3.0.txt) и
[CC-BY-NC-SA-3.0](LICENSE-ASSETS-CC-BY-NC-SA-3.0.txt).
Для четырёх ресурсов Goonstation сохраняется условие NonCommercial.

[ASSETS.json](ASSETS.json) содержит исходные permalink, Git blob ID и SHA-256
оригиналов и копий всех шести DMI. Совпадение хэшей подтверждает отсутствие
изменений пикселей, состояний, кадров и метаданных анимации. Использованные звуки
и остальные существующие ресурсы PrimeDream сохраняют свои исходные лицензии.

Русские предупреждения `sound/alerts/*.ogg` синтезированы локально из оригинальных
фраз. Голос, параметры обработки и тексты записаны в [sound/alerts/README.md](sound/alerts/README.md).

SVG-схема и оформление `SpacepodStatus` созданы для этой адаптации. Растровый
референс интерфейса используется как ориентир стиля и в ресурсы сборки не включён.

`docs/status-monitor.png` показывает настоящий компонент `SpacepodStatus` на
демонстрационных данных. `docs/local-pods.png` — снимок локального стенда,
предоставленный автором сборки; изображённые поды используют ресурсы из таблицы выше.
