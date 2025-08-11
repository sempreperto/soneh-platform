set -euo pipefail

REPO_NAME="${1:-soneh-saas}"
VISIBILITY="${2:---private}" # --private (padrão) | --public

# 0) sanity check
[ -f "pnpm-workspace.yaml" ] || { echo "❌ Rode este script na RAIZ do projeto (onde está pnpm-workspace.yaml)."; exit 1; }

echo "📁 Projeto: $PWD"
echo "📦 Repo no GitHub: $REPO_NAME ($VISIBILITY)"

# 1) .gitignore (só cria se não existir)
if [ ! -f .gitignore ]; then
cat > .gitignore <<'EOF'
# Node/JS
node_modules/
.pnpm-store/
.turbo/
dist/
.next/
apps/**/dist/
apps/**/.next/

# Env/segredos
.env
.env.*
!.env.example

infra/.env
apps/**/.env
apps/**/.env.*

# Docker/volumes/cache
**/.DS_Store
coverage/
*.log
*.pid
**/.idea/
**/.vscode/

# Builds móveis/web
apps/mobile/android/
apps/mobile/ios/
EOF
  echo "✅ .gitignore criado"
else
  echo "ℹ️  .gitignore já existe (não alterei)"
fi

# 2) Gerar .env.example (sem valores) se existir .env
if [ -f ".env" ] && [ ! -f ".env.example" ]; then
  grep -v '^\s*$\|^\s*#' .env | cut -d= -f1 | sed 's/$/=/' > .env.example || true
  echo "✅ .env.example gerado a partir de .env (apenas chaves, sem valores)"
fi

# 3) init git
if [ ! -d .git ]; then
  git init
  git branch -M main
  git add .
  git commit -m "chore: initial import"
  echo "✅ Git inicializado e primeiro commit feito"
else
  echo "ℹ️  Repositório git já existe — vou só adicionar remoto se faltar"
fi

# 4) criar repo no GitHub (se tiver gh e ainda não existir origin)
if ! git remote get-url origin >/dev/null 2>&1; then
  if command -v gh >/dev/null 2>&1; then
    echo "🔐 Verificando autenticação do GitHub CLI (gh)..."
    if ! gh auth status >/dev/null 2>&1; then
      echo "⚠️  Você não está autenticado no gh. Rode: gh auth login"
      exit 1
    fi
    gh repo create "$REPO_NAME" $VISIBILITY --source=. --remote=origin --push
    echo "✅ Repositório criado e push realizado com gh"
  else
    echo "⚠️  gh (GitHub CLI) não encontrado."
    echo "   1) Crie o repo no GitHub (web) com o nome: $REPO_NAME"
    echo "   2) Depois rode:"
    echo "      git remote add origin git@github.com:<seu-usuario>/$REPO_NAME.git"
    echo "      git push -u origin main"
  fi
else
  echo "ℹ️  Remote origin já configurado: $(git remote get-url origin)"
  echo "⏫ Fazendo push..."
  git push -u origin main
  echo "✅ Push feito"
fi

echo "🎉 Pronto! Repo: https://github.com/sempreperto/$REPO_NAME"
