#!/usr/bin/env bash
# Сборка примера: sample/_site/db.html
set -e
cd "$(dirname "$0")"
TOOL=..
"$TOOL/import-struct" --flyway db/migration
"$TOOL/gen-html" -ru --strict
