# Сборщик логов

Отбирает из `/var/log/syslog` строки с `error`/`fail` (без учёта регистра) в `report.txt`.

```bash
./script.sh                     # /var/log/syslog
./script.sh /var/log/auth.log   # другой лог
```

Код возврата 1 — лог не найден или не читается (сообщение в stderr).
`sample_output.txt` — первые 5 строк отчёта.
