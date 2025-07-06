```sh
# deps - apt
sudo apt update && sudo apt upgrade -y && sudo apt install -y llvm-14-dev liblld-14-dev software-properties-common gcc g++ asciinema containerd cmake zlib1g-dev build-essential python3 python3-dev python3-pip git clang

# deps - rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && source $HOME/.cargo/env
rustup target add wasm32-wasip1
exec $SHELL

# deps - wasmedge + WASINN plugin
curl -sSf https://raw.githubusercontent.com/WasmEdge/WasmEdge/master/utils/install.sh | bash -s -- --plugins wasi_nn-ggml -v 0.14.1 # binaries and plugin in $HOME/.wasmedge
source $HOME/.bashrc

# deps - crun with wasedge support
sudo apt update
sudo apt install -y make git gcc build-essential pkgconf libtool \
    libsystemd-dev libprotobuf-c-dev libcap-dev libseccomp-dev libyajl-dev \
    go-md2man libtool autoconf python3 automake

git clone https://github.com/containers/crun
cd crun
./autogen.sh
./configure --with-wasmedge
make
sudo make install
```


```sh
# wasmedge-shim building
cd
git clone https://github.com/containerd/runwasi.git
cd runwasi
./scripts/setup-linux.sh
make build-wasmedge
INSTALL="sudo install" LN="sudo ln -sf" make install-wasmedge
# maybe equivalent to :
sudo install ./target/aarch64-unknown-linux-gnu/debug/containerd-shim-wasmedge-v1 /usr/local/bin/
#
#
#
# k3s installation
cd
curl -sfL https://get.k3s.io | sh - 
sudo chmod 777 /etc/rancher/k3s/k3s.yaml # hack
#
#
#
# wasmedge-shim installing for k3s' containerd to find
cd runwasi
sudo install ./target/$(uname -m)-unknown-linux-gnu/debug/containerd-shim-wasmedge-v1 /var/lib/rancher/k3s/data/current/bin/ # Install the shim to k3s's expected location
sudo ln -sf /var/lib/rancher/k3s/data/current/bin/containerd-shim-wasmedge-v1 /usr/local/bin/ # Create symlink for containerd to find it
sudo ldd /var/lib/rancher/k3s/data/current/bin/containerd-shim-wasmedge-v1 # Verify library loading
sudo LD_LIBRARY_PATH=/var/lib/rancher/k3s/agent/opt/containerd/lib /usr/local/bin/containerd-shim-wasmedge-v1 -v # Test plugin loading manually



# making /var accessible for k3s' containerd configuration for - crun and wasedge-shim
sudo chmod 777 -R /var

# copying WASINN plugin stuff to where k3s' containerd can find it -- maybe not needed
# sudo mkdir -p /var/lib/rancher/k3s/agent/opt/containerd/lib/
# sudo cp ~/.wasmedge/plugin/libwasmedgePluginWasiNN.so /var/lib/rancher/k3s/agent/opt/containerd/lib/
# sudo cp ~/.wasmedge/lib/libwasmedge.so /var/lib/rancher/k3s/agent/opt/containerd/lib/
# echo "export LD_LIBRARY_PATH=/var/lib/rancher/k3s/agent/opt/containerd/lib" | sudo tee -a /etc/environment
# source /etc/environment

# k3s' containerd configuration for - crun and wasedge-shim
touch /var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl
sudo tee /var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl > /dev/null <<'EOF'
version = 3
root = "/var/lib/rancher/k3s/agent/containerd"
state = "/run/k3s/containerd"

[grpc]
  address = "/run/k3s/containerd/containerd.sock"

[plugins.'io.containerd.internal.v1.opt']
  path = "/var/lib/rancher/k3s/agent/containerd"

[plugins.'io.containerd.grpc.v1.cri']
  stream_server_address = "127.0.0.1"
  stream_server_port = "10010"

[plugins.'io.containerd.cri.v1.runtime']
  enable_selinux = false
  enable_unprivileged_ports = true
  enable_unprivileged_icmp = true
  device_ownership_from_security_context = false
  default_runtime_name = "crun"

[plugins.'io.containerd.cri.v1.images']
  snapshotter = "overlayfs"
  disable_snapshot_annotations = true

[plugins.'io.containerd.cri.v1.images'.pinned_images]
  sandbox = "rancher/mirrored-pause:3.6"

[plugins.'io.containerd.cri.v1.runtime'.cni]
  bin_dir = "/var/lib/rancher/k3s/data/cni"
  conf_dir = "/var/lib/rancher/k3s/agent/etc/cni/net.d"

[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc]
  runtime_type = "io.containerd.runc.v2"

[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc.options]
  SystemdCgroup = true

[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runhcs-wcow-process]
  runtime_type = "io.containerd.runhcs.v1"

[plugins.'io.containerd.cri.v1.runtime'.containerd]
  default_runtime_name = "crun"
  [plugins."io.containerd.cri.v1.runtime".containerd.runtimes]
    [plugins."io.containerd.cri.v1.runtime".containerd.runtimes.crun]
      runtime_type = "io.containerd.runc.v2"
      [plugins."io.containerd.cri.v1.runtime".containerd.runtimes.crun.options]
        BinaryName = "/usr/local/bin/crun"
        SystemdCgroup = true

[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.wasmedge]
  runtime_type = "io.containerd.wasmedge.v1"
  privileged_without_host_devices = true
  [plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.wasmedge.options]
    BinaryName = "/usr/local/bin/containerd-shim-wasmedge-v1"
    SystemdCgroup = true

[plugins.'io.containerd.cri.v1.images'.registry]
  config_path = "/var/lib/rancher/k3s/agent/etc/containerd/certs.d"
EOF

# restart k3s to let new k3s' containerd config take effect
sudo systemctl restart k3s
```

```sh
# build llama-server-wasm
cd
git clone --recurse-submodules https://github.com/second-state/runwasi-wasmedge-demo.git
cd
cd runwasi-wasmedge-demo

# edit makefile to eliminate containerd version error
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

git -C apps/llamaedge apply $PWD/disable_wasi_logging.patch
OPT_PROFILE=release RUSTFLAGS="--cfg wasmedge --cfg tokio_unstable" make apps/llamaedge/llama-api-server

# place llama-server-img in k3s' containerd local store (NOT THE LOCAL STORE OF HOST MACHINE'S CONTAINERD - IT'S ALREADY THERE IG)
cd $HOME/runwasi-wasmedge-demo/apps/llamaedge/llama-api-server
oci-tar-builder --name llama-api-server \
    --repo ghcr.io/second-state \
    --tag latest \
    --module target/wasm32-wasip1/release/llama-api-server.wasm \
    -o target/wasm32-wasip1/release/img-oci.tar # Create OCI image from the WASM binary
sudo k3s ctr image import --all-platforms $HOME/runwasi-wasmedge-demo/apps/llamaedge/llama-api-server/target/wasm32-wasip1/release/img-oci.tar # place it in k3s' containerd local store
sudo k3s ctr images ls # verify that the llama-api-server image is there
```



```sh 
# download model
sudo mkdir -p /mnt/models
sudo chmod 777 /mnt/models  # ensure readable by k3s
cd /mnt/models
curl -LO https://huggingface.co/second-state/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q5_K_M.gguf
#
#
# get pod name
POD_NAME=$(sudo k3s kubectl get pods -l app=llama-api -o jsonpath='{.items[0].metadata.name}')
# Vvrify model is visible to the WASM app
sudo k3s kubectl exec $POD_NAME -- ls -lh /models
#
#


# create the kubernetes configuration yaml's : ref ./k3s_config_yaml/

sudo k3s kubectl apply -f wasmedge-runtime.yaml
sudo k3s kubectl apply -f llama-config.yaml
sudo k3s kubectl apply -f llama-deployment.yaml
sudo k3s kubectl apply -f llama-service.yaml

sudo k3s kubectl get pods
sudo k3s kubectl describe pod llama-api-64f7844fc8-b9d5f # debugging
```


```sh
##### below is WIP ####
```


```sh
# In terminal 1:
sudo k3s kubectl port-forward svc/llama-service 8080:8080

# In terminal 2:
curl -X POST http://localhost:8080/v1/chat/completions \
    -H 'accept:application/json' \
    -H 'Content-Type: application/json' \
    -d '{
        "messages": [
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": "Who is Robert Oppenheimer?"}
        ],
        "model": "llama-3-1b"
    }'

```


```sh
# cleanup
sudo k3s kubectl delete -f llama-deployment.yaml
sudo k3s kubectl delete -f llama-service.yaml


```