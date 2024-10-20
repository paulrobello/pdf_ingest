"""LLM provider types."""

from __future__ import annotations

import os
from dataclasses import dataclass
from enum import Enum
from typing import Optional


@dataclass
class LangChainConfig:
    """Langchain config."""

    tracing: bool = False
    project: str = "pdf-ocr"
    base_url: str = "https://api.smith.langchain.com"
    api_key: str = ""


class LlmProvider(str, Enum):
    """Llm provider types."""

    OPENAI = "OpenAI"
    ANTHROPIC = "Anthropic"
    BEDROCK = "Bedrock"


llm_provider_types: list[LlmProvider] = list(LlmProvider)
llm_provider_names: list[str] = [p.value.lower() for p in llm_provider_types]

provider_base_urls: dict[LlmProvider, Optional[str]] = {
    LlmProvider.OPENAI: None,
    LlmProvider.ANTHROPIC: None,
    LlmProvider.BEDROCK: None,
}

provider_default_models: dict[LlmProvider, str] = {
    LlmProvider.OPENAI: "gpt-4o",
    LlmProvider.ANTHROPIC: "claude-3-5-sonnet-20240620",
    LlmProvider.BEDROCK: "anthropic.claude-3-5-sonnet-20240620-v1:0",
}

provider_env_key_names: dict[LlmProvider, str] = {
    LlmProvider.OPENAI: "OPENAI_API_KEY",
    LlmProvider.ANTHROPIC: "ANTHROPIC_API_KEY",
    LlmProvider.BEDROCK: "BEDROCK_API_KEY",
}


def get_provider_name_fuzzy(provider: str) -> str:
    """Get provider name fuzzy."""
    provider = provider.lower()
    for p in llm_provider_types:
        if p.value.lower() == provider:
            return p
        if p.value.lower().startswith(provider):
            return p
    return ""


@dataclass
class LlmProviderConfig:
    """Llm provider config."""

    default_model: str
    supports_base_url: bool
    env_key_name: str


provider_config: dict[LlmProvider, LlmProviderConfig] = {
    LlmProvider.OPENAI: LlmProviderConfig(
        default_model=provider_default_models[LlmProvider.OPENAI],
        supports_base_url=True,
        env_key_name=provider_env_key_names[LlmProvider.OPENAI],
    ),
    LlmProvider.ANTHROPIC: LlmProviderConfig(
        default_model=provider_default_models[LlmProvider.ANTHROPIC],
        supports_base_url=False,
        env_key_name=provider_env_key_names[LlmProvider.ANTHROPIC],
    ),
    LlmProvider.BEDROCK: LlmProviderConfig(
        default_model=provider_default_models[LlmProvider.BEDROCK],
        supports_base_url=False,
        env_key_name=provider_env_key_names[LlmProvider.BEDROCK],
    ),
}


provider_env_key_names: dict[LlmProvider, str] = {
    k: v.env_key_name for k, v in provider_config.items()
}


def provider_name_to_enum(name: str) -> LlmProvider:
    """Get LlmProvider enum from string."""
    return LlmProvider(name)


def is_provider_api_key_set(provider: LlmProvider) -> bool:
    """Check if API key is set for the provider."""
    if provider == LlmProvider.BEDROCK:
        return True
    return len(os.environ.get(provider_env_key_names[provider], "")) > 0


def get_providers_with_api_keys() -> list[LlmProvider]:
    """Get providers with API keys."""
    return [p for p in LlmProvider if is_provider_api_key_set(p)]


def get_provider_select_options() -> list[tuple[str, LlmProvider]]:
    """Get provider select options."""
    return [
        (
            p,
            LlmProvider(p),
        )
        for p in get_providers_with_api_keys()
    ]
