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

TARGET_FILE="$HOME/rl-swarm/modal-login/app/page.tsx"

USE_EFFECT_BLOCK='  useEffect(() => {
    if (!user && !signerStatus.isInitializing) {
      openAuthModal();
    }
  }, [user, signerStatus.isInitializing]);

'

echo "🔧 Checking if auth-modal useEffect is already placed before return()..."

# Check only lines near `return` block to see if patch was already inserted
if awk '/^  return \(/ { found_return=1 } found_return && /openAuthModal\(\)/ { found_patch=1 } END { exit !found_patch }' "$TARGET_FILE"; then
  echo "ℹ️ useEffect near return already present. Skipping insertion."
else
  echo "✍️ Inserting useEffect near return block..."
  awk -v insert="$USE_EFFECT_BLOCK" '
    BEGIN { inserted = 0 }
    {
      if (!inserted && $0 ~ /^  return \(/) {
        print insert;
        inserted = 1;
      }
      print $0;
    }
  ' "$TARGET_FILE" > "${TARGET_FILE}.tmp" && mv "${TARGET_FILE}.tmp" "$TARGET_FILE"
  echo "✅ useEffect inserted successfully before return block."
fi
