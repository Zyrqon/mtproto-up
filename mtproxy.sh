#!/bin/bash
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CONTAINER_NAME="mtproto-proxy"
PORT="443"
FAKE_DOMAIN="ya.ru"

DOMAIN_HEX=$(echo -n $FAKE_DOMAIN | xxd -ps | tr -d '\n')

DOMAIN_LEN=${#DOMAIN_HEX}
NEEDED=$((30 - DOMAIN_LEN))
RANDOM_HEX=$(openssl rand -hex 15 | cut -c1-$NEEDED)

SECRET="ee${DOMAIN_HEX}${RANDOM_HEX}"

if ss -tuln | grep -q ":${PORT} "; then
    for alt_port in 8443 8444 8445; do
        if ! ss -tuln | grep -q ":${alt_port} "; then
            PORT=$alt_port
            break
        fi
    done
fi

sudo docker stop ${CONTAINER_NAME} >/dev/null 2>&1
sudo docker rm ${CONTAINER_NAME} >/dev/null 2>&1

sudo docker run -d \
  --name ${CONTAINER_NAME} \
  --restart unless-stopped \
  -p ${PORT}:443 \
  -e SECRET="${SECRET}" \
  telegrammessenger/proxy > /dev/null 2>&1

sleep 3

if sudo docker ps | grep -q ${CONTAINER_NAME}; then
    SERVER_IP=$(curl -s ifconfig.me)

    echo "🔗 Copy link and paste in telegram:"
    echo -e "${GREEN}tg://proxy?server=${SERVER_IP}&port=${PORT}&secret=${SECRET}${NC}"

    cat > ~/mtproto_config.txt << EOF
SERVER=${SERVER_IP}
PORT=${PORT}
SECRET=${SECRET}
DOMAIN=${FAKE_DOMAIN}
LINK=tg://proxy?server=${SERVER_IP}&port=${PORT}&secret=${SECRET}
EOF

    sudo docker logs --tail 5 ${CONTAINER_NAME}
else
    sudo docker logs ${CONTAINER_NAME}
fi
