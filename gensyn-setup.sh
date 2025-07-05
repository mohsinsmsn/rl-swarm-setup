#!/bin/bash

set -e

echo ">> Updating system packages..."
sudo apt update && sudo apt install -y python3 python3-venv python3-pip curl wget screen git lsof

echo ">> Installing UFW and opening required ports..."
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

echo ">> Installing Yarn..."
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list > /dev/null
sudo apt update && sudo apt install -y yarn

echo ">> Cloning rl-swarm repository..."
git clone https://github.com/gensyn-ai/rl-swarm.git

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
