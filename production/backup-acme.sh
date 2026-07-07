#!/bin/bash
# =============================================================================
# Backup do acme.json (certificados + chaves privadas do Let's Encrypt)
#
# Perder o acme.json força a reemissão de todos os certificados e pode bater
# no rate limit do Let's Encrypt (5 certificados duplicados por semana).
#
# Uso:
#   bash backup-acme.sh [diretório-destino]     # default: ./backups
#
# Rotação: mantém 7 cópias, uma por dia da semana (acme.json.1 … acme.json.7).
# Agende no cron do host, ex. todo dia às 3h:
#   0 3 * * * /bin/bash /caminho/para/production/backup-acme.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/traefik/acme/acme.json"
DEST_DIR="${1:-$SCRIPT_DIR/backups}"

if [ ! -s "$SRC" ]; then
  echo "❌ $SRC não existe ou está vazio — nada para copiar." >&2
  exit 1
fi

mkdir -p "$DEST_DIR"

# O arquivo contém chaves privadas: a cópia mantém modo 600, como o original.
DEST="$DEST_DIR/acme.json.$(date +%u)"
install -m 600 "$SRC" "$DEST"

echo "✅ Backup criado: $DEST ($(du -h "$DEST" | cut -f1))"
