import logging
from typing import Optional

logger = logging.getLogger(__name__)

_MAX_CHARS = 8000  # ~2000 tokens — enough context for a 100-word summary

_PROMPT = (
    "Read the following legal document text and write a factual summary "
    "of approximately 100 words. Describe what the document is about, "
    "its main purpose, and key provisions. Be concise and neutral. "
    "Reply with the summary only — no preamble or extra commentary.\n\n"
    "Document text:\n"
)


def summarize_document(text: str) -> Optional[str]:
    from app.core.config import settings

    try:
        import ollama
        client = ollama.Client(host=settings.OLLAMA_HOST)
        response = client.chat(
            model=settings.OLLAMA_MODEL,
            messages=[{"role": "user", "content": _PROMPT + text[:_MAX_CHARS]}],
        )
        return response.message.content.strip()
    except ImportError:
        logger.error("[Summarizer] ollama package not installed. Run: pip install ollama")
        return None
    except Exception as exc:
        logger.error("[Summarizer] Failed to generate summary: %s", exc)
        return None
