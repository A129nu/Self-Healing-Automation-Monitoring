#!/bin/bash

echo "======================================"
echo "Nginx Health Check"
echo "======================================"

HEALTHY=true

echo ""
echo "[1] Checking Nginx service..."

if systemctl is-active --quiet nginx; then
    echo "PASS: Nginx service is active."
else
    echo "FAIL: Nginx service is not active."
    HEALTHY=false
fi

echo ""
echo "[2] Checking port 80..."

if ss -lnt | grep -q ':80 '; then
    echo "PASS: Port 80 is listening."
else
    echo "FAIL: Port 80 is not listening."
    HEALTHY=false
fi

echo ""
echo "[3] Checking HTTP response..."

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}"     --max-time 10     http://127.0.0.1/)

if [ "$HTTP_CODE" = "200" ]; then
    echo "PASS: HTTP response is 200."
else
    echo "FAIL: HTTP response is $HTTP_CODE."
    HEALTHY=false
fi

echo ""
echo "======================================"

if [ "$HEALTHY" = true ]; then
    echo "RESULT: HEALTHY"
    echo "======================================"
    exit 0
else
    echo "RESULT: UNHEALTHY"
    echo "======================================"
    exit 1
fi
