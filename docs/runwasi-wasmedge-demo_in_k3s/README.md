# Running `github.com/second-state/runwasi-wasmedge-demo` in k3s

### 1. Installing dependencies 
```sh
# deps - apt
sudo apt update && sudo apt upgrade -y && sudo apt install -y llvm-14-dev liblld-14-dev software-properties-common gcc g++ asciinema cmake zlib1g-dev build-essential python3 python3-dev python3-pip git clang

# deps - rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && source $HOME/.cargo/env
rustup target add wasm32-wasip1
exec $SHELL

# deps - wasmedge + WASINN plugin
curl -sSf https://raw.githubusercontent.com/WasmEdge/WasmEdge/master/utils/install.sh | bash -s -- --plugins wasi_nn-ggml -v 0.14.1 # binaries and plugin in $HOME/.wasmedge
source $HOME/.bashrc

# deps - crun with wasmedge support
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

# deps - runwasi-wasmedge-shim 
cd
git clone https://github.com/containerd/runwasi.git
cd runwasi
./scripts/setup-linux.sh
make build-wasmedge
INSTALL="sudo install" LN="sudo ln -sf" make install-wasmedge

# deps - k3s installation
cd
curl -sfL https://get.k3s.io | sh - 
sudo chmod 777 /etc/rancher/k3s/k3s.yaml # hack
```

### 2. Configuring containerd to use crun as default OCI runtime
k3s' containerd supports wasmedge and crun as runtimes, so when we restart k3s using 

`sudo systemctl restart k3s`

it finds those binaries in `/usr/local/bin` automatically and automatically writes a config.toml to `/var/lib/rancher/k3s/agent/etc/containerd/config.toml` reflecting that it now has the ability to successfully use those runtimes

After this, we just have to make `crun` the default runtime by 

`touch /var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl`

this` config.toml.tmpl's` contents are written to c`onfig.toml` on next k3s' restart

```sh
# making /var accessible to access k3s' containerd configuration config.toml
sudo chmod 777 -R /var

# k3s' containerd configuration for crun ( and runwasi's wasmedge shim )
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


3. Building image ghcr.io/second-state/llama-api-server:latest
This step builds the `ghcr.io/second-state/llama-api-server:latest` image and imports it to the k3s' containerd's local image store

```sh
# build llama-server-wasm
cd

git clone --recurse-submodules https://github.com/second-state/runwasi-wasmedge-demo.git

cd runwasi-wasmedge-demo

# edit makefile to eliminate containerd version error
sed -i -e '/define CHECK_CONTAINERD_VERSION/,/^endef/{
s/Containerd version must be/WARNING: Containerd version should be/
/exit 1;/d
}' Makefile

git -C apps/llamaedge apply $PWD/disable_wasi_logging.patch
OPT_PROFILE=release RUSTFLAGS="--cfg wasmedge --cfg tokio_unstable" make apps/llamaedge/llama-api-server

# place llama-server-img in k3s' containerd local store (NOT THE LOCAL STORE OF HOST MACHINE'S CONTAINERD - IT'S ALREADY THERE)
cd $HOME/runwasi-wasmedge-demo/apps/llamaedge/llama-api-server
oci-tar-builder --name llama-api-server \
    --repo ghcr.io/second-state \
    --tag latest \
    --module target/wasm32-wasip1/release/llama-api-server.wasm \
    -o target/wasm32-wasip1/release/img-oci.tar # Create OCI image from the WASM binary
sudo k3s ctr image import --all-platforms $HOME/runwasi-wasmedge-demo/apps/llamaedge/llama-api-server/target/wasm32-wasip1/release/img-oci.tar # place it in k3s' containerd local store
sudo k3s ctr images ls # verify that the llama-api-server image is there
```

### 4. Download the gguf model needed by llama-api-server
```sh 
# download model
cd
sudo mkdir -p models
sudo chmod 777 models  # ensure it's readable by k3s
cd models
curl -LO https://huggingface.co/second-state/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q5_K_M.gguf
```

### 5. Create the kubernetes configuration yaml ( ref <<>> )

```sh
cd
touch deployment.yaml
sudo tee deployment.yaml > /dev/null <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: llama-api-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: llama-api-server
  template:
    metadata:
      labels:
        app: llama-api-server
    spec:
      runtimeClassName: wasmedge
      containers:
        - name: llama-api-server
          image: ghcr.io/second-state/llama-api-server:latest
          imagePullPolicy: Never
          command: ["llama-api-server.wasm"]
          args:
            - "--prompt-template"
            - "llama-3-chat"
            - "--ctx-size"
            - "4096"
            - "--model-name"
            - "llama-3-1b"
          env:
            - name: WASMEDGE_PLUGIN_PATH
              value: "/home/dev/.wasmedge/plugin"

            - name: LD_LIBRARY_PATH 
              value: "/home/dev/.wasmedge/lib" 

            - name: WASMEDGE_WASINN_PRELOAD
              value: "default:GGML:CPU:/home/dev/models/Llama-3.2-1B-Instruct-Q5_K_M.gguf"

          volumeMounts:
            - name: gguf-model-file
              mountPath: /home/dev/models/Llama-3.2-1B-Instruct-Q5_K_M.gguf
              readOnly: true

            - name: wasi-nn-plugin-file
              mountPath: /home/dev/.wasmedge/plugin/libwasmedgePluginWasiNN.so
              readOnly: true
            - name: wasi-nn-plugin-lib
              mountPath: /home/dev/.wasmedge/lib
              readOnly: true

            - name: libm
              mountPath: /lib/aarch64-linux-gnu/libm.so.6
              readOnly: true
            - name: libpthread
              mountPath: /lib/aarch64-linux-gnu/libpthread.so.0
              readOnly: true
            - name: libc
              mountPath: /lib/aarch64-linux-gnu/libc.so.6
              readOnly: true
            - name: ld-linux
              mountPath: /lib/ld-linux-aarch64.so.1
              readOnly: true
            - name: libdl
              mountPath: /lib/aarch64-linux-gnu/libdl.so.2
              readOnly: true
            - name: libstdcxx
              mountPath: /lib/aarch64-linux-gnu/libstdc++.so.6
              readOnly: true
            - name: libgcc-s
              mountPath: /lib/aarch64-linux-gnu/libgcc-s.so.1
              readOnly: true

      volumes:
        - name: gguf-model-file
          hostPath:
            path: /home/dev/models/Llama-3.2-1B-Instruct-Q5_K_M.gguf
            type: File

        - name: wasi-nn-plugin-file
          hostPath:
            path: /home/dev/.wasmedge/plugin/libwasmedgePluginWasiNN.so
            type: File
        - name: wasi-nn-plugin-lib
          hostPath:
            path: /home/dev/.wasmedge/lib
            type: Directory

        - name: libm
          hostPath:
            path: /lib/aarch64-linux-gnu/libm.so.6
            type: File
        - name: libpthread
          hostPath:
            path: /lib/aarch64-linux-gnu/libpthread.so.0
            type: File
        - name: libc
          hostPath:
            path: /lib/aarch64-linux-gnu/libc.so.6
            type: File
        - name: ld-linux
          hostPath:
            path: /lib/ld-linux-aarch64.so.1
            type: File
        - name: libdl
          hostPath:
            path: /lib/aarch64-linux-gnu/libdl.so.2
            type: File
        - name: libstdcxx
          hostPath:
            path: /lib/aarch64-linux-gnu/libstdc++.so.6
            type: File
        - name: libgcc-s
          hostPath:
            path: /lib/aarch64-linux-gnu/libgcc_s.so.1
            type: File

---
apiVersion: v1
kind: Service
metadata:
  name: llama-api-server-service
spec:
  selector:
    app: llama-api-server
  ports:
    - protocol: TCP
      port: 8080
      targetPort: 8080
  type: ClusterIP

---
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: wasmedge
handler: wasmedge
EOF

sudo k3s kubectl get pods
# o/p :
# NAME                               READY   STATUS    RESTARTS   AGE
# llama-api-server-d87d7b4dd-z24xv   1/1     Running   0          2m28s

sudo k3s kubectl describe pod llama-api-64f7844fc8-b9d5f 
# o/p :
# Name:                llama-api-server-d87d7b4dd-z24xv
# Namespace:           default
# Priority:            0
# Runtime Class Name:  wasmedge
# Service Account:     default
# Node:                ubuntu/198.19.249.166
# Start Time:          Wed, 09 Jul 2025 23:37:00 +0530
# Labels:              app=llama-api-server
#                      pod-template-hash=d87d7b4dd
# Annotations:         <none>
# Status:              Running
# IP:                  10.42.0.9
# IPs:
#   IP:           10.42.0.9
# Controlled By:  ReplicaSet/llama-api-server-d87d7b4dd
# Containers:
#   llama-api:
#     Container ID:  containerd://695c1e565c9c3919a0faff2d465ef0a17a6530da0e0958184243f4f4e39ff0a7
#     Image:         ghcr.io/second-state/llama-api-server:latest
#     Image ID:      sha256:922ed5b65350bc57dfb85e1766f5ec3fa4f0a5db408e9b18f649d7bf937fa459
#     Port:          <none>
#     Host Port:     <none>
#     Command:
#       llama-api-server.wasm
#     Args:
#       --prompt-template
#       llama-3-chat
#       --ctx-size
#       4096
#       --model-name
#       llama-3-1b
#     State:          Running
#       Started:      Wed, 09 Jul 2025 23:39:09 +0530
#     Ready:          True
#     Restart Count:  0
#     Environment:
#       WASMEDGE_PLUGIN_PATH:     /home/dev/.wasmedge/plugin
#       WASMEDGE_WASINN_PRELOAD:  default:GGML:CPU:/home/dev/models/Llama-3.2-1B-Instruct-Q5_K_M.gguf
#       LD_LIBRARY_PATH:          /home/dev/.wasmedge/lib
#     Mounts:
#       /home/dev/.wasmedge/lib from wasi-nn-plugin-lib (ro)
#       /home/dev/.wasmedge/plugin/libwasmedgePluginWasiNN.so from wasi-nn-plugin-file (ro)
#       /home/dev/models/Llama-3.2-1B-Instruct-Q5_K_M.gguf from gguf-model-file (ro)
#       /lib/aarch64-linux-gnu/libc.so.6 from libc (ro)
#       /lib/aarch64-linux-gnu/libdl.so.2 from libdl (ro)
#       /lib/aarch64-linux-gnu/libgcc-s.so.1 from libgcc-s (ro)
#       /lib/aarch64-linux-gnu/libm.so.6 from libm (ro)
#       /lib/aarch64-linux-gnu/libpthread.so.0 from libpthread (ro)
#       /lib/aarch64-linux-gnu/libstdc++.so.6 from libstdcxx (ro)
#       /lib/ld-linux-aarch64.so.1 from ld-linux (ro)
#       /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-x2lqc (ro)
# Conditions:
#   Type                        Status
#   PodReadyToStartContainers   True
#   Initialized                 True
#   Ready                       True
#   ContainersReady             True
#   PodScheduled                True
# Volumes:
#   gguf-model-file:
#     Type:          HostPath (bare host directory volume)
#     Path:          /home/dev/models/Llama-3.2-1B-Instruct-Q5_K_M.gguf
#     HostPathType:  File
#   wasi-nn-plugin-file:
#     Type:          HostPath (bare host directory volume)
#     Path:          /home/dev/.wasmedge/plugin/libwasmedgePluginWasiNN.so
#     HostPathType:  File
#   wasi-nn-plugin-lib:
#     Type:          HostPath (bare host directory volume)
#     Path:          /home/dev/.wasmedge/lib
#     HostPathType:  Directory
#   libm:
#     Type:          HostPath (bare host directory volume)
#     Path:          /lib/aarch64-linux-gnu/libm.so.6
#     HostPathType:  File
#   libpthread:
#     Type:          HostPath (bare host directory volume)
#     Path:          /lib/aarch64-linux-gnu/libpthread.so.0
#     HostPathType:  File
#   libc:
#     Type:          HostPath (bare host directory volume)
#     Path:          /lib/aarch64-linux-gnu/libc.so.6
#     HostPathType:  File
#   ld-linux:
#     Type:          HostPath (bare host directory volume)
#     Path:          /lib/ld-linux-aarch64.so.1
#     HostPathType:  File
#   libdl:
#     Type:          HostPath (bare host directory volume)
#     Path:          /lib/aarch64-linux-gnu/libdl.so.2
#     HostPathType:  File
#   libstdcxx:
#     Type:          HostPath (bare host directory volume)
#     Path:          /lib/aarch64-linux-gnu/libstdc++.so.6
#     HostPathType:  File
#   libgcc-s:
#     Type:          HostPath (bare host directory volume)
#     Path:          /lib/aarch64-linux-gnu/libgcc_s.so.1
#     HostPathType:  File
#   kube-api-access-x2lqc:
#     Type:                    Projected (a volume that contains injected data from multiple sources)
#     TokenExpirationSeconds:  3607
#     ConfigMapName:           kube-root-ca.crt
#     ConfigMapOptional:       <nil>
#     DownwardAPI:             true
# QoS Class:                   BestEffort
# Node-Selectors:              <none>
# Tolerations:                 node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
#                              node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
# Events:
#   Type     Reason             Age                  From               Message
#   ----     ------             ----                 ----               -------
#   Normal   Scheduled          55s                 default-scheduler  Successfully assigned default/llama-api-server-d87d7b4dd-z24xv to ubuntu
#   Normal   Pulled             56s                  kubelet            Container image "ghcr.io/second-state/llama-api-server:latest" already present on machine
#   Normal   Created            56s                  kubelet            Created container: llama-api
#   Normal   Started            56s                  kubelet            Started container llama-api
```

### 5. Query the llama-api-server

```sh
# In terminal 1:
sudo k3s kubectl port-forward svc/llama-service 8080:8080
# o/p:
# Forwarding from 127.0.0.1:8080 -> 8080
# Forwarding from [::1]:8080 -> 8080
# Handling connection for 8080

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
# o/p :
# {"id":"chatcmpl-10af011c-a33b-4d36-9dad-b136253e204d","object":"chat.completion","created":1752085233,"model":"llama-3-1b","choices":[{"index":0,"message":{"content":"Robert Oppenheimer (1904-1967) was an American theoretical physicist who played a key role in the development of the atomic bomb during World War II. He is widely regarded as one of the most influential scientists of the 20th century.\n\nOppenheimer was born on April 22, 1904, in New York City to Jewish parents from Russia. His early life was marked by his family's emigration to the United States after anti-Semitic violence against Jews in Germany. He received his Ph.D. in physics from Princeton University in 1927 and worked at various research institutions, including the University of California, Berkeley.\n\nIn 1933, Oppenheimer joined Los Alamos Laboratory (now Los Alamos National Laboratory) as a young physicist working on a top-secret project to develop an atomic bomb under J. Robert Oppenheimer's direction. This project was code-named \"Manhattan Project.\" In 1942, the United States dropped the first atomic bombs on Hiroshima and Nagasaki, Japan, leading to his involvement in the development of the atomic bomb.\n\nAfter the war, Oppenheimer continued his work at Los Alamos and later became the director of the Manhattan Project's secret research division. He also played a key role in shaping the post-war nuclear policy, particularly through his presidency of the Advisory Committee on Nuclear Energy (ACNE), which helped to establish the United States' nuclear energy industry.\n\nDespite his crucial contributions to the development of atomic energy and national security, Oppenheimer was haunted by the moral implications of his work. He believed that his involvement in the Manhattan Project had made him complicit in the bombings, and he struggled with personal demons throughout his life. In 1954, he was subjected to a series of \"security clearance examinations\" due to allegations of subversive activities, which damaged his reputation and led to his eventual expulsion from government service.\n\nOppenheimer's views on science were also criticized for being too nuanced and scientifically skeptical. He believed that scientists should be guided by principles of ethics rather than simply pursuing power. After his retirement in 1955, he became an advocate for disarmament and arms control.\n\nThe 1986 book \"American Prometheus: The Triumph and Tragedy of J. Robert Oppenheimer\" was a critical biography written by Kai Bird and Martin J. Sherwin that helped to redeem Oppenheimer's reputation and provide a nuanced understanding of his complex legacy.\n\nDespite the controversy surrounding him, Robert Oppenheimer remains an important figure in science history and continues to be celebrated for his contributions to physics and his role in shaping our understanding of atomic energy.","role":"assistant"},"finish_reason":"stop","logprobs":null}],"usage":{"prompt_tokens":28,"completion_tokens":534,"total_tokens":562}}
```
```sh
sudo k3s kubectl logs llama-api-server-d87d7b4dd-z24xv
# o/p:
# [2025-07-09 18:09:09.781] [info] [WASI-NN] GGML backend: LLAMA_COMMIT 2e89f76b
# [2025-07-09 18:09:09.781] [info] [WASI-NN] GGML backend: LLAMA_BUILD_NUMBER 5640
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: loaded meta data with 31 key-value pairs and 147 tensors from /home/dev/models/Llama-3.2-1B-Instruct-Q5_K_M.gguf (version GGUF V3 (latest))
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: Dumping metadata keys/values. Note: KV overrides do not apply in this output.
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv   0:                       general.architecture str              = llama
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv   1:                               general.type str              = model
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv   2:                               general.name str              = Llama 3.2 1B Instruct
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv   3:                           general.finetune str              = Instruct
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv   4:                           general.basename str              = Llama-3.2
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv   5:                         general.size_label str              = 1B
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv   6:                            general.license str              = llama3.2
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv   7:                               general.tags arr[str,6]       = ["facebook", "meta", "pytorch", "llam...
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv   8:                          general.languages arr[str,8]       = ["en", "de", "fr", "it", "pt", "hi", ...
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv   9:                          llama.block_count u32              = 16
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  10:                       llama.context_length u32              = 131072
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  11:                     llama.embedding_length u32              = 2048
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  12:                  llama.feed_forward_length u32              = 8192
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  13:                 llama.attention.head_count u32              = 32
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  14:              llama.attention.head_count_kv u32              = 8
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  15:                       llama.rope.freq_base f32              = 500000.000000
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  16:     llama.attention.layer_norm_rms_epsilon f32              = 0.000010
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  17:                 llama.attention.key_length u32              = 64
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  18:               llama.attention.value_length u32              = 64
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  19:                           llama.vocab_size u32              = 128256
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  20:                 llama.rope.dimension_count u32              = 64
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  21:                       tokenizer.ggml.model str              = gpt2
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  22:                         tokenizer.ggml.pre str              = llama-bpe
# [2025-07-09 18:09:09.835] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  23:                      tokenizer.ggml.tokens arr[str,128256]  = ["!", "\"", "#", "$", "%", "&", "'", ...
# [2025-07-09 18:09:09.845] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  24:                  tokenizer.ggml.token_type arr[i32,128256]  = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, ...
# [2025-07-09 18:09:09.880] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  25:                      tokenizer.ggml.merges arr[str,280147]  = ["Ġ Ġ", "Ġ ĠĠĠ", "ĠĠ ĠĠ", "...
# [2025-07-09 18:09:09.880] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  26:                tokenizer.ggml.bos_token_id u32              = 128000
# [2025-07-09 18:09:09.880] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  27:                tokenizer.ggml.eos_token_id u32              = 128009
# [2025-07-09 18:09:09.880] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  28:                    tokenizer.chat_template str              = {{- bos_token }}\n{%- if custom_tools ...
# [2025-07-09 18:09:09.880] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  29:               general.quantization_version u32              = 2
# [2025-07-09 18:09:09.880] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  30:                          general.file_type u32              = 17
# [2025-07-09 18:09:09.880] [info] [WASI-NN] llama.cpp: llama_model_loader: - type  f32:   34 tensors
# [2025-07-09 18:09:09.880] [info] [WASI-NN] llama.cpp: llama_model_loader: - type q5_K:   96 tensors
# [2025-07-09 18:09:09.880] [info] [WASI-NN] llama.cpp: llama_model_loader: - type q6_K:   17 tensors
# [2025-07-09 18:09:09.880] [info] [WASI-NN] llama.cpp: print_info: file format = GGUF V3 (latest)
# [2025-07-09 18:09:09.880] [info] [WASI-NN] llama.cpp: print_info: file type   = Q5_K - Medium
# [2025-07-09 18:09:09.880] [info] [WASI-NN] llama.cpp: print_info: file size   = 861.81 MiB (5.85 BPW)
# [2025-07-09 18:09:10.020] [info] [WASI-NN] llama.cpp: load: special tokens cache size = 256
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: load: token to piece cache size = 0.7999 MB
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: arch             = llama
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: vocab_only       = 0
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_ctx_train      = 131072
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_embd           = 2048
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_layer          = 16
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_head           = 32
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_head_kv        = 8
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_rot            = 64
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_swa            = 0
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: is_swa_any       = 0
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_embd_head_k    = 64
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_embd_head_v    = 64
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_gqa            = 4
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_embd_k_gqa     = 512
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_embd_v_gqa     = 512
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: f_norm_eps       = 0.0e+00
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: f_norm_rms_eps   = 1.0e-05
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: f_clamp_kqv      = 0.0e+00
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: f_max_alibi_bias = 0.0e+00
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: f_logit_scale    = 0.0e+00
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: f_attn_scale     = 0.0e+00
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_ff             = 8192
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_expert         = 0
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_expert_used    = 0
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: causal attn      = 1
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: pooling type     = 0
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: rope type        = 0
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: rope scaling     = linear
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: freq_base_train  = 500000.0
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: freq_scale_train = 1
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_ctx_orig_yarn  = 131072
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: rope_finetuned   = unknown
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: ssm_d_conv       = 0
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: ssm_d_inner      = 0
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: ssm_d_state      = 0
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: ssm_dt_rank      = 0
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: ssm_dt_b_c_rms   = 0
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: model type       = 1B
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: model params     = 1.24 B
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: general.name     = Llama 3.2 1B Instruct
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: vocab type       = BPE
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_vocab          = 128256
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_merges         = 280147
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: BOS token        = 128000 '<|begin_of_text|>'
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: EOS token        = 128009 '<|eot_id|>'
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: EOT token        = 128009 '<|eot_id|>'
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: EOM token        = 128008 '<|eom_id|>'
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: LF token         = 198 'Ċ'
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: EOG token        = 128008 '<|eom_id|>'
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: EOG token        = 128009 '<|eot_id|>'
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: max token length = 256
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: load_tensors: loading model tensors, this can take a while... (mmap = true)
# [2025-07-09 18:09:10.455] [info] [WASI-NN] llama.cpp: load_tensors:   CPU_Mapped model buffer size =   861.81 MiB
# [2025-07-09 18:09:10.458] [info] [WASI-NN] llama.cpp: llama_context: constructing llama_context
# [2025-07-09 18:09:10.458] [info] [WASI-NN] llama.cpp: llama_context: n_seq_max     = 1
# [2025-07-09 18:09:10.458] [info] [WASI-NN] llama.cpp: llama_context: n_ctx         = 4096
# [2025-07-09 18:09:10.458] [info] [WASI-NN] llama.cpp: llama_context: n_ctx_per_seq = 4096
# [2025-07-09 18:09:10.458] [info] [WASI-NN] llama.cpp: llama_context: n_batch       = 512
# [2025-07-09 18:09:10.458] [info] [WASI-NN] llama.cpp: llama_context: n_ubatch      = 512
# [2025-07-09 18:09:10.458] [info] [WASI-NN] llama.cpp: llama_context: causal_attn   = 1
# [2025-07-09 18:09:10.458] [info] [WASI-NN] llama.cpp: llama_context: flash_attn    = 0
# [2025-07-09 18:09:10.458] [info] [WASI-NN] llama.cpp: llama_context: freq_base     = 500000.0
# [2025-07-09 18:09:10.458] [info] [WASI-NN] llama.cpp: llama_context: freq_scale    = 1
# [2025-07-09 18:09:10.458] [warning] [WASI-NN] llama.cpp: llama_context: n_ctx_per_seq (4096) < n_ctx_train (131072) -- the full capacity of the model will not be utilized
# [2025-07-09 18:09:10.458] [info] [WASI-NN] llama.cpp: llama_context:        CPU  output buffer size =     0.49 MiB
# [2025-07-09 18:09:10.458] [info] [WASI-NN] llama.cpp: llama_kv_cache_unified:        CPU KV buffer size =   128.00 MiB
# [2025-07-09 18:09:10.514] [info] [WASI-NN] llama.cpp: llama_kv_cache_unified: size =  128.00 MiB (  4096 cells,  16 layers,  1 seqs), K (f16):   64.00 MiB, V (f16):   64.00 MiB
# [2025-07-09 18:09:10.528] [info] [WASI-NN] llama.cpp: llama_context:        CPU compute buffer size =   280.01 MiB
# [2025-07-09 18:09:10.528] [info] [WASI-NN] llama.cpp: llama_context: graph nodes  = 582
# [2025-07-09 18:09:10.528] [info] [WASI-NN] llama.cpp: llama_context: graph splits = 1
# common_init_from_params: setting dry_penalty_last_n to ctx_size = 4096
# [2025-07-09 18:09:10.529] [info] [WASI-NN] GGML backend: llama_system_info: CPU : NEON = 1 | ARM_FMA = 1 | LLAMAFILE = 1 | REPACK = 1 |
# [2025-07-09 18:17:32.111] [warning] [WASI-NN] llama.cpp: check_double_bos_eos: Added a BOS token to the prompt as specified by the model but the prompt also starts with a BOS token. So now the final prompt starts with 2 BOS tokens. Are you sure this is what you want?
# [2025-07-09 18:17:32.114] [warning] [WASI-NN] llama.cpp: check_double_bos_eos: Added a BOS token to the prompt as specified by the model but the prompt also starts with a BOS token. So now the final prompt starts with 2 BOS tokens. Are you sure this is what you want?
# dev@ubuntu:~$  sudo k3s kubectl logs pod/llama-api-server-d87d7b4dd-z24xv
# [2025-07-09 18:09:09.781] [info] [WASI-NN] GGML backend: LLAMA_COMMIT 2e89f76b
# [2025-07-09 18:09:09.781] [info] [WASI-NN] GGML backend: LLAMA_BUILD_NUMBER 5640
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: loaded meta data with 31 key-value pairs and 147 tensors from /home/dev/models/Llama-3.2-1B-Instruct-Q5_K_M.gguf (version GGUF V3 (latest))
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: Dumping metadata keys/values. Note: KV overrides do not apply in this output.
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv   0:                       general.architecture str              = llama
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv   1:                               general.type str              = model
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv   2:                               general.name str              = Llama 3.2 1B Instruct
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv   3:                           general.finetune str              = Instruct
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv   4:                           general.basename str              = Llama-3.2
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv   5:                         general.size_label str              = 1B
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv   6:                            general.license str              = llama3.2
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv   7:                               general.tags arr[str,6]       = ["facebook", "meta", "pytorch", "llam...
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv   8:                          general.languages arr[str,8]       = ["en", "de", "fr", "it", "pt", "hi", ...
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv   9:                          llama.block_count u32              = 16
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  10:                       llama.context_length u32              = 131072
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  11:                     llama.embedding_length u32              = 2048
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  12:                  llama.feed_forward_length u32              = 8192
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  13:                 llama.attention.head_count u32              = 32
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  14:              llama.attention.head_count_kv u32              = 8
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  15:                       llama.rope.freq_base f32              = 500000.000000
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  16:     llama.attention.layer_norm_rms_epsilon f32              = 0.000010
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  17:                 llama.attention.key_length u32              = 64
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  18:               llama.attention.value_length u32              = 64
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  19:                           llama.vocab_size u32              = 128256
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  20:                 llama.rope.dimension_count u32              = 64
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  21:                       tokenizer.ggml.model str              = gpt2
# [2025-07-09 18:09:09.819] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  22:                         tokenizer.ggml.pre str              = llama-bpe
# [2025-07-09 18:09:09.835] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  23:                      tokenizer.ggml.tokens arr[str,128256]  = ["!", "\"", "#", "$", "%", "&", "'", ...
# [2025-07-09 18:09:09.845] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  24:                  tokenizer.ggml.token_type arr[i32,128256]  = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, ...
# [2025-07-09 18:09:09.880] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  25:                      tokenizer.ggml.merges arr[str,280147]  = ["Ġ Ġ", "Ġ ĠĠĠ", "ĠĠ ĠĠ", "...
# [2025-07-09 18:09:09.880] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  26:                tokenizer.ggml.bos_token_id u32              = 128000
# [2025-07-09 18:09:09.880] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  27:                tokenizer.ggml.eos_token_id u32              = 128009
# [2025-07-09 18:09:09.880] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  28:                    tokenizer.chat_template str              = {{- bos_token }}\n{%- if custom_tools ...
# [2025-07-09 18:09:09.880] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  29:               general.quantization_version u32              = 2
# [2025-07-09 18:09:09.880] [info] [WASI-NN] llama.cpp: llama_model_loader: - kv  30:                          general.file_type u32              = 17
# [2025-07-09 18:09:09.880] [info] [WASI-NN] llama.cpp: llama_model_loader: - type  f32:   34 tensors
# [2025-07-09 18:09:09.880] [info] [WASI-NN] llama.cpp: llama_model_loader: - type q5_K:   96 tensors
# [2025-07-09 18:09:09.880] [info] [WASI-NN] llama.cpp: llama_model_loader: - type q6_K:   17 tensors
# [2025-07-09 18:09:09.880] [info] [WASI-NN] llama.cpp: print_info: file format = GGUF V3 (latest)
# [2025-07-09 18:09:09.880] [info] [WASI-NN] llama.cpp: print_info: file type   = Q5_K - Medium
# [2025-07-09 18:09:09.880] [info] [WASI-NN] llama.cpp: print_info: file size   = 861.81 MiB (5.85 BPW)
# [2025-07-09 18:09:10.020] [info] [WASI-NN] llama.cpp: load: special tokens cache size = 256
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: load: token to piece cache size = 0.7999 MB
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: arch             = llama
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: vocab_only       = 0
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_ctx_train      = 131072
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_embd           = 2048
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_layer          = 16
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_head           = 32
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_head_kv        = 8
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_rot            = 64
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_swa            = 0
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: is_swa_any       = 0
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_embd_head_k    = 64
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_embd_head_v    = 64
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_gqa            = 4
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_embd_k_gqa     = 512
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_embd_v_gqa     = 512
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: f_norm_eps       = 0.0e+00
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: f_norm_rms_eps   = 1.0e-05
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: f_clamp_kqv      = 0.0e+00
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: f_max_alibi_bias = 0.0e+00
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: f_logit_scale    = 0.0e+00
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: f_attn_scale     = 0.0e+00
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_ff             = 8192
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_expert         = 0
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_expert_used    = 0
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: causal attn      = 1
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: pooling type     = 0
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: rope type        = 0
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: rope scaling     = linear
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: freq_base_train  = 500000.0
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: freq_scale_train = 1
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_ctx_orig_yarn  = 131072
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: rope_finetuned   = unknown
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: ssm_d_conv       = 0
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: ssm_d_inner      = 0
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: ssm_d_state      = 0
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: ssm_dt_rank      = 0
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: ssm_dt_b_c_rms   = 0
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: model type       = 1B
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: model params     = 1.24 B
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: general.name     = Llama 3.2 1B Instruct
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: vocab type       = BPE
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_vocab          = 128256
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: n_merges         = 280147
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: BOS token        = 128000 '<|begin_of_text|>'
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: EOS token        = 128009 '<|eot_id|>'
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: EOT token        = 128009 '<|eot_id|>'
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: EOM token        = 128008 '<|eom_id|>'
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: LF token         = 198 'Ċ'
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: EOG token        = 128008 '<|eom_id|>'
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: EOG token        = 128009 '<|eot_id|>'
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: print_info: max token length = 256
# [2025-07-09 18:09:10.060] [info] [WASI-NN] llama.cpp: load_tensors: loading model tensors, this can take a while... (mmap = true)
# [2025-07-09 18:09:10.455] [info] [WASI-NN] llama.cpp: load_tensors:   CPU_Mapped model buffer size =   861.81 MiB
# [2025-07-09 18:09:10.458] [info] [WASI-NN] llama.cpp: llama_context: constructing llama_context
# [2025-07-09 18:09:10.458] [info] [WASI-NN] llama.cpp: llama_context: n_seq_max     = 1
# [2025-07-09 18:09:10.458] [info] [WASI-NN] llama.cpp: llama_context: n_ctx         = 4096
# [2025-07-09 18:09:10.458] [info] [WASI-NN] llama.cpp: llama_context: n_ctx_per_seq = 4096
# [2025-07-09 18:09:10.458] [info] [WASI-NN] llama.cpp: llama_context: n_batch       = 512
# [2025-07-09 18:09:10.458] [info] [WASI-NN] llama.cpp: llama_context: n_ubatch      = 512
# [2025-07-09 18:09:10.458] [info] [WASI-NN] llama.cpp: llama_context: causal_attn   = 1
# [2025-07-09 18:09:10.458] [info] [WASI-NN] llama.cpp: llama_context: flash_attn    = 0
# [2025-07-09 18:09:10.458] [info] [WASI-NN] llama.cpp: llama_context: freq_base     = 500000.0
# [2025-07-09 18:09:10.458] [info] [WASI-NN] llama.cpp: llama_context: freq_scale    = 1
# [2025-07-09 18:09:10.458] [warning] [WASI-NN] llama.cpp: llama_context: n_ctx_per_seq (4096) < n_ctx_train (131072) -- the full capacity of the model will not be utilized
# [2025-07-09 18:09:10.458] [info] [WASI-NN] llama.cpp: llama_context:        CPU  output buffer size =     0.49 MiB
# [2025-07-09 18:09:10.458] [info] [WASI-NN] llama.cpp: llama_kv_cache_unified:        CPU KV buffer size =   128.00 MiB
# [2025-07-09 18:09:10.514] [info] [WASI-NN] llama.cpp: llama_kv_cache_unified: size =  128.00 MiB (  4096 cells,  16 layers,  1 seqs), K (f16):   64.00 MiB, V (f16):   64.00 MiB
# [2025-07-09 18:09:10.528] [info] [WASI-NN] llama.cpp: llama_context:        CPU compute buffer size =   280.01 MiB
# [2025-07-09 18:09:10.528] [info] [WASI-NN] llama.cpp: llama_context: graph nodes  = 582
# [2025-07-09 18:09:10.528] [info] [WASI-NN] llama.cpp: llama_context: graph splits = 1
# common_init_from_params: setting dry_penalty_last_n to ctx_size = 4096
# [2025-07-09 18:09:10.529] [info] [WASI-NN] GGML backend: llama_system_info: CPU : NEON = 1 | ARM_FMA = 1 | LLAMAFILE = 1 | REPACK = 1 |
# [2025-07-09 18:17:32.111] [warning] [WASI-NN] llama.cpp: check_double_bos_eos: Added a BOS token to the prompt as specified by the model but the prompt also starts with a BOS token. So now the final prompt starts with 2 BOS tokens. Are you sure this is what you want?
# [2025-07-09 18:17:32.114] [warning] [WASI-NN] llama.cpp: check_double_bos_eos: Added a BOS token to the prompt as specified by the model but the prompt also starts with a BOS token. So now the final prompt starts with 2 BOS tokens. Are you sure this is what you want?
# [2025-07-09 18:20:33.564] [info] [WASI-NN] GGML backend: sampleOutput: EOS token found.
# [2025-07-09 18:20:33.566] [info] [WASI-NN] llama.cpp: llama_perf_sampler_print:    sampling time =     228.91 ms /   534 runs   (    0.43 ms per token,  2332.80 tokens per second)
# [2025-07-09 18:20:33.566] [info] [WASI-NN] llama.cpp: llama_perf_context_print:        load time =  510750.30 ms
# [2025-07-09 18:20:33.566] [info] [WASI-NN] llama.cpp: llama_perf_context_print: prompt eval time =       0.00 ms /    28 tokens (    0.00 ms per token,      inf tokens per second)
# [2025-07-09 18:20:33.566] [info] [WASI-NN] llama.cpp: llama_perf_context_print:        eval time =       0.00 ms /   533 runs   (    0.00 ms per token,      inf tokens per second)
# [2025-07-09 18:20:33.566] [info] [WASI-NN] llama.cpp: llama_perf_context_print:       total time =  683783.35 ms /   561 tokens
```

### 6. Cleanup
```sh
cd
sudo k3s kubectl delete -f deployment.yaml

```