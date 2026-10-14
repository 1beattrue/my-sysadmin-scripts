# Сборщик логов

Отбирает из `/var/log/syslog` строки с `error`/`fail` (без учёта регистра) в `report.txt`.

```bash
./script.sh                     # /var/log/syslog
./script.sh /var/log/auth.log   # другой лог
```

Код возврата 1 — лог не найден или не читается (сообщение в stderr).
`sample_output.txt` — первые 5 строк отчёта.

## Docker

```bash
docker build -t my-script .
docker run --rm -v /var/log:/var/log:ro my-script   # без тома лог хоста не виден
docker compose up --build -d                        # отчёт: http://localhost:8080/report.txt
```
