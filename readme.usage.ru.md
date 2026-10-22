# Утилита doc-db: использование

## Как работает

Утилита doc-db - внешняя утилита: исполняющие скрипты лежат здесь, ваше описание базы данных - в вашем проекте.

Проектом считается ваш текущий каталог (или явно указанный `--root`), ваше описание базы данных нужно разместить в
`doc/db` (или явно указанном `--doc`). В вашем `doc/db` лежат три файла:

| Файл             | Что в нём                                                                                 | Кто правит                 |
|------------------|-------------------------------------------------------------------------------------------|----------------------------|
| `db-desc.yaml`   | Описания таблиц и колонок, диаграммы, ссылки на Java-классы констант                      | человек                    |
| `db-struct.yaml` | Физическая структура: таблицы, колонки, типы, обязательность, PK, FK, допустимые значения | генерирует `import-struct` |
| `db-consts.yaml` | Константы Java-классов из `constants_from` (нужен, только если они есть)                  | генерирует `import-consts` |

Ваше описание базы данных `db-desc.yaml` накладывается на `db-struct.yaml`, константы берутся из `db-consts.yaml`,
скрипт `gen-html` генерирует из них файл `_site/db.html` в текущем каталоге (или в явно указанном `-o`).

## Как подключить себе

Ваш проект подключает утилиту своим скриптом, например:

```bash
TOOL="${DOC_DB:-/home/user/projects/doc-db}"
cd "$ROOT"
"$TOOL/import-struct" --liquibase app-database/src/main/resources/db/changelog/db.changelog-master.xml -o doc/db/db-struct.yaml
"$TOOL/gen-html" -o _out/doc/db-doc.html
```

### Для запуска должно быть установлено

- Python 3 + `pip install pyyaml jinja2`
- `psql` - только если будете читать структуру реально БД командой `import-struct --db`
- Java - для диаграмм; PlantUML лежит в утилите: `lib/plantuml.jar`. Без него HTML генерируется без диаграмм.

### Шаги генерации документации

Из корня проекта:

```bash
# 1. Импортировать структура базы данных - из разных источников
import-struct --flyway backend/src/main/resources/db/migration
import-struct --liquibase path/to/db.changelog-master.xml
import-struct --db postgresql://user@localhost/dbname        # пароль - в PGPASSWORD или ~/.pgpass

# 2. Импортировать константы Java-классов - если в db-desc.yaml есть constants_from с классами
import-consts

# 3. Сгенерить HTML-документацию по базе данных
gen-html
```

### import-struct

Читает реальную структуру БД и запоминает ёё у себя.

- **Flyway** - SQL-файлы `V<версия>__*.sql` по возрастанию версии; можно несколько каталогов. Разбираются
  `CREATE TABLE`, `ALTER TABLE` (ADD/DROP/ALTER/RENAME COLUMN, ADD/DROP CONSTRAINT, RENAME TO), `DROP TABLE`.
  `INSERT`, `UPDATE`, индексы и прочее структуру не меняют и пропускаются.
- **Liquibase** - XML-changelog: `include` и `includeAll` по порядку; createTable, addColumn, dropColumn,
  renameColumn, renameTable, dropTable, modifyDataType, add/dropNotNullConstraint, add/dropPrimaryKey,
  add/dropForeignKeyConstraint; FK - и отдельной операцией, и в `<constraints>` колонки. Имена сверяются без
  учёта регистра (как у liquibase и PostgreSQL), в документации - написание из `createTable`.
- **Живая база** - каталог PostgreSQL через `psql`. Самый точный источник.

Что не удалось разобрать (неизвестная таблица, колонка, операция), пишется в stderr как `WARN ...`, а не
пропускается молча.

Служебные таблицы `flyway_schema_history`, `databasechangelog`, `databasechangeloglock` в структуру не попадают.
Типы приводятся к одному написанию: `varchar(50)`, `integer`, `bigint`, `numeric(6,2)`, `timestamptz`, `text[]`.
`values` - допустимые значения из `CHECK (col IN (...))`. Составные FK не показываются.

```yaml
tables:
  wagons:
    primary_key: [ id ]
    columns:
      id: { type: uuid, required: true }
      depot_id: { type: uuid, references: depots }
      status: { type: varchar(20), required: true, values: [ IN_SERVICE, IN_REPAIR, RESERVE, OUT_OF_SERVICE ] }
```

### import-consts

Собирает константы классов, указанных в `constants_from` в `db-desc.yaml` (у таблиц и колонок). Класс ищется по
FQN в каталогах исходников; из него берутся `public static final` константы с комментарием перед ними
(`/** ... */` или `//`). Класс не найден - ошибка, код выхода 1.

```yaml
classes:
  kz.example.Status:
    file: app/src/main/java/kz/example/Status.java
    constants:
      - { name: NEW, value: '1', description: 'Новая' }
```

### Формат описания структуры базы в db-desc.yaml

```yaml
title: "Название"
subtitle: "Подзаголовок"
diagrams:
  group_name:
    title: "Название диаграммы"
    description: "Пояснение"
    tables: [ Table1, Table2 ]
tables:
  TableName:
    title: "Краткое название"
    description: |
      Многострочное описание.
    constants_from: kz.example.Constants   # Java-класс с константами (необязательно)
    columns:
      column_name:
        title: "Краткое название"          # на диаграмме рядом с именем поля; нет - description
        description: "Описание поля"
        constants_from: kz.example.Status  # необязательно
      status:
        title: "Статус"
        constants_from: doc/dict/statuses.tsv  # или справочник .tsv
      other_column: "Краткая запись: строка вместо description"
```

`constants_from` - Java-класс (FQN) или файл `.tsv` (путь от корня проекта). Из `.tsv` берутся строки без
заголовка, первые три колонки - значение, название, пояснение; `import-consts` такие файлы пропускает, `gen-html` читает
их сам.

Порядок колонок в HTML - первичный ключ, затем как перечислены в `db-desc.yaml`, остальные - ссылки (FK) по алфавиту, затем
прочие по алфавиту.

### Проверка при генерации

`gen-html` до генерации проверяет, что в `db-desc.yaml` нет лишнего:

- **[extra table]** - таблицы нет в структуре (удалена или опечатка), в том числе в списке диаграммы;
- **[extra column]** - колонки нет в структуре;
- **[unknown key]** - ключ не из списка выше (например, `descripton`);
- **[no file]** - файла `.tsv` из `constants_from` нет;
- **[no constants]** - класса из `constants_from` нет в `db-consts.yaml`: файл устарел, перезапустите `import-consts`.

При ошибках HTML не генерируется, код выхода 1. Неописанные таблицы и колонки - не ошибка: `gen-html` только
печатает их число. С `--strict` и они ошибка, со списком:

- **[missing table]** - таблицы нет в `db-desc.yaml`;
- **[missing column]** - колонки нет в описании своей таблицы.

### Опции команд (скорее всего вам не нужны)

`--root DIR` (`import-consts`, `gen-html`) - корень проекта, если запуск не из него; от него ищутся `.tsv` из
`constants_from` и исходники Java. `--doc DIR` - каталог yaml-файлов, если не `doc/db`.

`gen-html -t FILE -o FILE -D NAME=VALUE` - другой шаблон, выходной файл и переменные шаблона (`-D` можно несколько).
Свой шаблон может расширять `template.html.j2` (`{% extends "template.html.j2" %}`) и переопределять блоки `style`,
`page` (вся страница), `toc` (содержание), `content` (диаграммы и таблицы) - например, чтобы встроить страницу в
общий сайт документации.

Язык подписей - `--lang XX` (сокращения `-en`, `-ru`), по умолчанию английский. Шаблон один, подписи берутся из
`lang/XX.yaml` в переменную `t` (`{{ t.tables }}`); ключи, которых нет в языке, - из `en.yaml`. Новый язык - ещё
один файл `lang/XX.yaml`. `--labels FILE` - свои подписи проекта поверх языковых. Свой шаблон тоже получает `t`.

Кэш диаграмм - `.plantuml-cache` в корне проекта (добавьте его в `.gitignore`). Для каждой диаграммы `gen-html` сначала строит её
текст PlantUML (таблицы, поля, связи); имя SVG в кэше - sha1 этого текста. Изменились структура или описания,
попавшие в диаграмму, - меняется текст, а с ним и имя: такого SVG нет, PlantUML запускается. Остальные диаграммы
берутся из кэша: повторная сборка - секунды вместо ~40 с. SVG, которые сборке не понадобились, удаляются. После обновления PlantUML кэш можно удалить целиком.

`import-struct -o FILE` - писать в другой файл; `--schema` - схема для `--db` (по умолчанию `public`).
`import-consts --src DIR ...` - каталоги исходников Java (по умолчанию `*/src/main/java` модулей проекта); `-o FILE`.

