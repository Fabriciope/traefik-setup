#!/bin/bash
# =============================================================================
# Script de configuração inicial do Traefik em produção
# Execute uma única vez antes do primeiro `docker compose up`
# =============================================================================
 
set -e
 
echo "🚀 Configurando ambiente Traefik para produção..."
 
# 1. Criar estrutura de diretórios
echo "📁 Criando diretórios..."
mkdir -p ./traefik/acme
mkdir -p ./traefik/auth
mkdir -p ./traefik/config
 
# 2. Criar arquivo acme.json com permissão correta (obrigatório pelo Traefik)
echo "🔐 Criando acme.json..."
touch ./traefik/acme/acme.json
chmod 600 ./traefik/acme/acme.json
 
# 3. Criar rede Docker externa (ignora erro se já existir)
echo "🌐 Criando rede Docker 'proxy-network'..."
docker network create proxy-network 2>/dev/null || echo "   (rede já existe, continuando...)"
 
# 4. Gerar usuário/senha para o dashboard
echo ""
echo "👤 Criando credenciais do dashboard..."
echo "   Informe o nome de usuário desejado:"
read -r DASHBOARD_USER
 
if ! command -v htpasswd &> /dev/null; then
  echo "   ⚠️  htpasswd não encontrado. Instalando apache2-utils..."
  sudo apt-get install -y apache2-utils 2>/dev/null || \
  sudo yum install -y httpd-tools 2>/dev/null || \
  brew install httpd 2>/dev/null || \
  { echo "   ❌ Instale manualmente: sudo apt install apache2-utils"; exit 1; }
fi
 
htpasswd -nBC 12 "$DASHBOARD_USER" > ./traefik/auth/dashboard_users
echo "   ✅ Arquivo de credenciais criado em ./traefik/auth/dashboard_users"
 
# 5. Criar .env a partir do exemplo (se não existir)
if [ ! -f .env ]; then
  cp .env.example .env
  echo ""
  echo "📝 Arquivo .env criado. Edite-o com seus valores:"
  echo "   nano .env"
else
  echo ""
  echo "   .env já existe, mantendo configurações atuais."
fi
 
echo ""
echo "✅ Setup concluído! Próximos passos:"
echo "   1. Edite o arquivo .env com seu e-mail e domínio"
echo "   2. Aponte o DNS do domínio do dashboard para este servidor"
echo "   3. Execute: docker compose up -d"
echo ""
