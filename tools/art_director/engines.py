"""
engines.py — Camada de abstração para diferentes LLMs com visão.

Motores suportados:
  gemini   — Google Gemini (FREE tier em aistudio.google.com, sem cartão)
  anthropic — Claude Sonnet (pago, melhor qualidade)
  ollama   — Modelos locais via Ollama (gratuito, precisa GPU/CPU potente)

Interface única:
  engine = build_engine(name, api_key)
  text   = engine.call(prompt, image)   # image é PIL.Image ou None
"""

from __future__ import annotations
import base64
import time
from io import BytesIO
from typing import Protocol

try:
    from PIL import Image
except ImportError:
    pass


# ── Configuração de rede (evita travamentos) ──────────────────────────────────

# Timeout máximo por requisição HTTP. Sem isto, uma chamada pode pendurar
# indefinidamente (foi a causa do "travamento" relatado).
HTTP_TIMEOUT = 90

# Esperas de backoff entre tentativas em caso de rate-limit (429) / indisponível (503).
# Mantido enxuto para falhar rápido em vez de empilhar vários minutos parado.
RETRY_WAITS = [0, 5, 15, 30]


# ── Protocolo comum ───────────────────────────────────────────────────────────

class Engine(Protocol):
    name: str
    model: str
    def call(self, prompt: str, image: "Image.Image | None" = None) -> str: ...


# ── Gemini (FREE) ─────────────────────────────────────────────────────────────

class GeminiEngine:
    """
    Google Gemini via REST API — sem dependências complexas.
    Free tier generoso, visão nativa, sem cartão de crédito.
    Chave gratuita em: https://aistudio.google.com/apikey
    Requer apenas: pip install requests
    """
    name  = "gemini"
    model = "gemini-2.5-flash"

    _BASE = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"

    def __init__(self, api_key: str, model: str | None = None):
        try:
            import requests as _req
            self._req = _req
        except ImportError:
            raise ImportError("pip install requests")
        self.api_key = api_key
        self.model   = model or self.model

    def call(self, prompt: str, image: "Image.Image | None" = None) -> str:
        parts: list[dict] = []
        if image is not None:
            buf = BytesIO()
            image.save(buf, format="PNG")
            b64 = base64.standard_b64encode(buf.getvalue()).decode()
            parts.append({"inline_data": {"mime_type": "image/png", "data": b64}})
        parts.append({"text": prompt})

        url  = self._BASE.format(model=self.model)
        body = {
            "contents": [{"parts": parts}],
            "generationConfig": {"maxOutputTokens": 8192, "temperature": 0.4},
        }
        # Retry com backoff em caso de rate-limit (429) ou indisponibilidade (503).
        # Erros de auth (401/403) NÃO são retentados — caem direto em raise_for_status.
        for attempt, wait in enumerate(RETRY_WAITS):
            if wait:
                print(f"\n  Aguardando {wait}s (tentativa {attempt+1}/{len(RETRY_WAITS)})...", end=" ", flush=True)
                time.sleep(wait)
            try:
                resp = self._req.post(url, params={"key": self.api_key},
                                      json=body, timeout=HTTP_TIMEOUT)
            except self._req.exceptions.RequestException as e:
                if attempt < len(RETRY_WAITS) - 1:
                    print(f"\n  Falha de rede: {type(e).__name__} — re-tentando...", end=" ", flush=True)
                    continue
                raise
            if resp.status_code in (429, 503) and attempt < len(RETRY_WAITS) - 1:
                continue
            resp.raise_for_status()
            data = resp.json()
            return data["candidates"][0]["content"]["parts"][0]["text"]
        resp.raise_for_status()  # lança se esgotou as tentativas


# ── Anthropic Claude ──────────────────────────────────────────────────────────

class AnthropicEngine:
    """
    Claude Sonnet — melhor qualidade de crítica e geração de código.
    Requer ANTHROPIC_API_KEY (pago).
    pip install anthropic
    """
    name  = "anthropic"
    model = "claude-sonnet-4-6"

    def __init__(self, api_key: str, model: str | None = None):
        try:
            import anthropic
        except ImportError:
            raise ImportError("pip install anthropic")
        # max_retries=2 + timeout explícito evitam que a chamada pendure ~10min (default).
        self._client = anthropic.Anthropic(
            api_key=api_key, timeout=HTTP_TIMEOUT, max_retries=2
        )
        self.model   = model or self.model

    def _to_b64(self, img: "Image.Image") -> str:
        buf = BytesIO()
        img.save(buf, format="PNG")
        return base64.standard_b64encode(buf.getvalue()).decode()

    def call(self, prompt: str, image: "Image.Image | None" = None) -> str:
        import anthropic
        content: list = []
        if image is not None:
            content.append({
                "type": "image",
                "source": {
                    "type": "base64",
                    "media_type": "image/png",
                    "data": self._to_b64(image),
                },
            })
        content.append({"type": "text", "text": prompt})
        response = self._client.messages.create(
            model=self.model,
            max_tokens=8192,
            messages=[{"role": "user", "content": content}],
            timeout=HTTP_TIMEOUT,
        )
        return response.content[0].text


# ── Ollama (local, gratuito) ──────────────────────────────────────────────────

class OllamaEngine:
    """
    Ollama — modelos locais, 100% gratuito, sem internet.
    Instale Ollama: https://ollama.com
    Modelos com visão: ollama pull llava  (ou moondream, bakllava)
    pip install ollama
    """
    name  = "ollama"
    model = "llava"

    def __init__(self, api_key: str | None = None, model: str | None = None):
        try:
            import ollama as _ollama
            self._ollama = _ollama
        except ImportError:
            raise ImportError("pip install ollama")
        # Client com timeout — sem isto a chamada pendura se o modelo local nunca responde.
        self._client = _ollama.Client(timeout=HTTP_TIMEOUT)
        self.model = model or self.model

    def _to_bytes(self, img: "Image.Image") -> bytes:
        buf = BytesIO()
        img.save(buf, format="PNG")
        return buf.getvalue()

    def call(self, prompt: str, image: "Image.Image | None" = None) -> str:
        msg: dict = {"role": "user", "content": prompt}
        if image is not None:
            msg["images"] = [self._to_bytes(image)]
        response = self._client.chat(
            model=self.model,
            messages=[msg],
        )
        return response["message"]["content"]


# ── OpenRouter (free tier, múltiplos modelos com visão) ───────────────────────

class OpenRouterEngine:
    """
    OpenRouter — acessa dezenas de modelos via uma API OpenAI-compatível.
    Modelos free com visão: meta-llama/llama-3.2-11b-vision-instruct:free
                            qwen/qwen-2-vl-7b-instruct:free
    Chave grátis em: https://openrouter.ai/keys
    Requer apenas: pip install requests
    """
    name  = "openrouter"
    model = "meta-llama/llama-3.2-11b-vision-instruct:free"

    _BASE = "https://openrouter.ai/api/v1/chat/completions"

    def __init__(self, api_key: str, model: str | None = None):
        try:
            import requests as _req
            self._req = _req
        except ImportError:
            raise ImportError("pip install requests")
        self.api_key = api_key
        self.model   = model or self.model

    def call(self, prompt: str, image: "Image.Image | None" = None) -> str:
        content: list = []
        if image is not None:
            buf = BytesIO()
            image.save(buf, format="PNG")
            b64 = base64.standard_b64encode(buf.getvalue()).decode()
            content.append({
                "type": "image_url",
                "image_url": {"url": f"data:image/png;base64,{b64}"},
            })
        content.append({"type": "text", "text": prompt})

        body = {
            "model": self.model,
            "messages": [{"role": "user", "content": content}],
        }
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type":  "application/json",
        }
        for attempt, wait in enumerate(RETRY_WAITS):
            if wait:
                print(f"\n  Aguardando {wait}s (tentativa {attempt+1}/{len(RETRY_WAITS)})...", end=" ", flush=True)
                time.sleep(wait)
            try:
                resp = self._req.post(self._BASE, headers=headers,
                                      json=body, timeout=HTTP_TIMEOUT)
            except self._req.exceptions.RequestException as e:
                if attempt < len(RETRY_WAITS) - 1:
                    print(f"\n  Falha de rede: {type(e).__name__} — re-tentando...", end=" ", flush=True)
                    continue
                raise
            if resp.status_code in (429, 503) and attempt < len(RETRY_WAITS) - 1:
                continue
            resp.raise_for_status()
            return resp.json()["choices"][0]["message"]["content"]
        resp.raise_for_status()


# ── Factory ───────────────────────────────────────────────────────────────────

ENGINES = {
    "gemini":      GeminiEngine,
    "anthropic":   AnthropicEngine,
    "claude":      AnthropicEngine,   # alias
    "ollama":      OllamaEngine,
    "openrouter":  OpenRouterEngine,
}

ENGINE_KEYS = {
    "gemini":      "GEMINI_API_KEY",
    "anthropic":   "ANTHROPIC_API_KEY",
    "claude":      "ANTHROPIC_API_KEY",
    "ollama":      None,
    "openrouter":  "OPENROUTER_API_KEY",
}

FREE_ENGINES = {"gemini", "ollama", "openrouter"}


def build_engine(name: str, api_key: str | None = None,
                 model: str | None = None) -> Engine:
    name = name.lower()
    if name not in ENGINES:
        raise ValueError(f"Engine desconhecida: {name!r}. Opções: {list(ENGINES)}")
    cls = ENGINES[name]
    return cls(api_key=api_key or "", model=model)


def engine_help() -> str:
    return (
        "\nMotores disponíveis (--engine):\n"
        "  gemini      — Grátis! Chave em aistudio.google.com/apikey (sem cartão)\n"
        "                Variável: GEMINI_API_KEY\n"
        "  openrouter  — Grátis! Vários modelos com visão. openrouter.ai/keys\n"
        "                Variável: OPENROUTER_API_KEY\n"
        "                Modelos: --model meta-llama/llama-3.2-11b-vision-instruct:free\n"
        "                         --model qwen/qwen-2-vl-7b-instruct:free\n"
        "  anthropic   — Melhor qualidade, pago. Variável: ANTHROPIC_API_KEY\n"
        "  ollama      — Local, grátis. Instale Ollama + 'ollama pull llava'\n"
        "                Não precisa de chave API\n"
    )
