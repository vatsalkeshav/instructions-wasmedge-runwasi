# Running the *"wasmedge - wasmedge plugin - llamaedge - runwasi's wasmedge shim"* demo outside k8s

## 1. Install dependencies
```sh
# step 0 - installing dependencies
sudo apt update && sudo apt upgrade -y && sudo apt install -y llvm-14-dev liblld-14-dev software-properties-common gcc g++ asciinema containerd cmake zlib1g-dev build-essential python3 python3-dev python3-pip git clang crun

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && source $HOME/.cargo/env
rustup target add wasm32-wasip1 # wasm32-wasip1 specifies that at the end, binary is to be of wasm type
```

## 2. building and installing wasmedge-shim for containerd

  1. *wasmedge shim can be thought of (but not exactly) as a containerd runtime (like crun, runc) that spins up sandboxed WASM (WebAssembly) applications ( like / ) instead of traditional containers*

  2. *And Runwasi is builds these shims*

```sh
# building
cd
git clone https://github.com/containerd/runwasi.git
cd runwasi
./scripts/setup-linux.sh
make build-wasmedge

# placing the binary(wasmedge shim files) in the right place
INSTALL="sudo install" LN="sudo ln -sf" make install-wasmedge
# maybe equivalent to :
sudo install ./target/aarch64-unknown-linux-gnu/debug/containerd-shim-wasmedge-v1 /usr/local/bin/

# configuring containerd to run wasm applications instead of traditional containers
sudo mkdir -p /etc/containerd
mkdir -p /usr/local/bin
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i '/\[plugins\."io\.containerd\.grpc\.v1\.cri"\.containerd\.runtimes\]/a \
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.wasmedge]\
    runtime_type = "io.containerd.wasmedge.v1"\
' /etc/containerd/config.toml

# verify containerd configuration
sudo cat /etc/containerd/config.toml | grep -A 3 "wasmedge"
# output :
#   [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.wasmedge]
#    runtime_type = "io.containerd.wasmedge.v1"

# stop-start (restart) containerd
sudo systemctl stop containerd
sudo systemctl start containerd
```

## 3. the main app

*__this is a demo that shows wasmedge's plugin WASI-NN__*

__*WASI-NN or other wasmedge plugins are there to run stuff too big to be compiled to a single wasm binary*__

secret - I too am kind of hazy on how this works

*__Here's how to make it work :__*

0. cloning repo and tweaking the Makefile to reduce errors
```sh
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

```


1. Manually removed the dependency on wasi_logging due to issue [#4003](https://github.com/WasmEdge/WasmEdge/issues/4003).

```bash
git -C apps/llamaedge apply $PWD/disable_wasi_logging.patch
```

2. Build and import demo image

```bash
OPT_PROFILE=release RUSTFLAGS="--cfg wasmedge --cfg tokio_unstable" make apps/llamaedge/llama-api-server
# above command also places this image in containerd's local store - equivalent to this :
# sudo ctr -n default image import --all-platforms apps/llamaedge/llama-api-server/target/wasm32-wasip1/release/img-oci.tar

# verify
sudo ctr images ls 
# output :
# REF                                            TYPE                                         DIGEST                                                                    SIZE       PLATFORMS     LABELS
# ghcr.io/second-state/llama-api-server:latest   application/vnd.oci.image.manifest.v1+json   sha256:7567d37d5b0176861cdaf4b6d01027895811f4324b49d2d787930a06163a1afe   11.2 MiB   wasip1/wasm   -

```

3. Download the WasmEdge plugin from the installer *__and place it, along with its dependent libraries, into containerd's LD_LIBRARY_PATH ( using inject_dependencise.sh )__*

```bash
curl -sSf https://raw.githubusercontent.com/WasmEdge/WasmEdge/master/utils/install.sh | bash -s -- --plugins wasi_nn-ggml -v 0.14.1
source $HOME/.bashrc

./inject_dependencise.sh ~/.wasmedge/plugin/libwasmedgePluginWasiNN.so /opt/containerd/lib
```

4. Download LLM model

```bash
curl -LO https://huggingface.co/second-state/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q5_K_M.gguf
```

5. Run llama-api-server

```bash
sudo ctr run --rm --runtime=io.containerd.wasmedge.v1 \
  --net-host \
  --mount type=bind,src=/opt/containerd/lib,dst=/opt/containerd/lib,options=bind:ro \
  --env WASMEDGE_PLUGIN_PATH=/opt/containerd/lib \
  --mount type=bind,src=$PWD,dst=/resource,options=bind:ro \
  --env WASMEDGE_WASINN_PRELOAD=default:GGML:CPU:/resource/Llama-3.2-1B-Instruct-Q5_K_M.gguf \
  ghcr.io/second-state/llama-api-server:latest testggml2 llama-api-server.wasm \
  --prompt-template llama-3-chat \
  --ctx-size 4096 \
  --model-name llama-3-1b
```

---

Open another session

1. Query to api server

```bash
curl -X POST http://localhost:8080/v1/chat/completions \
    -H 'accept:application/json' \
    -H 'Content-Type: application/json' \
    -d '{"messages":[{"role":"system", "content": "You are a helpful assistant."}, {"role":"user", "content": "Who is Robert Oppenheimer?"}], "model":"llama-3-8b"}'
```

> **Output**  
 ```{"id":"chatcmpl-f670ab3a-a578-4ed9-a56f-dc380acff882","object":"chat.completion","created":1740398087,"model":"llama-3-1b","choices":[{"index":0,"message":{"content":"Robert Oppenheimer (1904-1967) was a renowned American theoretical physicist who played a crucial role in the development of the atomic bomb during World War II. He is widely regarded as one of the most influential scientists of the 20th century.\n\nBorn in New York City, Oppenheimer grew up in a family of intellectuals and showed an early interest in mathematics and physics. He studied at Harvard University, where he earned his undergraduate degree and later worked with Leo Szilard on the development of nuclear fission theories.\n\nAfter World War I, Oppenheimer moved to the University of California, Berkeley, where he became interested in theoretical physics and began working on Einstein's theory of relativity. He then joined the faculty at Los Alamos Laboratory in New Mexico, where he led a team that developed the first nuclear reactor and made significant contributions to the Manhattan Project's development of the atomic bomb.\n\nIn 1945, Oppenheimer was appointed director of the Los Alamos Laboratory and became the chief scientist responsible for leading the team working on the atomic bomb project. However, he faced intense scrutiny and criticism from the US government due to his involvement with the project, which raised concerns about the ethics of developing a deadly weapon.\n\nIn 1945, Oppenheimer was transferred from the Los Alamos Laboratory to the United States Atomic Energy Commission (AEC), where he worked until his death in 1967. He was criticized for his perceived nuclear hawkishness and involvement with communism, which led to his security clearance being revoked due to \"national security concerns.\"\n\nDespite these controversies, Oppenheimer's contributions to physics are still widely recognized. His work on the development of quantum mechanics, thermodynamics, and statistical mechanics laid the foundation for many advances in our understanding of the universe. He was also a pioneer in the field of nuclear physics and made significant contributions to the understanding of neutron scattering.\n\nOppenheimer was awarded the Nobel Prize in Physics in 1937 for his work on beta-ray spectroscopy. He was also awarded the Enrico Fermi Award by the National Academy of Sciences in 1954.\n\nTragically, Oppenheimer's life was cut short when he died on February 18, 1967, at the age of 62, from a self-inflicted gunshot wound. However, his legacy continues to be celebrated for its significance in shaping our understanding of the universe and humanity's place within it.","role":"assistant"},"finish_reason":"stop","logprobs":null}],"usage":{"prompt_tokens":28,"completion_tokens":492,"total_tokens":520}}%```

2. Close api server

```bash
sudo ctr task rm testggml --force
```
