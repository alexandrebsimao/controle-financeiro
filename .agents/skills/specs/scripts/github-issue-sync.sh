#!/usr/bin/env bash
# ==============================================================================
# GitHub Issue Sync Helper for Specifications and Interactions
# ==============================================================================
# Usage:
#   github-issue-sync.sh create "<title>" "<body_content_or_file>" "[labels]"
#   github-issue-sync.sh comment "<issue_number>" "<comment_content_or_file>"
# ==============================================================================

set -euo pipefail

# Determine repository remote slug (e.g. owner/repo)
get_repo_slug() {
  local remote_url
  remote_url=$(git config --get remote.origin.url || true)
  if [[ -z "$remote_url" ]]; then
    echo "Erro: remote origin do git não configurado." >&2
    exit 1
  fi

  # Support both SSH (git@github.com:owner/repo.git) and HTTPS (https://github.com/owner/repo.git)
  if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
    echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  else
    echo "Erro: Não foi possível extrair owner/repo da URL: $remote_url" >&2
    exit 1
  fi
}

REPO_SLUG=$(get_repo_slug)
ACTION="${1:-}"

# Read content from argument or file
read_content() {
  local input="$1"
  if [[ -f "$input" ]]; then
    cat "$input"
  else
    echo "$input"
  fi
}

case "$ACTION" in
  create)
    TITLE="${2:-}"
    BODY_INPUT="${3:-}"
    LABELS="${4:-spec,ready-for-agent}"

    if [[ -z "$TITLE" || -z "$BODY_INPUT" ]]; then
      echo "Uso: $0 create \"<title>\" \"<body_or_file>\" [labels]" >&2
      exit 1
    fi

    BODY_CONTENT=$(read_content "$BODY_INPUT")

    if command -v gh >/dev/null 2>&1; then
      echo "Criando issue via GitHub CLI..." >&2
      ISSUE_URL=$(gh issue create --repo "$REPO_SLUG" --title "$TITLE" --body "$BODY_CONTENT" --label "$LABELS")
      echo "$ISSUE_URL"
    elif [[ -n "${GITHUB_TOKEN:-${GH_TOKEN:-}}" ]]; then
      TOKEN="${GITHUB_TOKEN:-$GH_TOKEN}"
      echo "Criando issue via GitHub REST API..." >&2
      JSON_PAYLOAD=$(python3 -c "import json, sys; print(json.dumps({'title': sys.argv[1], 'body': sys.argv[2], 'labels': [l.strip() for l in sys.argv[3].split(',') if l.strip()]}))" "$TITLE" "$BODY_CONTENT" "$LABELS")
      
      RESPONSE=$(curl -s -X POST \
        -H "Authorization: Bearer $TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Content-Type: application/json" \
        https://api.github.com/repos/"$REPO_SLUG"/issues \
        -d "$JSON_PAYLOAD")
      
      ISSUE_URL=$(echo "$RESPONSE" | python3 -c "import json, sys; res=json.load(sys.stdin); print(res.get('html_url', 'Erro ao criar issue: ' + str(res)))")
      echo "$ISSUE_URL"
    else
      echo "AVISO: Nem 'gh' nem GITHUB_TOKEN configurados." >&2
      echo "Por favor instale o GitHub CLI ('brew install gh && gh auth login') ou defina GITHUB_TOKEN." >&2
      echo "SIMULATED_ISSUE_URL=https://github.com/$REPO_SLUG/issues/pending"
    fi
    ;;

  comment)
    ISSUE_NUM="${2:-}"
    COMMENT_INPUT="${3:-}"

    if [[ -z "$ISSUE_NUM" || -z "$COMMENT_INPUT" ]]; then
      echo "Uso: $0 comment \"<issue_number>\" \"<comment_or_file>\"" >&2
      exit 1
    fi

    # Extract pure number if URL was passed
    ISSUE_NUM="${ISSUE_NUM##*/}"
    ISSUE_NUM="${ISSUE_NUM//#/}"

    COMMENT_CONTENT=$(read_content "$COMMENT_INPUT")

    if command -v gh >/dev/null 2>&1; then
      gh issue comment "$ISSUE_NUM" --repo "$REPO_SLUG" --body "$COMMENT_CONTENT"
      echo "Comentário adicionado na issue #$ISSUE_NUM" >&2
    elif [[ -n "${GITHUB_TOKEN:-${GH_TOKEN:-}}" ]]; then
      TOKEN="${GITHUB_TOKEN:-$GH_TOKEN}"
      JSON_PAYLOAD=$(python3 -c "import json, sys; print(json.dumps({'body': sys.argv[1]}))" "$COMMENT_CONTENT")
      
      curl -s -X POST \
        -H "Authorization: Bearer $TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Content-Type: application/json" \
        https://api.github.com/repos/"$REPO_SLUG"/issues/"$ISSUE_NUM"/comments \
        -d "$JSON_PAYLOAD" >/dev/null
      echo "Comentário adicionado na issue #$ISSUE_NUM via API" >&2
    else
      echo "AVISO: Nem 'gh' nem GITHUB_TOKEN configurados. Comentário não enviado ao GitHub." >&2
    fi
    ;;

  *)
    echo "Comando inválido: $ACTION" >&2
    echo "Comandos disponíveis: create, comment" >&2
    exit 1
    ;;
esac
