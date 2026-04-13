#!/usr/bin/env bash
# Converts openai/whisper-small to CTranslate2 format (int8 quantization)
# Output: /workspaces/faster-whisper/whisper-small-ct2/

# If invoked with `sh`, restart with bash so bash-specific options/features work.
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

set -euo pipefail

OUT_DIR="/workspaces/faster-whisper/whisper-small-ct2"
ARCHIVE="/workspaces/faster-whisper/whisper-small-ct2.tar.gz"

echo "==> Installing dependencies..."
pip install -q "ctranslate2>=4.3" "transformers[torch]" accelerate sentencepiece safetensors

echo "==> Converting openai/whisper-small -> ${OUT_DIR}"
python -m ctranslate2.converters.transformers \
  --model openai/whisper-small \
  --output_dir "${OUT_DIR}" \
  --copy_files tokenizer.json preprocessor_config.json special_tokens_map.json tokenizer_config.json \
  --quantization int8 \
  --force

echo "==> Ensuring tokenizer and preprocessor configs exist"
python - <<'PY'
from pathlib import Path

from transformers import AutoFeatureExtractor, AutoTokenizer

model_id = "openai/whisper-small"
out_dir = "/workspaces/faster-whisper/whisper-small-ct2"
out = Path(out_dir)

if not (out / "tokenizer.json").is_file():
    tokenizer = AutoTokenizer.from_pretrained(model_id)
    tokenizer.save_pretrained(out_dir)

if not (out / "preprocessor_config.json").is_file():
    extractor = AutoFeatureExtractor.from_pretrained(model_id)
    extractor.save_pretrained(out_dir)
PY

required=(
  "model.bin"
  "config.json"
  "vocabulary.json"
  "tokenizer.json"
  "preprocessor_config.json"
)

echo "==> Verifying required files"
for f in "${required[@]}"; do
  if [[ ! -f "${OUT_DIR}/${f}" ]]; then
    echo "Missing required file: ${OUT_DIR}/${f}" >&2
    exit 1
  fi
done

echo "==> Creating tar archive ${ARCHIVE}"
tar -czf "${ARCHIVE}" -C "/workspaces/faster-whisper" "whisper-small-ct2"

echo ""
echo "Done! Files written to ${OUT_DIR}:"
ls -lh "${OUT_DIR}"
echo ""
echo "Archive ready: ${ARCHIVE}"
ls -lh "${ARCHIVE}"
