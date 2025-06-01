## Testing before k8s
```sh

# 0
sudo apt update && sudo apt upgrade -y && sudo apt install -y llvm-14-dev liblld-14-dev software-properties-common gcc g++ asciinema containerd cmake zlib1g-dev build-essential python3 python3-dev python3-pip git clang

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && source $HOME/.cargo/env
rustup target add wasm32-wasip1

cd
git clone https://github.com/containerd/runwasi.git
cd runwasi
./scripts/setup-linux.sh
make build-wasmedge
INSTALL="sudo install" LN="sudo ln -sf" make install-wasmedge

sudo mkdir -p /etc/containerd
mkdir -p /usr/local/bin
sudo install ./target/aarch64-unknown-linux-gnu/debug/containerd-shim-wasmedge-v1 /usr/local/bin/
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i '/\[plugins\."io\.containerd\.grpc\.v1\.cri"\.containerd\.runtimes\]/a \
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.wasmedge]\
    runtime_type = "io.containerd.wasmedge.v1"\
' /etc/containerd/config.toml
sudo cat /etc/containerd/config.toml | grep -A 3 "wasmedge"
sudo systemctl stop containerd
sudo systemctl start containerd

cd
git clone --recurse-submodules https://github.com/second-state/runwasi-wasmedge-demo.git
cd
cd runwasi-wasmedge-demo
rm -fr Makefile
touch Makefile
sudo tee ./Makefile > /dev/null <<'EOF'
CONTAINERD_NAMESPACE ?= default
LLAMAEDGE_SERVICE = llama-api-server # apps/llamaedge/llama-api-server 

OPT_PROFILE ?= debug
RELEASE_FLAG :=
ifeq ($(OPT_PROFILE),release)
RELEASE_FLAG = --release
endif

define CHECK_RUST_TOOLS
	@command -v cargo-get >/dev/null 2>&1 || { \
		echo "cargo-get not found, installing..."; \
		cargo install cargo-get; \
	}
	@command -v oci-tar-builder >/dev/null 2>&1 || { \
		echo "oci-tar-builder not found, installing..."; \
		cargo install oci-tar-builder; \
	}
endef

# define CHECK_CONTAINERD_VERSION
# 	@CTR_VERSION=$$(sudo ctr version | sed -n -e '/Version/ {s/.*: *//p;q;}'); \
# 	if ! printf '%s\n%s\n%s\n' "$$CTR_VERSION" "v1.7.7" "v1.6.25" | sort -V | tail -1 | grep -qx "$$CTR_VERSION"; then \
# 		echo "Containerd version must be v1.7.7+ or v1.6.25+, but detected $$CTR_VERSION"; \
# 		exit 1; \
# 	fi
# endef

define CHECK_CONTAINERD_VERSION
	@CTR_VERSION=$$(sudo ctr version | sed -n -e '/Version/ {s/.*: *//p;q;}'); \
	if ! printf '%s\n%s\n%s\n' "$$CTR_VERSION" "v1.7.7" "v1.6.25" | sort -V | tail -1 | grep -qx "$$CTR_VERSION"; then \
		echo "WARNING: Containerd version should be v1.7.7+ or v1.6.25+, but detected $$CTR_VERSION"; \
	fi
endef

.PHONY: .FORCE
.FORCE:

%.wasm: .FORCE
	@PACKAGE_PATH=$(firstword $(subst /target/, ,$@)) && \
	echo "Build WASM from $$PACKAGE_PATH" && \
	cd $$PACKAGE_PATH && cargo build --target-dir ./target --target=wasm32-wasip1 $(RELEASE_FLAG)

apps/%/img-oci.tar: apps/%/*.wasm
	$(CHECK_RUST_TOOLS)
	@PACKAGE_PATH=$(firstword $(subst /target/, ,$@)) && \
	PACKAGE_NAME=$$(cd $$PACKAGE_PATH && cargo-get package.name) && \
	echo "Build OCI image from $$PACKAGE_PATH" && \
	cd $$PACKAGE_PATH && \
	oci-tar-builder --name $$PACKAGE_NAME --repo ghcr.io/second-state --tag latest --module target/wasm32-wasip1/$(OPT_PROFILE)/$$PACKAGE_NAME.wasm -o target/wasm32-wasip1/$(OPT_PROFILE)/img-oci.tar

.DEFAULT_GOAL := all
all: $(LLAMAEDGE_SERVICE)/target/wasm32-wasip1/$(OPT_PROFILE)/img-oci.tar
	$(CHECK_CONTAINERD_VERSION)
	$(foreach var,$^,\
		sudo ctr -n $(CONTAINERD_NAMESPACE) image import --all-platforms $(var);\
	)

%: %/target/wasm32-wasip1/$(OPT_PROFILE)/img-oci.tar
	$(CHECK_CONTAINERD_VERSION)
	sudo ctr -n $(CONTAINERD_NAMESPACE) image import --all-platforms $<

.PHONY: clean

clean:
	@echo "Remove all imported OCI images from Contained."
	@sudo ctr image ls -q | grep '^ghcr.io/second-state' | xargs -n 1 sudo ctr images rm
	@echo "Remove all built WASM files."
	@find . -type d -name 'target' | xargs rm -rf

EOF

# 1
git -C apps/llamaedge apply $PWD/disable_wasi_logging.patch

# 2
OPT_PROFILE=release RUSTFLAGS="--cfg wasmedge --cfg tokio_unstable" make apps/llamaedge/llama-api-server

# rethink below command
sudo ctr -n default image import --all-platforms apps/llamaedge/llama-api-server/target/wasm32-wasip1/release/img-oci.tar

# rm apps/llamaedge/llama-api-server/target/wasm32-wasip1/release/img-oci.tar
sudo ctr images ls # verify

# 3
curl -sSf https://raw.githubusercontent.com/WasmEdge/WasmEdge/master/utils/install.sh | bash -s -- --plugins wasi_nn-ggml -v 0.14.1
./inject_dependencise.sh ~/.wasmedge/plugin/libwasmedgePluginWasiNN.so /opt/containerd/lib
source $HOME/.bashrc

# 4
curl -LO https://huggingface.co/second-state/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q5_K_M.gguf

# 5
sudo ctr run --rm --runtime=io.containerd.wasmedge.v1 \
  --net-host \
  --mount type=bind,src=/opt/containerd/lib,dst=/opt/containerd/lib,options=bind:ro \
  --env WASMEDGE_PLUGIN_PATH=/opt/containerd/lib \
  --mount type=bind,src=$PWD,dst=/resource,options=bind:ro \
  --env WASMEDGE_WASINN_PRELOAD=default:GGML:CPU:/resource/Llama-3.2-1B-Instruct-Q5_K_M.gguf \
  ghcr.io/second-state/llama-api-server:latest testggml llama-api-server.wasm \
  --prompt-template llama-3-chat \
  --ctx-size 4096 \
  --model-name llama-3-1b

# 6
curl -X POST http://localhost:8080/v1/chat/completions \
    -H 'accept:application/json' \
    -H 'Content-Type: application/json' \
    -d '{"messages":[{"role":"system", "content": "You are a helpful assistant."}, {"role":"user", "content": "Who is Robert Oppenheimer?"}], "model":"llama-3-8b"}'

```

## If a specific version of containerd is needed
```sh
# containerd installation ( if still required )
sudo apt install -y wget
mkdir cont-new && cd cont-new
wget https://github.com/containerd/containerd/releases/download/v2.1.0/containerd-2.1.0-linux-arm64.tar.gz
wget https://github.com/containerd/containerd/releases/download/v2.1.0/containerd-2.1.0-linux-arm64.tar.gz.sha256sum
sha256sum -c containerd-2.1.0-linux-arm64.tar.gz.sha256sum
sudo tar Cxzvf /usr/local containerd-2.1.0-linux-arm64.tar.gz
exec $SHELL
containerd -v

```