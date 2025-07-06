sudo apt update && sudo apt upgrade -y && sudo apt install -y llvm-14-dev liblld-14-dev software-properties-common gcc g++ asciinema containerd cmake zlib1g-dev build-essential python3 python3-dev python3-pip git clang

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && source $HOME/.cargo/env
rustup target add wasm32-wasip1 # wasm32-wasip1 specifies that at the end, binary is to be of wasm type

curl -sSf https://raw.githubusercontent.com/WasmEdge/WasmEdge/master/utils/install.sh | bash -s -- --plugins wasi_nn-ggml -v 0.14.1
source /home/dev/.bashrc

cd
git clone https://github.com/containerd/runwasi.git
cd runwasi
./scripts/setup-linux.sh
make build-wasmedge

INSTALL="sudo install" LN="sudo ln -sf" make install-wasmedge
mkdir -p /usr/local/bin
sudo install ./target/aarch64-unknown-linux-gnu/debug/containerd-shim-wasmedge-v1 /usr/local/bin/

# configure containerd for runwasi's wasmedge shim
sudo mkdir -p /etc/containerd

containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i '/\[plugins\."io\.containerd\.grpc\.v1\.cri"\.containerd\.runtimes\]/a \
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.wasmedge]\
    runtime_type = "io.containerd.wasmedge.v1"\
' /etc/containerd/config.toml

sudo cat /etc/containerd/config.toml | grep -A 3 "wasmedge"

sudo systemctl stop containerd
sudo systemctl start containerd

#kind
[ $(uname -m) = aarch64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.29.0/kind-linux-arm64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind