#!/bin/bash
# =============================================================================
# Script de configuração inicial do Traefik em desenvolvimento
# Execute uma única vez antes do primeiro `docker compose up`
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="$SCRIPT_DIR/traefik/certs"

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

# 1. Criar rede Docker externa (ignora erro se já existir)
echo "🌐 Criando rede Docker 'proxy-network'..."
docker network create proxy-network 2>/dev/null || echo "   (rede já existe, continuando...)"

# 2. Instalar mkcert, se necessário
if ! command -v mkcert &> /dev/null; then
  echo ""
  echo "🔐 mkcert não encontrado. Instalando..."
  sudo apt-get install -y mkcert libnss3-tools 2>/dev/null || \
  sudo yum install -y mkcert 2>/dev/null || \
  brew install mkcert 2>/dev/null || \
  { echo "   ❌ Instale manualmente: https://github.com/FiloSottile/mkcert#installation"; exit 1; }
fi

# 3. Montar a lista de domínios do certificado
#    *.dev NÃO entra como wildcard: é um TLD público (Public Suffix List) e
#    navegadores recusam wildcard direto sobre TLD público, mesmo com CA
#    local confiável. Domínios .dev precisam vir explícitos — veja
#    traefik/dev-domains.txt.
DOMAINS=("*.localhost" "*.local" "traefik.local" "localhost" "127.0.0.1" "::1")

DOMAINS_FILE="$SCRIPT_DIR/traefik/dev-domains.txt"
if [ -f "$DOMAINS_FILE" ]; then
  while IFS= read -r line; do
    line="${line%%#*}"                      # remove comentários
    line="$(echo "$line" | tr -d '[:space:]')"  # trim
    [ -n "$line" ] && DOMAINS+=("$line")
  done < "$DOMAINS_FILE"
fi

# 4. Gerar certificado TLS local (sempre regenera — barato e idempotente;
#    garante que domínios novos adicionados em dev-domains.txt entrem)
mkdir -p "$CERTS_DIR"

echo ""
echo "🔐 Instalando a CA local do mkcert (pode pedir sua senha)..."
mkcert -install

echo "🔐 Gerando certificado para: ${DOMAINS[*]}"
mkcert -cert-file "$CERTS_DIR/local-cert.pem" -key-file "$CERTS_DIR/local-key.pem" "${DOMAINS[@]}"

echo "   ✅ Certificado criado em $CERTS_DIR"

echo ""
echo "✅ Setup concluído! Próximos passos:"
echo ""
echo "   1. Suba o Traefik:"
echo "      docker compose up -d  (dentro de $SCRIPT_DIR)"
echo "      ou: ./traefik.sh dev  (na raiz do projeto)"
echo ""
echo "   2. Acesse o dashboard:"
echo "      http://localhost:8080/dashboard/"
echo "      https://traefik.local/dashboard/ (requer /etc/hosts, veja abaixo)"
echo ""
echo "   3. (Opcional) Para acessar via traefik.local, adicione ao /etc/hosts:"
echo "      echo '127.0.0.1 traefik.local' | sudo tee -a /etc/hosts"
echo ""
