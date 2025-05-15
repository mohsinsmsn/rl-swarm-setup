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

echo "🔧 Inserting useEffect to open auth modal in page.tsx..."

PAGE_FILE="$HOME/rl-swarm/modal-login/app/page.tsx"

# Only insert if not already present
if ! grep -q 'openAuthModal();' "$PAGE_FILE"; then
  awk '
  /return\s*\(/ && !patched {
    print "  useEffect(() => {\n    if (!user && !signerStatus.isInitializing) {\n      openAuthModal();\n    }\n  }, [user, signerStatus.isInitializing]);\n"
    patched=1
  }
  { print }
  ' "$PAGE_FILE" > "${PAGE_FILE}.tmp" && mv "${PAGE_FILE}.tmp" "$PAGE_FILE"

  echo "✅ useEffect inserted into page.tsx"
else
  echo "ℹ️ useEffect already exists in page.tsx, skipping."
fi

echo "🎉 All patches applied successfully."
