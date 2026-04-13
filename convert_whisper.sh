#!/usr/bin/env bash
# Converts a selected OpenAI Whisper model to CTranslate2 format (int8 quantization)
# Outputs are written under /workspaces/faster-whisper/xos_model_conversion_outputs/

# If invoked with `sh`, restart with bash so bash-specific options/features work.
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

set -euo pipefail

ROOT_DIR="/workspaces/faster-whisper"
OUT_ROOT="${ROOT_DIR}/xos_model_conversion_outputs"
VARIANTS=(
  "tiny"
  "base"
  "small"
  "medium"
  "large-v1"
  "large-v2"
  "large-v3"
  "large-v3-turbo"
  "large"
)

MODEL_VARIANT="${1:-${WHISPER_VARIANT:-}}"

if [ -z "${MODEL_VARIANT}" ]; then
  echo "Select a Whisper model variant to convert:"
  for i in "${!VARIANTS[@]}"; do
    printf "  %d) %s\n" "$((i + 1))" "${VARIANTS[$i]}"
  done
  read -r -p "Enter number or name [default: small]: " choice
  if [ -z "${choice}" ]; then
    MODEL_VARIANT="small"
  elif [[ "${choice}" =~ ^[0-9]+$ ]]; then
    idx=$((choice - 1))
    if [ "${idx}" -lt 0 ] || [ "${idx}" -ge "${#VARIANTS[@]}" ]; then
      echo "Invalid selection: ${choice}" >&2
      exit 1
    fi
    MODEL_VARIANT="${VARIANTS[$idx]}"
  else
    MODEL_VARIANT="${choice}"
  fi
fi

valid="false"
for v in "${VARIANTS[@]}"; do
  if [ "${MODEL_VARIANT}" = "${v}" ]; then
    valid="true"
    break
  fi
done

if [ "${valid}" != "true" ]; then
  echo "Unsupported model variant: ${MODEL_VARIANT}" >&2
  echo "Supported variants: ${VARIANTS[*]}" >&2
  exit 1
fi

MODEL_ID="openai/whisper-${MODEL_VARIANT}"
OUT_DIR="${OUT_ROOT}/whisper-${MODEL_VARIANT}-ct2"
ARCHIVE="${OUT_ROOT}/whisper-${MODEL_VARIANT}-ct2.tar.gz"

mkdir -p "${OUT_ROOT}"

echo "==> Installing dependencies..."
pip install -q "ctranslate2>=4.3" "transformers[torch]" accelerate sentencepiece safetensors

echo "==> Converting ${MODEL_ID} -> ${OUT_DIR}"
python -m ctranslate2.converters.transformers \
  --model "${MODEL_ID}" \
  --output_dir "${OUT_DIR}" \
  --copy_files tokenizer.json preprocessor_config.json special_tokens_map.json tokenizer_config.json \
  --quantization int8 \
  --force

echo "==> Ensuring tokenizer and preprocessor configs exist"
MODEL_ID="${MODEL_ID}" OUT_DIR="${OUT_DIR}" python - <<'PY'
from pathlib import Path
import os

from transformers import AutoFeatureExtractor, AutoTokenizer

model_id = os.environ["MODEL_ID"]
out_dir = os.environ["OUT_DIR"]
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
tar -czf "${ARCHIVE}" -C "${OUT_ROOT}" "whisper-${MODEL_VARIANT}-ct2"

echo ""
echo "Done! Files written to ${OUT_DIR}:"
ls -lh "${OUT_DIR}"
echo ""
echo "Archive ready: ${ARCHIVE}"
ls -lh "${ARCHIVE}"
