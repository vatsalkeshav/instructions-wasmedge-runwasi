# Instructions for Setting Up runwasi-wasmedge-containerd-crun

### On orbStack VM ubuntu 22.04(Jammy Jellyfish) on Mac M1

## Step 1 : Build WasmEdge

```sh
# as guided by wasmedge docs
sudo apt install -y llvm-14-dev liblld-14-dev software-properties-common gcc g++

# as guided by self-exploration
sudo apt install -y cmake zlib1g-dev build-essential python3 python3-dev python3-pip git

# install rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# build wasmedge
git clone https://github.com/WasmEdge/WasmEdge.git
cd WasmEdge
mkdir -p build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DWASMEDGE_BUILD_TESTS=OFF .. && make -j2 # Note the tests are off and "make -j2" is used instead of "make -j"

#verify
./tools/wasmedge/wasmedge --version
./tools/wasmedgec/wasmedgec --version

#install system-wide
sudo make install
wasmedge --version
wasmedgec --version
```

## Step 2 : Build and Test Runwasi

```sh
# build runwasi
git clone https://github.com/containerd/runwasi.git
cd runwasi
./scripts/setup-linux.sh
make build-wasmedge

# install runwasi - opt a - this may or may not work
INSTALL="sudo install" LN="sudo ln -sf" make install-wasmedge
# should show :
# mkdir -p /usr/local/bin
# sudo install ./target/aarch64-unknown-linux-gnu/debug/containerd-shim-wasmedge-v1 /usr/local/bin/

# check installation
sudo ls /usr/local/bin/containerd-shim-wasmedge-v1
# should show :
# /usr/local/bin/containerd-shim-wasmedge-v1


# install runwasi - opt b - use if opt a does not work
cd ~/runwasi
INSTALL="sudo install" LN="sudo ln -sf" make install-wasmedge

containerd config default | sudo tee /etc/containerd/config.toml >/dev/null

sudo sed -i '/\[plugins\."io\.containerd\.grpc\.v1\.cri"\.containerd\.runtimes\]/a \
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.wasmedge]\
    runtime_type = "io.containerd.wasmedge.v1"\
' /etc/containerd/config.toml

# Verify Correct Config
sudo cat /etc/containerd/config.toml | grep -A 3 "wasmedge"
# should show :
#[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.wasmedge]
#   runtime_type = "io.containerd.wasmedge.v1"

# stop-start containerd
sudo systemctl stop containerd
sudo systemctl start containerd

# test
cd

sudo ctr images pull ghcr.io/containerd/runwasi/wasi-demo-app:latest

sudo ctr run --rm --runtime=io.containerd.wasmedge.v1 \
  ghcr.io/containerd/runwasi/wasi-demo-app:latest \
  testwasm

sudo ctr task kill -s SIGKILL testwasm # to stop the song that never ends (or use ctrl+c)
```

## Step 3 : Build and Test Rust Webassembly application using Wasmedge

```sh
# build
git clone https://github.com/vatsalkeshav/WASMathician.git
cd wasm-calculator
rustup target add wasm32-wasip1
cargo build --target wasm32-wasip1 --release
wasmedgec target/wasm32-wasip1/release/wasm-calculator.wasm calculator.wasm

# usage
wasmedge target/wasm32-wasip1/release/wasm-calculator.wasm
# or
wasmedge calculator.wasm
```