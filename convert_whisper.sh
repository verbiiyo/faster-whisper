#!/usr/bin/env bash
# Converts openai/whisper-small to CTranslate2 format (int8 quantization)
# Output: /workspaces/faster-whisper/whisper-small-ct2/
set -euo pipefail

OUT_DIR="/workspaces/faster-whisper/whisper-small-ct2"

echo "==> Installing dependencies..."
pip install -q "ctranslate2>=4.3" "transformers[torch]" accelerate sentencepiece safetensors

echo "==> Converting openai/whisper-small -> ${OUT_DIR}"
python -m ctranslate2.converters.transformers \
  --model openai/whisper-small \
  --output_dir "${OUT_DIR}" \
  --quantization int8 \
  --force

echo ""
echo "Done! Files written to ${OUT_DIR}:"
ls -lh "${OUT_DIR}"
