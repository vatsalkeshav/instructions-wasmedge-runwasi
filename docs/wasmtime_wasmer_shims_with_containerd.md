# Instructions for Setting Up runwasi-wasmtime/wasmer with example

## Install Dependencies

```sh
# installable by apt
sudo apt update && sudo apt upgrade -y && sudo apt install -y llvm-14-dev liblld-14-dev software-properties-common gcc g++ asciinema containerd cmake zlib1g-dev build-essential python3 python3-dev python3-pip git

# rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && source $HOME/.cargo/env
```

## Step 2 : Build and Test Runwasi

Build Runwasi
```sh
# Build Runwasi
cd
git clone https://github.com/containerd/runwasi.git
cd runwasi
./scripts/setup-linux.sh
make build-wasmtime

# install system-wide
sudo cp /home/dev/runwasi/target/aarch64-unknown-linux-gnu/debug/containerd-shim-wasmtime-v1 /usr/local/bin/
sudo chmod 777 /usr/local/bin/containerd-shim-wasmtime-v1

# configure containerd for runwasi's wasmtime shim
sudo mkdir -p /etc/containerd

containerd config default | sudo tee /etc/containerd/config.toml >/dev/null

# specify the binary name(path) too
sudo sed -i '/\[plugins\."io\.containerd\.grpc\.v1\.cri"\.containerd\.runtimes\]/a \
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.wasmtime]\
    runtime_type = "io.containerd.wasmtime.v1"\
    binary_name = "/usr/local/bin/containerd-shim-wasmtime-v1"\
' /etc/containerd/config.toml

# Verify Correct Config
sudo cat /etc/containerd/config.toml | grep -A 3 "wasmedge"

# Test the wasmtime shim

# stop-start containerd
sudo systemctl stop containerd
sudo systemctl start containerd

# Pull and Run the Song image
cd

sudo ctr images pull ghcr.io/containerd/runwasi/wasi-demo-app:latest

sudo ctr run --rm --runtime=io.containerd.wasmedge.v1 \
  ghcr.io/containerd/runwasi/wasi-demo-app:latest \
  testwasm

sudo ctr task kill -s SIGKILL testwasm # in another terminal - to stop the song that never ends (or use ctrl+c)
```
