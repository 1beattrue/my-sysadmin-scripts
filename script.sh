#!/bin/bash
# Использование: ./script.sh [путь_к_логу]   (по умолчанию /var/log/syslog)
LOGFILE="${1:-/var/log/syslog}"

if [ ! -f "$LOGFILE" ]; then
    echo "Ошибка: файл $LOGFILE не найден" >&2
    exit 1
fi

if [ ! -r "$LOGFILE" ]; then
    echo "Ошибка: нет прав на чтение $LOGFILE" >&2
    exit 1
fi

grep -aiE "error|fail" "$LOGFILE" > report.txt
echo "Готово: строк в report.txt: $(wc -l < report.txt)"
