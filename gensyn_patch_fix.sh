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

PAGE_FILE="$HOME/rl-swarm/modal-login/app/page.tsx"

if [[ ! -f "$PAGE_FILE" ]]; then
  echo "❌ Error: File not found at $PAGE_FILE"
  exit 1
fi

# The block to insert
INSERT_BLOCK='
  useEffect(() => {
    if (!user && !signerStatus.isInitializing) {
      openAuthModal();
    }
  }, [user, signerStatus.isInitializing]);
'

# Check if it's already present
if grep -q 'if (!user && !signerStatus.isInitializing)' "$PAGE_FILE"; then
  echo "ℹ️ useEffect block already inserted. Skipping."
  exit 0
fi

# Insert after the crypto.subtle block
awk -v insert="$INSERT_BLOCK" '
/typeof window.crypto.subtle !== "object"/ {
  found = 1
}
found && /\}\), \[\]\);/ {
  print $0
  print insert
  found = 0
  next
}
{ print $0 }
' "$PAGE_FILE" > "${PAGE_FILE}.tmp" && mv "${PAGE_FILE}.tmp" "$PAGE_FILE"

echo "✅ useEffect block inserted after crypto check."
