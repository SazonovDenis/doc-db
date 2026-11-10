#!/usr/bin/env bash
# Сборка примера: sample/_site/db.html
set -e
cd "$(dirname "$0")"
TOOL=..
"$TOOL/import-struct" --flyway db/migration
# исходники Java примера - в src, а не в */src/main/java
"$TOOL/import-consts" --src src
"$TOOL/gen-html" -ru --strict
