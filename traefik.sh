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
  dev|development)   DIR="development"; PROJECT="traefik-dev" ;;
  prod|production)   DIR="production";  PROJECT="traefik-prod" ;;
  *)
    echo "Erro: ambiente desconhecido '$ENV'. Use 'dev' ou 'prod'." >&2
    exit 1
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# -----------------------------------------------------------------------------
# Aviso de drift: as tags da imagem traefik devem ser iguais nos dois ambientes
# (a duplicação entre development/ e production/ é intencional; a tag não deve
# divergir silenciosamente)
# -----------------------------------------------------------------------------
DEV_IMAGE=$(grep -m1 -oE 'image: traefik:[^ ]+' "$SCRIPT_DIR/development/docker-compose.yml" || true)
PROD_IMAGE=$(grep -m1 -oE 'image: traefik:[^ ]+' "$SCRIPT_DIR/production/docker-compose.yml" || true)
if [ -n "$DEV_IMAGE" ] && [ -n "$PROD_IMAGE" ] && [ "$DEV_IMAGE" != "$PROD_IMAGE" ]; then
  echo "⚠️  Versões do Traefik divergem entre os ambientes:" >&2
  echo "    development → ${DEV_IMAGE#image: }" >&2
  echo "    production  → ${PROD_IMAGE#image: }" >&2
fi

# -----------------------------------------------------------------------------
# Validação do .env de produção antes de subir: falhar aqui é mais barato que
# descobrir na emissão do certificado que ACME_EMAIL estava vazio/placeholder
# -----------------------------------------------------------------------------
CMD=${2:-up}
if [ "$DIR" = "production" ] && [ "$CMD" = "up" ]; then
  ENV_FILE="$SCRIPT_DIR/production/.env"
  if [ ! -f "$ENV_FILE" ]; then
    echo "Erro: $ENV_FILE não existe. Rode: bash production/setup-traefik-prod.sh" >&2
    exit 1
  fi
  for VAR in ACME_EMAIL TRAEFIK_DASHBOARD_HOST; do
    VALUE=$(grep -m1 -E "^${VAR}=" "$ENV_FILE" | cut -d= -f2- || true)
    case "$VALUE" in
      ""|name@email.com|traefik.site.com.br)
        echo "Erro: $VAR não está definido em production/.env (valor atual: '${VALUE:-vazio}')." >&2
        echo "Edite o arquivo antes de subir a produção." >&2
        exit 1
        ;;
    esac
  done
fi

cd "$SCRIPT_DIR/$DIR"

if [ $# -le 1 ]; then
  exec docker compose --project-name "$PROJECT" up -d
else
  exec docker compose --project-name "$PROJECT" "${@:2}"
fi
