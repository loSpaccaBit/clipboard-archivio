#!/usr/bin/env bash
# Campiona CPU e memoria di Appunti Archivio per N secondi.
set -euo pipefail
export LC_NUMERIC=C

APP_NAME="Appunti Archivio"
DURATION="${1:-30}"
INTERVAL="${2:-2}"
REPORT_DIR="${3:-/Users/lospaccabit/ClipboardArchivio/Scripts/reports}"

mkdir -p "$REPORT_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
REPORT="$REPORT_DIR/performance-$STAMP.txt"

PID="$(pgrep -x "$APP_NAME" | head -1 || true)"
if [[ -z "$PID" ]]; then
  echo "Errore: '$APP_NAME' non è in esecuzione. Avviala prima del test." >&2
  exit 1
fi

echo "Test performance — $APP_NAME (PID $PID)" | tee "$REPORT"
echo "Durata: ${DURATION}s, campionamento ogni ${INTERVAL}s" | tee -a "$REPORT"
echo "Avviato: $(date)" | tee -a "$REPORT"
echo "----------------------------------------" | tee -a "$REPORT"

CPU_SUM=0
MEM_SUM=0
SAMPLES=0
CPU_MAX=0
MEM_MAX=0

end=$((SECONDS + DURATION))
while (( SECONDS < end )); do
  LINE="$(LC_ALL=C ps -p "$PID" -o %cpu=,rss= 2>/dev/null | tr -s ' ' || true)"
  if [[ -n "$LINE" ]]; then
    CPU="$(echo "$LINE" | awk '{print $1}' | tr ',' '.')"
    RSS_KB="$(echo "$LINE" | awk '{print $2}')"
    MEM_MB="$(awk -v rss="$RSS_KB" 'BEGIN {printf "%.1f", rss / 1024}')"
    printf "[%s] CPU: %s%%  RAM: %s MB\n" "$(date +%H:%M:%S)" "$CPU" "$MEM_MB" | tee -a "$REPORT"
    CPU_SUM="$(awk -v a="$CPU_SUM" -v b="$CPU" 'BEGIN {print a + b}')"
    MEM_SUM="$(awk -v a="$MEM_SUM" -v b="$MEM_MB" 'BEGIN {print a + b}')"
    SAMPLES=$((SAMPLES + 1))
    CPU_MAX="$(awk -v a="$CPU" -v b="$CPU_MAX" 'BEGIN {print (a > b) ? a : b}')"
    MEM_MAX="$(awk -v a="$MEM_MB" -v b="$MEM_MAX" 'BEGIN {print (a > b) ? a : b}')"
  fi
  sleep "$INTERVAL"
done

echo "----------------------------------------" | tee -a "$REPORT"
if (( SAMPLES > 0 )); then
  CPU_AVG="$(awk -v s="$CPU_SUM" -v n="$SAMPLES" 'BEGIN {printf "%.2f", s / n}')"
  MEM_AVG="$(awk -v s="$MEM_SUM" -v n="$SAMPLES" 'BEGIN {printf "%.1f", s / n}')"
  echo "Campioni: $SAMPLES" | tee -a "$REPORT"
  echo "CPU media: ${CPU_AVG}%  (max ${CPU_MAX}%)" | tee -a "$REPORT"
  echo "RAM media: ${MEM_AVG} MB  (max ${MEM_MAX} MB)" | tee -a "$REPORT"
  echo "" | tee -a "$REPORT"
  echo "Obiettivo menu bar app: CPU < 1% a riposo, RAM < 100 MB" | tee -a "$REPORT"
  PASS_CPU="$(awk -v v="$CPU_AVG" 'BEGIN {print (v < 1.0) ? "OK" : "ATTENZIONE"}')"
  PASS_MEM="$(awk -v v="$MEM_AVG" 'BEGIN {print (v < 100) ? "OK" : "ATTENZIONE"}')"
  echo "Valutazione CPU: $PASS_CPU" | tee -a "$REPORT"
  echo "Valutazione RAM: $PASS_MEM" | tee -a "$REPORT"
else
  echo "Nessun campione raccolto — il processo potrebbe essere terminato." | tee -a "$REPORT"
  exit 2
fi

echo "Report salvato in: $REPORT"