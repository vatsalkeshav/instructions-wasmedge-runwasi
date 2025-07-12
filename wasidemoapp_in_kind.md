## Steps for running wasi-demo-app in Kind (following README.md)
in Orbstack's Ubuntu:22.04 vm on Mac M1

### 1. Docker Installation
```sh

# install dependencies
sudo apt update && sudo apt upgrade -y
sudo apt install -y ca-certificates curl gnupg lsb-release

# add docker’s official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# set up the docker repo
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# install docker engine
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# verify
sudo docker run hello-world

# to run Docker w/o sudo
sudo usermod -aG docker $USER

# enable Docker to start on Boot
sudo systemctl enable docker

# reboot to rock effect
sudo reboot
```
```sh
orb
```

## 2. Kubctl Installation
```sh
# add Kubernetes repo
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# install kubectl
sudo apt-get update
sudo apt-get install -y kubectl
```

## 3. Kind Installtion
```sh
# install kind (Linux/arm64 binary)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.27.0/kind-linux-arm64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/
# to uninstall:
# sudo rm -fr /usr/local/bin/kind

# verify
kind version
```

## 4. YAML to mount the WasmEdge shim into the cluster
```sh
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
kind create cluster --config kind-wasm.yaml
```

## 5. Configure Containerd to utilize Runwasi's `containerd-shim-wasmedge-v1`
```sh
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
```

## 6. Deploy the Wasm Workload
```sh
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
kubectl apply -f wasmedge-deploy.yaml

# verify
kubectl get pods
kubectl logs -l app=wasi-demo
# o/p :
# This is a song that never ends.
# Yes, it goes on and on my friends.
# Some people started singing it not knowing what it was,
# So they'll continue singing it forever just because...
#
# This is a song that never ends.
# Yes, it goes on and on my friends.
# Some people started singing it not knowing what it was,
# So they'll continue singing it forever just because...
```
