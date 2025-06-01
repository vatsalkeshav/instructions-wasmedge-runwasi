New Steps for Kind+Docker+kubectl+neverendingsong (following README.md)

1. Docker
```bash

# Update/Install dependencies
sudo apt update && sudo apt upgrade -y
sudo apt install -y ca-certificates curl gnupg lsb-release

# Add Docker’s Official GPG Key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set Up the Docker Repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Verify Docker Installation
sudo docker run hello-world

# Run Docker Without sudo
sudo usermod -aG docker $USER

# Enable Docker to Start on Boot
sudo systemctl enable docker

# reboot to rock effect
sudo reboot
orb
```

2. Kubctl
```bash
# Add Kubernetes repo
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Install kubectl
sudo apt-get update
sudo apt-get install -y kubectl
```

3. Kind
```bash
# Install Kind (Linux/arm64 binary)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.27.0/kind-linux-arm64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/

# Verify installation
kind version

# Create a Kind config file to mount the WasmEdge shim into the cluster
cat <<EOF > kind-wasm.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: wasm-cluster
nodes:
- role: control-plane
  extraMounts:
  - hostPath: /usr/local/bin/containerd-shim-wasmedge-v1
    containerPath: /usr/local/bin/containerd-shim-wasmedge-v1
EOF

# Create kind cluster with wasmedge support
kind create cluster --config kind-wasm.yaml

# . . . Configure containerd in Kind . . .
# Connect to the Kind node's shell
docker exec -it wasm-cluster-control-plane bash

# Inside the node, edit containerd config
cat > /etc/containerd/config.toml <<EOF
[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.wasmedge]
  runtime_type = "io.containerd.wasmedge.v1"
EOF

# Restart containerd
systemctl restart containerd
exit

# . . . Deploy the Wasm Workload . . .
# Apply the RuntimeClass and deployment
cat <<EOF > wasmedge-deploy.yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: wasmedge
handler: wasmedge
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wasi-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wasi-demo
  template:
    metadata:
      labels:
        app: wasi-demo
    spec:
      runtimeClassName: wasmedge
      containers:
      - name: demo
        image: ghcr.io/containerd/runwasi/wasi-demo-app:latest
EOF

# Deploy
kubectl apply -f wasmedge-deploy.yaml

# . . . Verify the Deployment . . .
# Check the pod status and logs
kubectl get pods
kubectl logs -l app=wasi-demo

# Expected output:
This is a song that never ends.
Yes, it goes on and on my friends.
Some people started singing it not knowing what it was,
So they'll continue singing it forever just because...
```