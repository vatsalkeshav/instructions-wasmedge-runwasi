# Instructions for Setting Up runwasi-wasmedge with example

### On orbStack VM ubuntu 22.04(Jammy Jellyfish) on Mac M1

## Install Dependencies

```sh
# installable by apt
sudo apt update && sudo apt upgrade -y && sudo apt install -y llvm-14-dev liblld-14-dev software-properties-common gcc g++ asciinema containerd cmake zlib1g-dev build-essential python3 python3-dev python3-pip git

# rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && source $HOME/.cargo/env && . "$HOME/.cargo/env"
```

## Step 1 : Build WasmEdge

```sh
# build wasmedge
git clone https://github.com/WasmEdge/WasmEdge.git
cd WasmEdge
mkdir -p build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DWASMEDGE_BUILD_TESTS=OFF .. && make -j2 # tests are off for quicker compilation and "make -j2" is used instead of "make -j" to reduce load on machine

# install wasmedge system-wide
sudo make install

# verify
wasmedge --version
wasmedgec --version
```

## Step 2 : Build and Test Runwasi

Build Runwasi
```sh
# Build Runwasi
cd
git clone https://github.com/containerd/runwasi.git
cd runwasi
./scripts/setup-linux.sh
make build-wasmedge

# install system-wide
INSTALL="sudo install" LN="sudo ln -sf" make install-wasmedge
# maybe equivalent to : 
mkdir -p /usr/local/bin
sudo install ./target/aarch64-unknown-linux-gnu/debug/containerd-shim-wasmedge-v1 /usr/local/bin/

# configure containerd for runwasi's wasmedge shim
sudo mkdir -p /etc/containerd

containerd config default | sudo tee /etc/containerd/config.toml >/dev/null

sudo sed -i '/\[plugins\."io\.containerd\.grpc\.v1\.cri"\.containerd\.runtimes\]/a \
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.wasmedge]\
    runtime_type = "io.containerd.wasmedge.v1"\
' /etc/containerd/config.toml

# Verify Correct Config
sudo cat /etc/containerd/config.toml | grep -A 3 "wasmedge"

# Test the Runwasi's WasmEdge shim

# stop-start containerd
sudo systemctl stop containerd
sudo systemctl start containerd

# Test the setup - Pull and Run the Song image
cd

sudo ctr images pull ghcr.io/containerd/runwasi/wasi-demo-app:latest

sudo ctr run --rm --runtime=io.containerd.wasmedge.v1 \
  ghcr.io/containerd/runwasi/wasi-demo-app:latest \
  testwasm

sudo ctr task kill -s SIGKILL testwasm # to stop the song that never ends (or use ctrl+c)
```

## Step 3 : Build and Test Rust Webassembly application using Wasmedge

Build WASMathecian
```sh
git clone https://github.com/vatsalkeshav/WASMathician.git

cd WASMathician

rustup target add wasm32-wasip1

cargo build --target wasm32-wasip1 --release
```

Test with WasmEdge
```sh
wasmedgec target/wasm32-wasip1/release/wasm-calculator.wasm calculator.wasm

wasmedge target/wasm32-wasip1/release/wasm-calculator.wasm

wasmedge calculator.wasm
```