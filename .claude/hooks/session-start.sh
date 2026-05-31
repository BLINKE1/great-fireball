#!/bin/bash
# SessionStart hook — prepara o ambiente p/ DESENVOLVER E TESTAR a Soph/o jogo.
#
# Instala o Godot 4.6.3 (versao que o projeto exige) e as libs p/ rodar headless
# com xvfb, alem do Pillow (gerador de arte em tools/art_director). Com isso o
# agente consegue: importar o projeto, rodar a sala de testes e capturar
# screenshots reais do jogo — fechando o loop "render -> ver -> corrigir".
#
# Idempotente: pula o que ja estiver instalado. Sincrono: garante tudo pronto
# antes da sessao comecar.
set -euo pipefail

# So roda no ambiente remoto (Claude Code on the web). Local: nao mexe na maquina.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  echo "[session-start] ambiente local — pulando setup do Godot."
  exit 0
fi

GODOT_VERSION="4.6.3-stable"
GODOT_PKG="Godot_v${GODOT_VERSION}_linux.x86_64"
GODOT_DIR="${HOME}/godot"
GODOT_BIN="${GODOT_DIR}/${GODOT_PKG}"
GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${GODOT_PKG}.zip"

echo "[session-start] preparando ambiente de teste do jogo..."

# ── 1) Libs de sistema p/ Godot headless + render offscreen (xvfb) ──────────
need_pkgs=()
command -v xvfb-run >/dev/null 2>&1 || need_pkgs+=(xvfb)
command -v unzip     >/dev/null 2>&1 || need_pkgs+=(unzip)
# libGL basta p/ rodar headless com o driver opengl3 (GL compatibility).
ldconfig -p 2>/dev/null | grep -q "libGL.so.1" || need_pkgs+=(libgl1)
if [ "${#need_pkgs[@]}" -gt 0 ]; then
  echo "[session-start] instalando libs: ${need_pkgs[*]}"
  if command -v apt-get >/dev/null 2>&1; then
    # update tolerante: PPAs de terceiro quebrados nao devem abortar o setup
    apt-get update -qq 2>/dev/null || echo "[session-start] aviso: apt-get update parcial (PPA de terceiro?)"
    apt-get install -y -qq "${need_pkgs[@]}" \
      || echo "[session-start] aviso: apt falhou em ${need_pkgs[*]} (segue mesmo assim)"
  fi
else
  echo "[session-start] libs de sistema ja presentes (xvfb/unzip/libGL)."
fi

# ── 2) Godot 4.6.3 (baixa so se ainda nao existe) ───────────────────────────
if [ -x "${GODOT_BIN}" ]; then
  echo "[session-start] Godot ja presente: ${GODOT_BIN}"
else
  echo "[session-start] baixando Godot ${GODOT_VERSION}..."
  mkdir -p "${GODOT_DIR}"
  tmp_zip="$(mktemp --suffix=.zip)"
  if curl -sSL --max-time 240 -o "${tmp_zip}" "${GODOT_URL}"; then
    unzip -o -q "${tmp_zip}" -d "${GODOT_DIR}"
    chmod +x "${GODOT_BIN}" || true
    rm -f "${tmp_zip}"
    echo "[session-start] Godot instalado em ${GODOT_BIN}"
  else
    echo "[session-start] ERRO: download do Godot falhou (rede?). Testes ficarao indisponiveis."
    rm -f "${tmp_zip}"
  fi
fi

# ── 3) Pillow p/ o gerador de arte (tools/art_director/soph_dream.py) ───────
if ! python3 -c "import PIL" >/dev/null 2>&1; then
  echo "[session-start] instalando Pillow..."
  python3 -m pip install --quiet --disable-pip-version-check Pillow \
    || echo "[session-start] aviso: pip Pillow falhou"
fi

# ── 4) Exporta o caminho do Godot p/ a sessao ($GODOT) ──────────────────────
if [ -x "${GODOT_BIN}" ] && [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export GODOT=\"${GODOT_BIN}\"" >> "${CLAUDE_ENV_FILE}"
  echo "[session-start] \$GODOT exportado p/ a sessao."
fi

echo "[session-start] pronto."
