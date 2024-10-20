
# Prerequisites
Install uv

## Linux and Mac
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

## Windows
```bash
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

Install poppler

## Linux
```bash
apt install poppler-utils
```

## Mac
```bash
brew install poppler
```

## Windows
```bash
scoop install poppler
```

# Usage

```bash
uv run --package ai_ocr ai_ocr
```
