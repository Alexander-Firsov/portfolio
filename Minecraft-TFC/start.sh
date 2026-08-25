#!/bin/bash
set -e

# Имя игрока по умолчанию
PLAYER_NAME="${1:-Remuru}"
PLAY_TIME_MIN="${2:-60}"

# Настройка X11
sudo xhost +local:docker >/dev/null 2>&1

# Запуск контейнеров
cd ~/project/tfc
sudo docker compose up -d

# Запуск сервера в фоне
sudo docker compose exec -d tfc_server /app/run.sh

sleep 60
# Ожидание инициализации сервера по файлу логов
while true; do
    if [ -f "server_data/logs/latest.log" ]; then
        # Удаляем анси-коды и проверяем
        if sed 's/\x1b\[[0-9;]*m//g' server_data/logs/latest.log | grep -q "Sending reload packet to clients" && \
           sed 's/\x1b\[[0-9;]*m//g' server_data/logs/latest.log | grep -q "Mixing common.MixinServerStatus"; then
            break
        fi
    fi
    sleep 10
    echo -n '*'
done
echo

echo "Запуск клиента для $PLAYER_NAME..."
sudo docker compose exec -d tfc_client /app/launcher.sh "$PLAYER_NAME"

echo "Таймер запущен на $PLAY_TIME_MIN минут."

sleep $(( (PLAY_TIME_MIN + 1) * 60 )) # Спим основное время (минус 1 минута + 2 минуты на поднятие клиента)

# Звуковое предупреждение (через системный динамик или aplay)
echo -e "\a" # Системный сигнал (beep)
echo "ВНИМАНИЕ: До выхода осталась 1 минута!"
# aplay /usr/share/sounds/alsa/Front_Center.wav > /dev/null 2>&1
cvlc --play-and-exit $(ls sounds/*.mp3 | shuf -n 1) > /dev/null 2>&1

sleep 60 # Ждем последнюю минуту

# Программное завершение клиента
echo "Время вышло. Закрываем клиент..."
# Ищем процесс java внутри контейнера клиента и посылаем SIGTERM (мягкое завершение)
sudo docker exec tfc_client pkill -15 java || echo "Клиент уже был закрыт."

echo "Остановка сервера..."
sudo docker exec -i tfc_server sh -c 'echo stop > /proc/1/fd/0'

# Ожидание остановки и очистка
sleep 2
sudo docker compose down
