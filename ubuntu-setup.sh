#!/bin/bash

# Instructions for Setting Up runwasi-wasmedge with example
# On orbStack VM ubuntu 22.04(Jammy Jellyfish) on Mac M1

set -e  # Exit on error

echo "=== Installing dependencies ==="
# installable by apt
sudo apt update && sudo apt upgrade -y && sudo apt install -y llvm-14-dev liblld-14-dev software-properties-common gcc g++ asciinema containerd cmake zlib1g-dev build-essential python3 python3-dev python3-pip git

# rust
echo "=== Installing Rust ==="
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source $HOME/.cargo/env
. "$HOME/.cargo/env"

echo "=== Building WasmEdge ==="
# build wasmedge
git clone https://github.com/WasmEdge/WasmEdge.git
cd WasmEdge
mkdir -p build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DWASMEDGE_BUILD_TESTS=OFF .. && make -j2  # Reduced parallelism for M1

# install wasmedge system-wide
sudo make install
cd ../..

# verify
echo "=== Verifying WasmEdge installation ==="
wasmedge --version
wasmedgec --version

echo "=== Building and installing runwasi ==="
# Build Runwasi
git clone https://github.com/containerd/runwasi.git
cd runwasi
./scripts/setup-linux.sh
make build-wasmedge # make build-wasmtime / make build-wasmer

# install system-wide
INSTALL="sudo install" LN="sudo ln -sf" make install-wasmedge # make install-wasmtime / make install-wasmer

echo "=== Configuring containerd for runwasi's wasmedge shim ==="
# configure containerd for runwasi's wasmedge shim
sudo mkdir -p /etc/containerd

containerd config default | sudo tee /etc/containerd/config.toml >/dev/null

# wasmtime/wasmer/wasmedge shim configuration
sudo sed -i '/\[plugins\."io\.containerd\.grpc\.v1\.cri"\.containerd\.runtimes\]/a \
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.wasmedge]\ 
    runtime_type = "io.containerd.wasmedge.v1"\
' /etc/containerd/config.toml

echo "=== Containerd configuration ==="
# Verify Correct Config
sudo cat /etc/containerd/config.toml | grep -A 3 "wasmedge"

echo "=== Restarting containerd ==="
# stop-start containerd
sudo systemctl stop containerd
sudo systemctl start containerd

echo "=== Setup completed successfully! ==="