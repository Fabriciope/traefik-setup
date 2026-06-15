#!/bin/bash
# =============================================================================
# Script de configuração inicial do Traefik em desenvolvimento
# Execute uma única vez antes do primeiro `docker compose up`
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Verificação de pré-requisitos antes de executar qualquer coisa
echo "🔍 Verificando pré-requisitos..."

MISSING=0

if [ ! -f "$SCRIPT_DIR/docker-compose.yml" ]; then
  echo "   ❌ docker-compose.yml não encontrado em $SCRIPT_DIR"
  MISSING=1
fi

if ! command -v docker &> /dev/null; then
  echo "   ❌ docker não está instalado"
  MISSING=1
fi

if [ "$MISSING" -eq 1 ]; then
  echo ""
  echo "Corrija os problemas acima e execute novamente."
  exit 1
fi

echo "   ✅ Tudo certo."
echo ""
echo "🛠️  Configurando ambiente Traefik para desenvolvimento..."

# Criar rede Docker externa (ignora erro se já existir)
echo "🌐 Criando rede Docker 'proxy-network'..."
docker network create proxy-network 2>/dev/null || echo "   (rede já existe, continuando...)"

echo ""
echo "✅ Setup concluído! Próximos passos:"
echo ""
echo "   1. Suba o Traefik:"
echo "      docker compose up -d  (dentro de $SCRIPT_DIR)"
echo "      ou: ./traefik.sh dev  (na raiz do projeto)"
echo ""
echo "   2. Acesse o dashboard:"
echo "      http://localhost:8080/dashboard/"
echo ""
echo "   3. (Opcional) Para acessar via http://traefik.local, adicione ao /etc/hosts:"
echo "      echo '127.0.0.1 traefik.local' | sudo tee -a /etc/hosts"
echo ""
