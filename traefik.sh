#!/usr/bin/env bash
# =============================================================================
# Gerenciador de ambientes Traefik
# Uso: ./traefik.sh <dev|prod> [comando docker compose]
#
# Exemplos:
#   ./traefik.sh dev               # sobe o ambiente de desenvolvimento
#   ./traefik.sh prod              # sobe o ambiente de produção
#   ./traefik.sh dev logs -f       # segue os logs do dev
#   ./traefik.sh prod down         # derruba a produção
#   ./traefik.sh dev restart       # reinicia o dev
# =============================================================================

set -euo pipefail

ENV=${1:-}

if [ -z "$ENV" ]; then
  echo "Uso: ./traefik.sh <dev|prod> [comando docker compose]"
  echo ""
  echo "Ambientes disponíveis:"
  echo "  dev   → development/"
  echo "  prod  → production/"
  exit 1
fi

case "$ENV" in
  dev|development)   DIR="development" ;;
  prod|production)   DIR="production" ;;
  *)
    echo "Erro: ambiente desconhecido '$ENV'. Use 'dev' ou 'prod'." >&2
    exit 1
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/$DIR"

if [ $# -le 1 ]; then
  exec docker compose up -d
else
  exec docker compose "${@:2}"
fi
