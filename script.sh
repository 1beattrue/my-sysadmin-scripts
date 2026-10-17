#!/bin/bash
# Использование: ./script.sh [путь_к_логу]   (по умолчанию /var/log/syslog)
LOGFILE="${1:-/var/log/syslog}"
PATTERN="error|fail"

if [ ! -f "$LOGFILE" ]; then
    echo "Ошибка: файл $LOGFILE не найден" >&2
    exit 1
fi

if [ ! -r "$LOGFILE" ]; then
    echo "Ошибка: нет прав на чтение $LOGFILE" >&2
    exit 1
fi

TOTAL=$(grep -aciE "$PATTERN" "$LOGFILE")
ERRORS=$(grep -aci "error" "$LOGFILE")
FAILS=$(grep -aci "fail" "$LOGFILE")

{
    echo "Отчёт сборщика логов"
    echo "Дата:      $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Хост:      $(hostname)"
    echo "Источник:  $LOGFILE"
    echo "Фильтр:    $PATTERN (без учёта регистра)"
    echo "Найдено:   $TOTAL строк (error: $ERRORS, fail: $FAILS)"
    echo "----------------------------------------"
    if [ "$TOTAL" -gt 0 ]; then
        grep -aiE "$PATTERN" "$LOGFILE"
    else
        echo "(совпадений нет)"
    fi
} > report.txt

echo "Готово: найдено строк: $TOTAL → report.txt"
