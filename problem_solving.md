
```sh
$ sudo k3s kubectl get pods
NAME                         READY   STATUS   RESTARTS     AGE
llama-api-56c566d446-h4n7z   0/1     Error    1 (3s ago)   4s
```

```sh
$ sudo k3s kubectl logs pod/llama-api-56c566d446-h4n7z
[2025-07-06 05:03:41.640] [error] instantiation failed: unknown import, Code: 0x302
[2025-07-06 05:03:41.640] [error]     When linking module: "wasi_ephemeral_nn" , function name: "compute"
[2025-07-06 05:03:41.640] [error]     At AST node: import description
[2025-07-06 05:03:41.640] [error]     At AST node: import section
[2025-07-06 05:03:41.640] [error]     At AST node: module
```

```sh
$ sudo k3s kubectl describe pod llama-api-56c566d446-h4n7z
Name:                llama-api-56c566d446-h4n7z
Namespace:           default
Priority:            0
Runtime Class Name:  wasmedge
Service Account:     default
Node:                ubuntu/198.19.249.218
Start Time:          Sun, 06 Jul 2025 09:59:31 +0530
Labels:              app=llama-api
                     pod-template-hash=56c566d446
Annotations:         <none>
Status:              Running
IP:                  10.42.0.15
IPs:
  IP:           10.42.0.15
Controlled By:  ReplicaSet/llama-api-56c566d446
Containers:
  llama-api:
    Container ID:  containerd://771769f0b52abc9651298707cba09d84af8728067d2fa1494a927198cd83e675
    Image:         ghcr.io/second-state/llama-api-server:latest
    Image ID:      sha256:f4c5452c554f9cc44681f6696b0151763e84b6e8414343904fb0feff533e56ea
    Port:          <none>
    Host Port:     <none>
    Command:
      llama-api-server.wasm
    Args:
      --prompt-template
      $(PROMPT_TEMPLATE)
      --ctx-size
      $(CTX_SIZE)
      --model-name
      $(MODEL_NAME)
    State:          Terminated
      Reason:       Error
      Exit Code:    137
      Started:      Sun, 06 Jul 2025 09:59:47 +0530
      Finished:     Sun, 06 Jul 2025 09:59:48 +0530
    Last State:     Terminated
      Reason:       Error
      Exit Code:    137
      Started:      Sun, 06 Jul 2025 09:59:32 +0530
      Finished:     Sun, 06 Jul 2025 09:59:33 +0530
    Ready:          False
    Restart Count:  2
    Environment:
      WASMEDGE_PLUGIN_PATH:     /home/$(whoami)/.wasmedge/plugin/libwasmedgePluginWasiNN.so
      WASMEDGE_WASINN_PRELOAD:  default:GGML:CPU:/models/Llama-3.2-1B-Instruct-Q5_K_M.gguf
      PROMPT_TEMPLATE:          <set to the key 'PROMPT_TEMPLATE' of config map 'llama-config'>  Optional: false
      CTX_SIZE:                 <set to the key 'CTX_SIZE' of config map 'llama-config'>         Optional: false
      MODEL_NAME:               <set to the key 'MODEL_NAME' of config map 'llama-config'>       Optional: false
    Mounts:
      /models from models (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-fkpdx (ro)
Conditions:
  Type                        Status
  PodReadyToStartContainers   True
  Initialized                 True
  Ready                       False
  ContainersReady             False
  PodScheduled                True
Volumes:
  models:
    Type:          HostPath (bare host directory volume)
    Path:          /mnt/models
    HostPathType:  Directory
  kube-api-access-fkpdx:
    Type:                    Projected (a volume that contains injected data from multiple sources)
    TokenExpirationSeconds:  3607
    ConfigMapName:           kube-root-ca.crt
    ConfigMapOptional:       <nil>
    DownwardAPI:             true
QoS Class:                   BestEffort
Node-Selectors:              <none>
Tolerations:                 node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                             node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
Events:
  Type     Reason     Age               From               Message
  ----     ------     ----              ----               -------
  Normal   Scheduled  23s               default-scheduler  Successfully assigned default/llama-api-56c566d446-h4n7z to ubuntu
  Normal   Pulled     7s (x3 over 23s)  kubelet            Container image "ghcr.io/second-state/llama-api-server:latest" already present on machine
  Normal   Created    7s (x3 over 23s)  kubelet            Created container: llama-api
  Normal   Started    7s (x3 over 23s)  kubelet            Started container llama-api
  Warning  BackOff    6s (x2 over 21s)  kubelet            Back-off restarting failed container llama-api in pod llama-api-56c566d446-h4n7z_default(d813b3cc-360e-4239-8381-8576ddca1844)
```

```toml
# apps/llamaedge/Cargo.toml
[workspace.dependencies]
  wasmedge-wasi-nn = "0.8.0"
```

```sh
wasm2wat ~/runwasi-wasmedge-demo/apps/llamaedge/llama-api-server/target/wasm32-wasip1/release/llama-api-server.wasm | grep import
  (import "wasi_ephemeral_nn" "compute" (func $_ZN16wasmedge_wasi_nn9generated17wasi_ephemeral_nn7compute17h1368f0f171af6b48E (type 7)))
  (import "wasi_ephemeral_nn" "set_input" (func $_ZN16wasmedge_wasi_nn9generated17wasi_ephemeral_nn9set_input17h732b1244e9b53e4aE (type 4)))
  (import "wasi_ephemeral_nn" "get_output" (func $_ZN16wasmedge_wasi_nn9generated17wasi_ephemeral_nn10get_output17h743c55da8d36c815E (type 12)))
  (import "wasi_ephemeral_nn" "fini_single" (func $_ZN16wasmedge_wasi_nn9generated17wasi_ephemeral_nn11fini_single17h19c691fd62e58ca8E (type 7)))
  (import "wasi_ephemeral_nn" "compute_single" (func $_ZN16wasmedge_wasi_nn9generated17wasi_ephemeral_nn14compute_single17h99c4cd6a5da0b69cE (type 7)))
  (import "wasi_ephemeral_nn" "get_output_single" (func $_ZN16wasmedge_wasi_nn9generated17wasi_ephemeral_nn17get_output_single17ha68d302117099877E (type 12)))
  (import "wasi_ephemeral_nn" "load_by_name_with_config" (func $_ZN16wasmedge_wasi_nn9generated17wasi_ephemeral_nn24load_by_name_with_config17he721b5296d83c70cE (type 12)))
  (import "wasi_ephemeral_nn" "init_execution_context" (func $_ZN16wasmedge_wasi_nn9generated17wasi_ephemeral_nn22init_execution_context17h740b82f59ce002b2E (type 8)))
  (import "wasi_ephemeral_nn" "unload" (func $_ZN16wasmedge_wasi_nn9generated17wasi_ephemeral_nn6unload17h079a84a8751e81bdE (type 7)))
  (import "wasi_snapshot_preview1" "random_get" (func $_ZN9getrandom8backends7wasi_p110random_get17h3aa4f5a722d08583E (type 8)))
  (import "wasi_snapshot_preview1" "sock_setsockopt" (func $_ZN20wasmedge_wasi_socket6socket9wasi_sock15sock_setsockopt17h68da5211e9444335E (type 12)))
  (import "wasi_snapshot_preview1" "sock_getaddrinfo" (func $_ZN20wasmedge_wasi_socket6socket12WasiAddrinfo12get_addrinfo16sock_getaddrinfo17hb27de64fc9c323adE (type 23)))
  (import "wasi_snapshot_preview1" "sock_open" (func $_ZN20wasmedge_wasi_socket6socket9wasi_sock9sock_open17h6ca3f4d88dd5ea06E (type 4)))
  (import "wasi_snapshot_preview1" "sock_send" (func $_ZN20wasmedge_wasi_socket6socket9wasi_sock9sock_send17hb6b8d4185a45d601E (type 12)))
  (import "wasi_snapshot_preview1" "sock_recv" (func $_ZN20wasmedge_wasi_socket6socket9wasi_sock9sock_recv17h55977ed90b55f634E (type 24)))
  (import "wasi_snapshot_preview1" "sock_connect" (func $_ZN20wasmedge_wasi_socket6socket9wasi_sock12sock_connect17h6b8d38de8a4fc2b4E (type 4)))
  (import "wasi_snapshot_preview1" "sock_bind" (func $_ZN20wasmedge_wasi_socket6socket9wasi_sock9sock_bind17h821b838ac8c4e8f4E (type 4)))
  (import "wasi_snapshot_preview1" "sock_listen" (func $_ZN20wasmedge_wasi_socket6socket9wasi_sock11sock_listen17h89e9c80f251cc782E (type 8)))
  (import "wasi_snapshot_preview1" "sock_accept" (func $_ZN20wasmedge_wasi_socket6socket9wasi_sock11sock_accept17heee1e56b2da7aceeE (type 8)))
  (import "wasi_snapshot_preview1" "sock_shutdown" (func $_ZN20wasmedge_wasi_socket6socket9wasi_sock13sock_shutdown17h57ae8af4b64d6de7E (type 8)))
  (import "wasi_snapshot_preview1" "sock_getlocaladdr" (func $_ZN20wasmedge_wasi_socket6socket9wasi_sock17sock_getlocaladdr17h3d855498691c252aE (type 18)))
  (import "wasi_snapshot_preview1" "sock_getpeeraddr" (func $_ZN20wasmedge_wasi_socket6socket9wasi_sock16sock_getpeeraddr17h4ac2dc7b09f98951E (type 18)))
  (import "wasi_snapshot_preview1" "args_get" (func $_ZN4wasi13lib_generated22wasi_snapshot_preview18args_get17h22cb7bf2bc76ee33E (type 8)))
  (import "wasi_snapshot_preview1" "args_sizes_get" (func $_ZN4wasi13lib_generated22wasi_snapshot_preview114args_sizes_get17hfd7e6e1871385dc9E (type 8)))
  (import "wasi_snapshot_preview1" "clock_time_get" (func $_ZN4wasi13lib_generated22wasi_snapshot_preview114clock_time_get17hf9ba4d0377c4ddadE (type 25)))
  (import "wasi_snapshot_preview1" "fd_fdstat_get" (func $_ZN4wasi13lib_generated22wasi_snapshot_preview113fd_fdstat_get17hd6ce45d667ddc54dE (type 8)))
  (import "wasi_snapshot_preview1" "fd_fdstat_set_flags" (func $_ZN4wasi13lib_generated22wasi_snapshot_preview119fd_fdstat_set_flags17hec7da231d781f8b8E (type 8)))
  (import "wasi_snapshot_preview1" "fd_filestat_get" (func $_ZN4wasi13lib_generated22wasi_snapshot_preview115fd_filestat_get17h4c1a298cd7822681E (type 8)))
  (import "wasi_snapshot_preview1" "fd_read" (func $_ZN4wasi13lib_generated22wasi_snapshot_preview17fd_read17h9c5a02e372fa1c43E (type 18)))
  (import "wasi_snapshot_preview1" "fd_readdir" (func $_ZN4wasi13lib_generated22wasi_snapshot_preview110fd_readdir17h9023b5be0357994cE (type 26)))
  (import "wasi_snapshot_preview1" "fd_tell" (func $_ZN4wasi13lib_generated22wasi_snapshot_preview17fd_tell17hfea8b729d1f2d0bbE (type 8)))
  (import "wasi_snapshot_preview1" "fd_write" (func $_ZN4wasi13lib_generated22wasi_snapshot_preview18fd_write17h33aeb12ec25abb21E (type 18)))
  (import "wasi_snapshot_preview1" "path_create_directory" (func $_ZN4wasi13lib_generated22wasi_snapshot_preview121path_create_directory17h3bd525c813cc3d24E (type 4)))
  (import "wasi_snapshot_preview1" "path_filestat_get" (func $_ZN4wasi13lib_generated22wasi_snapshot_preview117path_filestat_get17ha1e4dd55a19006b1E (type 12)))
  (import "wasi_snapshot_preview1" "path_open" (func $_ZN4wasi13lib_generated22wasi_snapshot_preview19path_open17h24152001420e8094E (type 27)))
  (import "wasi_snapshot_preview1" "path_remove_directory" (func $_ZN4wasi13lib_generated22wasi_snapshot_preview121path_remove_directory17h25401549b99bba71E (type 4)))
  (import "wasi_snapshot_preview1" "path_unlink_file" (func $_ZN4wasi13lib_generated22wasi_snapshot_preview116path_unlink_file17h24addead4e709e60E (type 4)))
  (import "wasi_snapshot_preview1" "poll_oneoff" (func $_ZN4wasi13lib_generated22wasi_snapshot_preview111poll_oneoff17hefb3091322d3cdb4E (type 18)))
  (import "wasi_snapshot_preview1" "sched_yield" (func $_ZN4wasi13lib_generated22wasi_snapshot_preview111sched_yield17h5322265a3606de1cE (type 11)))
  (import "wasi_snapshot_preview1" "environ_get" (func $__imported_wasi_snapshot_preview1_environ_get (type 8)))
  (import "wasi_snapshot_preview1" "environ_sizes_get" (func $__imported_wasi_snapshot_preview1_environ_sizes_get (type 8)))
  (import "wasi_snapshot_preview1" "fd_close" (func $__imported_wasi_snapshot_preview1_fd_close (type 7)))
  (import "wasi_snapshot_preview1" "fd_prestat_get" (func $__imported_wasi_snapshot_preview1_fd_prestat_get (type 8)))
  (import "wasi_snapshot_preview1" "fd_prestat_dir_name" (func $__imported_wasi_snapshot_preview1_fd_prestat_dir_name (type 4)))
  (import "wasi_snapshot_preview1" "proc_exit" (func $__imported_wasi_snapshot_preview1_proc_exit (type 0)))
```