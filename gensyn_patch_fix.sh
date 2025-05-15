#!/bin/bash

echo "🔧 Fixing batch size and training settings in grp*.yaml..."

cd "$HOME/rl-swarm/hivemind_exp/configs/mac/" || {
  echo "❌ Could not navigate to yaml config directory."
  exit 1
}

# Update values in all grp*.yaml files
for file in grp*.yaml; do
  echo "📁 Processing $file..."
  sed -i 's/torch_dtype:.*/torch_dtype: float32/' "$file"
  sed -i 's/bf16:.*/bf16: false/' "$file"
  sed -i 's/tf32:.*/tf32: false/' "$file"
  sed -i 's/gradient_checkpointing:.*/gradient_checkpointing: false/' "$file"
  sed -i 's/per_device_train_batch_size:.*/per_device_train_batch_size: 1/' "$file"
done

echo "✅ Batch config patch completed."

echo ""
echo "🔧 Replacing page.tsx file with patched version from GitHub..."

PAGE_PATH="$HOME/rl-swarm/modal-login/app/page.tsx"
curl -fsSL https://raw.githubusercontent.com/mohsinsmsn/rl-swarm-setup/refs/heads/main/page.tsx -o "$PAGE_PATH"

if [ $? -eq 0 ]; then
  echo "✅ page.tsx replaced successfully."
else
  echo "❌ Failed to download page.tsx from GitHub."
fi

echo ""
echo "🎉 All patches applied successfully."
