#!/bin/bash

echo "🔧 Fixing batch size and training settings in grp*.yaml..."

CONFIG_DIR="$HOME/rl-swarm/hivemind_exp/configs/mac"
PATCHED_KEYS=(
  "torch_dtype: float32"
  "bf16: false"
  "tf32: false"
  "gradient_checkpointing: false"
  "per_device_train_batch_size: 1"
)

for yaml_file in "$CONFIG_DIR"/grp*.yaml; do
  echo "📁 Processing $(basename "$yaml_file")..."

  # Replace or append each key
  for key in "${PATCHED_KEYS[@]}"; do
    key_name=$(echo "$key" | cut -d: -f1)
    if grep -q "^$key_name:" "$yaml_file"; then
      sed -i "s|^$key_name:.*|$key|" "$yaml_file"
    else
      echo "$key" >> "$yaml_file"
    fi
  done

  echo "✅ Batch config patch completed."
done
