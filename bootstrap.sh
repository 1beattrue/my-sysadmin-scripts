#!/usr/bin/env bash
# Поднимает весь стенд с нуля на Ubuntu 22.04: образ, RAID 1 + LVM, nginx/TLS, systemd.
# Повторный запуск безопасен: существующие диски RAID/LVM не пересоздаются, а собираются заново.
set -e   # без pipefail: `yes | mdadm` иначе завершит скрипт кодом 141 (SIGPIPE у yes)

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"
LAB=/mnt/raid-lab

echo "== 0. Пакеты =="
sudo apt-get update -qq
if ! command -v docker > /dev/null; then   # на Killercoda уже стоит docker-ce, docker.io с ним конфликтует
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        docker.io docker-compose-v2 docker-buildx > /dev/null
fi
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq nginx openssl curl > /dev/null
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
    mdadm lvm2 > /dev/null
DOCKER=docker
docker info > /dev/null 2>&1 || DOCKER="sudo docker"

echo "== 1. Образ и контейнер =="
sudo systemctl stop my-app 2>/dev/null || true
$DOCKER build -q --provenance=false -t my-script .
$DOCKER rm -f my-app > /dev/null 2>&1 || true
$DOCKER create -p 8080:8080 --name my-app -v /var/log:/var/log:ro my-script

echo "== 2. RAID 1 + LVM на loop-устройствах =="
if grep -q "^md0" /proc/mdstat; then
    echo "   RAID уже собран — пропуск"
elif [ -f "$LAB/disk1.img" ]; then
    echo "   Образы дисков найдены (например, после перезагрузки) — сборка без пересоздания"
    LOOP1=$(sudo losetup -fP --show "$LAB/disk1.img")
    LOOP2=$(sudo losetup -fP --show "$LAB/disk2.img")
    LOOP3=$(sudo losetup -fP --show "$LAB/disk3.img")
    sudo mdadm --assemble /dev/md0 "$LOOP1" "$LOOP2" || true   # ядро могло собрать само
    sudo vgchange -ay vg_data
else
    sudo mkdir -p "$LAB"
    for i in 1 2 3; do sudo dd if=/dev/zero of="$LAB/disk$i.img" bs=1M count=512 status=none; done
    LOOP1=$(sudo losetup -fP --show "$LAB/disk1.img")
    LOOP2=$(sudo losetup -fP --show "$LAB/disk2.img")
    LOOP3=$(sudo losetup -fP --show "$LAB/disk3.img")
    yes | sudo mdadm --create /dev/md0 --level=1 --raid-devices=2 "$LOOP1" "$LOOP2"
    sudo mkfs.ext4 -q -F /dev/md0
    sudo pvcreate "$LOOP3"
    sudo vgcreate vg_data "$LOOP3"
    sudo lvcreate -L 200M -n lv_logs vg_data
    sudo mkfs.ext4 -q -F /dev/vg_data/lv_logs
fi
sudo mkdir -p /mnt/raid /mnt/logs
mountpoint -q /mnt/raid || sudo mount /dev/md0 /mnt/raid
mountpoint -q /mnt/logs || sudo mount /dev/vg_data/lv_logs /mnt/logs

echo "== 3. Nginx и TLS =="
if [ ! -f /etc/ssl/certs/my-app.crt ]; then
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/my-app.key \
        -out /etc/ssl/certs/my-app.crt \
        -subj "/CN=my-app.local" 2> /dev/null
fi
sudo cp nginx/my-app.conf /etc/nginx/sites-available/my-app
sudo ln -sf /etc/nginx/sites-available/my-app /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl enable --now nginx
sudo systemctl reload nginx

echo "== 4. systemd-служба =="
sudo cp systemd/my-app.service /etc/systemd/system/my-app.service
sudo systemctl daemon-reload
sudo systemctl enable my-app
sudo systemctl start my-app

echo "== 5. Самопроверка =="
printf "Ожидание готовности сервиса"
READY=no
for i in $(seq 1 15); do
    if curl -ksf -o /dev/null https://127.0.0.1/report.txt; then READY=yes; break; fi
    printf "."
    sleep 2
done
echo
if [ "$READY" = yes ]; then
    curl -ksI https://127.0.0.1/report.txt | head -1
else
    echo "ВНИМАНИЕ: сервис не ответил за 30 секунд. Смотрите: sudo systemctl status my-app; sudo journalctl -u my-app"
fi
cat /proc/mdstat
df -h /mnt/raid /mnt/logs
systemctl is-enabled my-app
systemctl is-active my-app
echo "bootstrap.sh: готово"
