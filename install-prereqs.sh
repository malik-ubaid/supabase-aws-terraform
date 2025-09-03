#!/bin/bash
set -e

echo "🔧 Installing Prerequisites for Supabase CDKTF Deployment"
echo "=========================================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📦 Updating system packages...${NC}"
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y curl unzip gnupg software-properties-common apt-transport-https ca-certificates lsb-release

# ---------------------------
# Install Python 3.9+ and pip
# ---------------------------
echo -e "${BLUE}🐍 Installing Python 3.9+...${NC}"
sudo apt-get install -y python3 python3-pip python3-venv
python3 --version
pip3 --version

# ---------------------------
# Install Node.js 18+
# ---------------------------
echo -e "${BLUE}🟢 Installing Node.js 18+...${NC}"
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
node --version
npm --version

# ---------------------------
# Install AWS CLI v2
# ---------------------------
echo -e "${BLUE}☁️  Installing AWS CLI v2...${NC}"
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install --update
rm -rf aws awscliv2.zip
aws --version

# ---------------------------
# Install kubectl (latest stable with fallback)
# ---------------------------
echo -e "${BLUE}☸️  Installing kubectl...${NC}"
KUBECTL_VERSION=$(curl -Ls https://dl.k8s.io/release/stable.txt)

if [ -z "$KUBECTL_VERSION" ]; then
    echo -e "${YELLOW}⚠️  Could not fetch latest version, falling back to v1.29.0${NC}"
    KUBECTL_VERSION="v1.29.0"
fi

curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl
kubectl version --client

# ---------------------------
# Install Helm 3
# ---------------------------
echo -e "${BLUE}⎈ Installing Helm 3...${NC}"
curl https://baltocdn.com/helm/signing.asc | sudo gpg --dearmor -o /usr/share/keyrings/helm.gpg
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | \
    sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update -y
sudo apt-get install -y helm
helm version

# ---------------------------
# Install Terraform CLI
# ---------------------------
echo -e "${BLUE}🏗️  Installing Terraform CLI...${NC}"
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update -y
sudo apt-get install -y terraform
terraform version

# ---------------------------
# Install CDKTF CLI
# ---------------------------
echo -e "${BLUE}📦 Installing CDKTF CLI...${NC}"
sudo npm install -g cdktf-cli@latest
cdktf --version

# ---------------------------
# Install Python requirements if present
# ---------------------------
if [ -f "requirements.txt" ]; then
    echo -e "${BLUE}📚 Installing Python dependencies...${NC}"
    pip3 install -r requirements.txt
fi

echo -e "${GREEN}✅ All prerequisites installed successfully!${NC}"
echo ""
echo -e "${YELLOW}⚠️  Next: run 'aws configure' to set up your AWS credentials${NC}"

