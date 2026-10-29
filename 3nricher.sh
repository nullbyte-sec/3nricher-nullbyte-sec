#!/usr/bin/env bash
# 3nricher - one-command setup + launch. Usage: ./3nricher.sh
set -e

BACKEND="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUI="$(dirname "$BACKEND")/3nricher-gui"
PORT=5001
URL="http://localhost:5173"

need() {
  command -v "$1" >/dev/null 2>&1 || { echo "[3nricher] Missing required tool: $1 ($2)"; exit 1; }
}
need git "install git"
need python3 "install python3"
need npm "install nodejs and npm"
need docker "install Docker; the enrichment runs in a container"
need make "install make"

cd "$BACKEND"
if [ ! -d venv ]; then
  echo "[3nricher] Creating Python venv..."
  python3 -m venv venv
fi
source venv/bin/activate
echo "[3nricher] Installing backend dependencies..."
pip install -q -r requirements.txt flask flask-cors

if [ ! -f .env ]; then
  cp .env.example .env
  echo "[3nricher] Created .env from template."
  echo "[3nricher] Add your API keys with: nano $BACKEND/.env"
  echo "[3nricher] Then run ./3nricher.sh again."
  exit 0
fi

if [ ! -d "$GUI" ]; then
  echo "[3nricher] Cloning web GUI..."
  git clone https://github.com/nullbyte-sec/3nricher-gui.git "$GUI"
fi
cd "$GUI"
if [ ! -d node_modules ]; then
  echo "[3nricher] Installing GUI dependencies (first run only)..."
  npm install --legacy-peer-deps
fi

fuser -k ${PORT}/tcp 2>/dev/null || true
pkill -f "vite" 2>/dev/null || true
sleep 1

echo "[3nricher] Starting backend on :${PORT}..."
cd "$BACKEND"
python3 server.py > /tmp/3nricher-backend.log 2>&1 &
BACKEND_PID=$!
echo -n "[3nricher] Waiting for backend"
for i in $(seq 1 30); do
  curl -s -o /dev/null "http://127.0.0.1:${PORT}/" && break
  echo -n "."; sleep 0.5
done
echo " ready."

echo "[3nricher] Starting web GUI..."
cd "$GUI"
npm run dev > /tmp/3nricher-gui.log 2>&1 &
GUI_PID=$!
echo -n "[3nricher] Waiting for web GUI"
for i in $(seq 1 40); do
  curl -s -o /dev/null "$URL" && break
  echo -n "."; sleep 0.5
done
echo " ready."

echo "[3nricher] Opening ${URL}"
xdg-open "$URL" 2>/dev/null &

echo "[3nricher] Running. Logs: /tmp/3nricher-backend.log, /tmp/3nricher-gui.log"
echo "[3nricher] Press Ctrl+C to stop everything."
trap 'kill $BACKEND_PID $GUI_PID 2>/dev/null; exit 0' INT TERM
wait
