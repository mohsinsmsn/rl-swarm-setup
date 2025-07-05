#!/bin/bash

set -e

echo ">> Updating system packages..."
sudo apt update && sudo apt install -y python3 python3-venv python3-pip curl wget screen git lsof gnupg

echo ">> Installing and configuring UFW..."
sudo apt install -y ufw
sudo ufw allow 22
sudo ufw allow 3000/tcp
echo y | sudo ufw enable

echo ">> Installing cloudflared..."
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb

echo ">> Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt update && sudo apt install -y nodejs

echo ">> Installing Yarn (modern key method)..."
sudo mkdir -p /etc/apt/keyrings
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | sudo tee /etc/apt/keyrings/yarn.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/yarn.gpg] https://dl.yarnpkg.com/debian/ stable main" | \
    sudo tee /etc/apt/sources.list.d/yarn.list > /dev/null
sudo apt update && sudo apt install -y yarn

# Clone rl-swarm if not already present
if [ -d "rl-swarm" ]; then
  echo "⚠️  Directory 'rl-swarm' already exists. Skipping clone."
  echo "👉  If this is an error, remove it manually with: rm -rf rl-swarm"
else
  echo ">> Cloning rl-swarm repository..."
  git clone https://github.com/gensyn-ai/rl-swarm.git
fi

echo ">> Launching Gensyn node in a detached screen session (name: Gensyn)..."
screen -dmS Gensyn bash -c "
cd rl-swarm && \
python3 -m venv .venv && \
source .venv/bin/activate && \
./run_rl_swarm.sh 2>&1 | tee swarm.log
"

echo "✅ Gensyn setup complete."
echo "📺 To view the node logs, run: screen -r Gensyn"
echo "💾 Log is also saved to: rl-swarm/swarm.log"
