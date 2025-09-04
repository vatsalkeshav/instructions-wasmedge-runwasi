# A journey through __*wasm32-wasip1*__
## _LFX Mentorship_ : __Use Runwasi with WasmEdge runtime to test multiple WASM apps as cloud services__

`it's a sea of fire - you need to drown to be ashore.`

### __The Fellowship__
I applied for this quest on the LFX mentorship portal, prepared the pre-test and this journey started. Me, Rust and the wise mentors by my side - Vincent Lin and Yi Huang - were the pilgrims.

*What was the underlying motivation behind all this?*
With WasmEdge serving as one of Runwasi’s standard runtimes, and as its C++ implemented library continues to evolve, there was a need for a verification process integrated into Runwasi to streamline and validate the stability of both container and cloud environments.

*What was there to be achieved?*
 1. Research of the relevant codebase, tools, and environment setup procedures.
 2. Verification of the system’s behavior under Kubernetes (k8s).
 3. Confirmation on how the plugin system should be configured in a k8s environment — for example, environment variables or dynamic library (plugin and plugin dependencies) loading paths.
 4. Creation of a CI repository that we could use to verify the integration yourself and show results.
 5. For the creative aspect, exploring how to integrate HTTP service and the plugin system in a multi-node setup. The goal being to showcase how this ecosystem can be effectively deployed in the cloud.

### __The Forest__
_This might seem easy to some, but it was not, maybe for me, atleast at that time_

It began in a young but dense, questioning but well-documented forest of WASM. It took nearly 3 weeks of training and navigation to finally achieve something.

I started out with systematic baby steps - deploying simple WASM's like `ghcr.io/containerd/runwasi/wasi-demo-app:latest` in Kind and k3s environments as WASM pods. It was my first time learning about pods, let alone WASM pods. A shining knight named k3s joined as the 5th member on this quest from this point on.
```yaml
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
```

Around that time, we also explored containerd OCI runtimes like crun and containerd shims like runwasi's wasmedge, wasmer and wasmtime shims for the sake of learning - It felt really great getting code 0 after spending 4 days (and nights) figuring out how to replace k3s's containerd's (k3s uses the containerd that comes bundled with it) OCI runtime runc to crun.
```sh
# this config.toml.tmpl helps k3s generate it's config.toml(existant in same dir) as a copy of config.toml.tmpl
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

[plugins."io.containerd.cri.v1.runtime".containerd]
  default_runtime_name = "crun"
  [plugins."io.containerd.cri.v1.runtime".containerd.runtimes]
    [plugins."io.containerd.cri.v1.runtime".containerd.runtimes.crun]
      runtime_type = "io.containerd.runc.v2"
      [plugins."io.containerd.cri.v1.runtime".containerd.runtimes.crun.options]
        BinaryName = "/usr/local/bin/crun"
        SystemdCgroup = true

[plugins.'io.containerd.cri.v1.images'.registry]
  config_path = "/var/lib/rancher/k3s/agent/etc/containerd/certs.d"
EOF
```

Although it didn't directly contribute to the project (which was learned later) but it made me know that

`momentum and attracts more momentum, eventually transforming to code 0's` 

so do whatever you can to gain that. And that had been gained.
![Architecture Diagram](./diagrams/blog1(1).png)

### __The Valley__
_Out of the Forest, into the Valley of k8s_

The valley of Kubernetes was where LlamaEdge's llama-api-server was to be deployed in Kubernetes. Everything was a breeze until a blocker was encountered - it was simple - the pod was hung at `container restarting`. So inititated the Art of Deduction which called to do all sorts of things 
 - look at the logs of the llama-api-server pod,
    ```sh
    sudo k3s kubectl logs pod/llama-api-56c566d446-h4n7z
    [2025-07-06 05:03:41.640] [error] instantiation failed: unknown import, Code: 0x302
    [2025-07-06 05:03:41.640] [error]     When linking module: "wasi_ephemeral_nn" , function name: "compute"
    [2025-07-06 05:03:41.640] [error]     At AST node: import description
    [2025-07-06 05:03:41.640] [error]     At AST node: import section
    [2025-07-06 05:03:41.640] [error]     At AST node: module 
    ```
 - wasm2wat the compiled wasm binary
    ```sh
    wasm2wat ~/runwasi-wasmedge-demo/apps/llamaedge/llama-api-server/target/wasm32-wasip1/release/llama-api-server.wasm | grep import
    (import "wasi_ephemeral_nn" "compute" (func $_ZN16wasmedge_wasi_nn9generated17wasi_ephemeral_nn7compute17h1368f0f171af6b48E (type 7)))
    (import "wasi_ephemeral_nn" "set_input" (func $_ZN16wasmedge_wasi_nn9generated17wasi_ephemeral_nn9set_input17h732b1244e9b53e4aE (type 4)))
    (import "wasi_ephemeral_nn" "get_output" (func $_ZN16wasmedge_wasi_nn9generated17wasi_ephemeral_nn10get_output17h743c55da8d36c815E (type 12)))
    (import "wasi_ephemeral_nn" "fini_single" (func $_ZN16wasmedge_wasi_nn9generated17wasi_ephemeral_nn11fini_single17h19c691fd62e58ca8E (type 7)))
    ```
Still having no clue (no right clue atleast), I asked Vincent and learned that that nothing beats experience -
```sh
"My guess is that plugin dynamic lib might not have been detected during the execution lifecycle of runwasi when launched via k3s."

- Vincent Lin
```

A little more brainstorming and hit and trial - and so the mounting of all the dependencies of `/.wasmedge/plugin/libwasmedgePluginWasiNN.so` (as listed by `ldd`) to the container was done
```yaml
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
              value: "/home/runner/.wasmedge/plugin"
            - name: LD_LIBRARY_PATH
              value: "/home/runner/.wasmedge/lib"
            - name: WASMEDGE_WASINN_PRELOAD
              value: "default:GGML:CPU:/home/runner/models/Llama-3.2-1B-Instruct-Q5_K_M.gguf"
          volumeMounts:
            - name: gguf-model-file
              mountPath: /home/runner/models/Llama-3.2-1B-Instruct-Q5_K_M.gguf
              readOnly: true
            - name: wasi-nn-plugin-file
              mountPath: /home/runner/.wasmedge/plugin/libwasmedgePluginWasiNN.so
              readOnly: true
            - name: wasi-nn-plugin-lib
              mountPath: /home/runner/.wasmedge/lib
              readOnly: true
            - name: libm
              mountPath: /lib/x86_64-linux-gnu/libm.so.6
              readOnly: true
            - name: libpthread
              mountPath: /lib/x86_64-linux-gnu/libpthread.so.0
              readOnly: true
            - name: libc
              mountPath: /lib/x86_64-linux-gnu/libc.so.6
              readOnly: true
            - name: ld-linux
              mountPath: /lib64/ld-linux-x86-64.so.2
              readOnly: true
            - name: libdl
              mountPath: /lib/x86_64-linux-gnu/libdl.so.2
              readOnly: true
            - name: libstdcxx
              mountPath: /lib/x86_64-linux-gnu/libstdc++.so.6
              readOnly: true
            - name: libgcc-s
              mountPath: /lib/x86_64-linux-gnu/libgcc_s.so.1
              readOnly: true
      volumes:
        - name: gguf-model-file
          hostPath:
            path: /home/runner/models/Llama-3.2-1B-Instruct-Q5_K_M.gguf
            type: File
        - name: wasi-nn-plugin-file
          hostPath:
            path: /home/runner/.wasmedge/plugin/libwasmedgePluginWasiNN.so
            type: File
        - name: wasi-nn-plugin-lib
          hostPath:
            path: /home/runner/.wasmedge/lib
            type: Directory
        - name: libm
          hostPath:
            path: /lib/x86_64-linux-gnu/libm.so.6
            type: File
        - name: libpthread
          hostPath:
            path: /lib/x86_64-linux-gnu/libpthread.so.0
            type: File
        - name: libc
          hostPath:
            path: /lib/x86_64-linux-gnu/libc.so.6
            type: File
        - name: ld-linux
          hostPath:
            path: /lib64/ld-linux-x86-64.so.2
            type: File
        - name: libdl
          hostPath:
            path: /lib/x86_64-linux-gnu/libdl.so.2
            type: File
        - name: libstdcxx
          hostPath:
            path: /lib/x86_64-linux-gnu/libstdc++.so.6
            type: File
        - name: libgcc-s
          hostPath:
            path: /lib/x86_64-linux-gnu/libgcc_s.so.1
            type: File
```
and like that, The project passed the mid-term evaluation with fying colours.

We towed an old friend named GitHub actions to lay rail tracks to here as a CI was written to run daily as a verfication step.
[link]

This effort might even help the official LlamaEdge scrolls.
[link]

### __The Mountain__
Next to be conquered was a mountain that required that we integrate an HTTP service and the WASI-NN plugin system in a multi-node setup.

A sage was seen there. -----------------(1)

This was relatively smoother - Rust designed a prototype `multi-wasm-pod-demo`
![Architecture Diagram](./diagrams/blog1(1).png)
which later evolved to `load-bal-llamaedge-demo` - This demo featured LlamaEdge's llama-api-server (as WASM-pods) runnning different gguf models in a multi-pod environment - all managed by a load-balancer (also a WASM-pod) - assisted by a service-watcher utilizing kube-rs client (a regular non-WASM pod) -
[link]

A chasm was encountered - wasm pods (run with the help of runwasi's wasmedge shim) was not resolving dns from the service names. At that time, we also wanted a fully automatic k8s style dynamic service management for our backend llama-api-server pods, so we went ahead with a non-WASM pod service-watcher pod utilizing the kube-rs client. --------------------(2)

![Architecture Diagram](./diagrams/blog1(1).png)

Going the extra mile, rail tracks to its peak were also laid.
[link]

On the way back, I asked the sage @hydai how to cross the chasm. He told that it was no chasm, just a shallow foggy area that required the use of latest tokio_wasi crate and DNS_SERVER environment variable in the yaml deployment configuration. Once again, `nothing beats experience`.
-----------------from (1) and (2)
[link]

### __The Pod Tests__
_Identity is an illusion, name itself is an analogy and efforts aren't always not boring_

Some pod tests were introduced in the CI of both .github/workflows/k3s_ci.yml from runwasi-wasmedge-demo and .github/workflows/ci.yml from load-bal-llamaedge-demo - thanks to a reliable ally Mr. Bash Scripting.
 - pre-request and post-request pod health checks - generating reports on pod status, container readiness, restarts, events, and resource usage
 - service health check - logs endpoints, service status, service info etc.
 - (only for `load-bal-llamedge-demo`) load-balancer pod logs separated by event markers
    ```yml
      - name: Collect load-balancer Pod Logs (Pre-Sequential Test)
        run: |
            cd $HOME

            LB_POD=$(sudo k3s kubectl get pod -l app=load-balancer -o jsonpath='{.items[0].metadata.name}')
            LOG_FILE="$HOME/logs/lb_pod_logs_combined.md"
            touch LOG_FILE

            NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

            # determine last timestamp from file
            if grep -q "^@@ LAST_TS=" "$LOG_FILE" 2>/dev/null; then
                LAST_TS=$(tail -n 1 "$LOG_FILE" | sed 's/^@@ LAST_TS=//')
                RANGE_OPT="--since-time=$LAST_TS"

                # time diff
                LAST_UNIX=$(date -d "$LAST_TS" +%s)
                NOW_UNIX=$(date -d "$NOW" +%s)
                DIFF=$((NOW_UNIX - LAST_UNIX))
                DIFF_STR=" (after ${DIFF}s)"

                # next index
                INDEX=$(( $(grep -c "^=== Pod logs" "$LOG_FILE") + 1 ))
            else
                RANGE_OPT=""
                DIFF_STR=""
                INDEX=1
            fi

            # append marker
            {
                echo ""
                echo "=== Pod logs (Pre-Sequential Test) $INDEX - $NOW$DIFF_STR ==="
            } >> "$LOG_FILE"

            # append new logs
            sudo k3s kubectl logs "$LB_POD" --timestamps $RANGE_OPT >> "$LOG_FILE"

            # save last timestamp marker inside same file
            echo "@@ LAST_TS=$NOW" >> "$LOG_FILE"

            echo "Logs appended to: $LOG_FILE (entry $INDEX)"
    ```
    which is a little interesting

### __The Jewel Mines__
_The mountain was golden!_
Journey itself is home and it had found me my riches before exiting with code 0. Turned out there was a gold mine beneath the mountain - another realm of outworldly flamboyance.
This quest demonstrates a real-world scenario as to how WASM workloads can efficiently replace traditional container/vm/etc. approches of cloud deployment.

 - *__LlamaEdge writing AI servers to run on the edge (in Rust too!)__*
 - *__WasmEdge replacing traditional containers with WASM ones__*

these are the 2 of the *biggest leaps in tech of our decade* and thanks to this mentorship program, I had the opportunity to learn and work with them.

### __End of The Beginning__
_Stories are never complete_
The `service-watcher` from `load-bal-llamaedge-demo` is still run a non-WASM pod because it uses `kube-rs` and `k8s-opensapi` as dependencies which in turn depend on
```sh
reqwest → hyper → tokio → socket2
```
all of which assume native sockets, threads, and system TLS (Refer cargo tree of kube-rs and k8s-openapi : https://github.com/vatsalkeshav/load-bal-llamaedge-demo/blob/master/watcher/cargo.md)

While WasmEdge provides forks like `tokio-wasi`, `reqwest-wasi`, `hyper-wasi`, `socket` etc. - `kube-rs` has hard dependencies on the native crates, so they won’t link without patching `kube-rs` itself. Given this, running the watcher as a traditional pod seems more practical for now but there'd be nothing better if the service-watcher would complile to wasm32-wasip1 target.

### __Never Forgetti__
```
“The mirror reflects not just your image, but the story of your strength, resilience, and grace.” 
- Dalai Lama
```

My growth here is a reflection of your guidance - your support through challenges and encouragement in successes - Thank you [Vincent Lin](https://github.com/CaptainVincent) and [Yi Huang](https://github.com/0yi0)

I'm also glad to have the opportunity to be a part of and be helped by the [WasmEdge](https://cloud-native.slack.com/archives/C0215BBK248/p1754502803786039) and [Runwasi](https://cloud-native.slack.com/archives/C04LTPB6Z0V/p1754502430462249) communities.

Thanks [@hydai](https://github.com/hydai) for helping me with the dns resolution (:

Thanks [@steel-bucket](https://github.com/steel-bucket) for being such an helpful dev and a fierce friend.

Above all, thanks Linux Foundation and CNCF.
