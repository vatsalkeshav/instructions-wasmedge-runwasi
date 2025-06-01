# Testing WasmEdge

## 1. Install k3s
i/p:
```sh
# install
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik" sh -
# verify
sudo k3s kubectl get nodes
```
o/p:
```sh
NAME     STATUS   ROLES                  AGE   VERSION
ubuntu   Ready    control-plane,master   1s    v1.32.5+k3s1
```

## 3. Hack
```sh
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
```
solves
```sh
dev@ubuntu:~$ kubectl --context kind-runwasi-cluster apply -f deploy.yaml
WARN[0000] Unable to read /etc/rancher/k3s/k3s.yaml, please start server with --write-kubeconfig-mode or --write-kubeconfig-group to modify kube config permissions
error: error loading config file "/etc/rancher/k3s/k3s.yaml": open /etc/rancher/k3s/k3s.yaml: permission denied
```

## 4. pod yaml

create yaml
```yaml
# wasm-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: wasmedge-test
spec:
  runtimeClassName: wasmedge  # / wasmtime : match the runtime in containerd config
  containers:
    - name: wasm-container
      image: ghcr.io/containerd/runwasi/wasi-demo-app:latest
      command: ["/wasi-demo-app"]
```
deploy it
```sh
sudo k3s kubectl apply -f wasm-pod.yaml
```
check logs (here, song is not shown)
```sh
sudo k3s kubectl logs wasmedge-test
```
check pod status
```sh
dev@ubuntu:~$ sudo k3s kubectl get pods
NAME            READY   STATUS             RESTARTS        AGE
wasmedge-test   0/1     CrashLoopBackOff   5 (2m41s ago)   5m51s
```

check events
```sh
dev@ubuntu:~$ sudo k3s kubectl describe pod wasmedge-test
Name:                wasmedge-test
Namespace:           default
Priority:            0
Runtime Class Name:  wasmedge
Service Account:     default
Node:                ubuntu/198.19.249.49
Start Time:          Sat, 21 Jun 2025 10:37:58 +0530
Labels:              <none>
Annotations:         <none>
Status:              Running
IP:                  10.42.0.5
IPs:
  IP:  10.42.0.5
Containers:
  wasm-container:
    Container ID:  containerd://3f2d0a9684e7991b449d065ca548106103f9ee6b3a1f4fd04939dd7e2349bc77
    Image:         ghcr.io/containerd/runwasi/wasi-demo-app:latest
    Image ID:      ghcr.io/containerd/runwasi/wasi-demo-app@sha256:1a5ef678e7425a98de8166d9e289e09e21d8a82312ad7e5c8bf9b961bb1f2666
    Port:          <none>
    Host Port:     <none>
    Command:
      /wasi-demo-app
    State:          Waiting
      Reason:       CrashLoopBackOff
    Last State:     Terminated
      Reason:       StartError
      Message:      failed to create containerd task: failed to create shim task: failed to create container: exec process failed with error error in executing process : wasmedge executor can't handle spec
      Exit Code:    128
      Started:      Thu, 01 Jan 1970 05:30:00 +0530
      Finished:     Sat, 21 Jun 2025 10:41:08 +0530
    Ready:          False
    Restart Count:  5
    Environment:    <none>
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-4hnxf (ro)
Conditions:
  Type                        Status
  PodReadyToStartContainers   True
  Initialized                 True
  Ready                       False
  ContainersReady             False
  PodScheduled                True
Volumes:
  kube-api-access-4hnxf:
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
  Type     Reason     Age                   From               Message
  ----     ------     ----                  ----               -------
  Normal   Scheduled  4m55s                 default-scheduler  Successfully assigned default/wasmedge-test to ubuntu
  Normal   Pulled     4m50s                 kubelet            Successfully pulled image "ghcr.io/containerd/runwasi/wasi-demo-app:latest" in 4.503s (4.503s including waiting). Image size: 2265395 bytes.
  Normal   Pulled     4m48s                 kubelet            Successfully pulled image "ghcr.io/containerd/runwasi/wasi-demo-app:latest" in 1.091s (1.091s including waiting). Image size: 2265395 bytes.
  Normal   Pulled     4m33s                 kubelet            Successfully pulled image "ghcr.io/containerd/runwasi/wasi-demo-app:latest" in 1.003s (1.003s including waiting). Image size: 2265395 bytes.
  Warning  Failed     4m32s                 kubelet            Error: failed to create containerd task: failed to create shim task: failed to create container: exec process failed with error error in executing process : wasmedge executor can't handle spec. error during cleanup: failed to cleanup container: failed to stop unit cri-containerd-wasm-container.scope: dbus error: dbus function call error: Unit cri-containerd-wasm-container.scope not loaded.
  Normal   Pulled     4m6s                  kubelet            Successfully pulled image "ghcr.io/containerd/runwasi/wasi-demo-app:latest" in 1.051s (1.051s including waiting). Image size: 2265395 bytes.
  Normal   Pulled     3m20s                 kubelet            Successfully pulled image "ghcr.io/containerd/runwasi/wasi-demo-app:latest" in 1.154s (1.155s including waiting). Image size: 2265395 bytes.
  Normal   Pulling    107s (x6 over 4m54s)  kubelet            Pulling image "ghcr.io/containerd/runwasi/wasi-demo-app:latest"
  Normal   Created    105s (x6 over 4m50s)  kubelet            Created container: wasm-container
  Warning  Failed     105s (x5 over 4m50s)  kubelet            Error: failed to create containerd task: failed to create shim task: failed to create container: exec process failed with error error in executing process : wasmedge executor can't handle spec
  Normal   Pulled     105s                  kubelet            Successfully pulled image "ghcr.io/containerd/runwasi/wasi-demo-app:latest" in 1.174s (1.178s including waiting). Image size: 2265395 bytes.
  Warning  BackOff    54s (x19 over 4m47s)  kubelet            Back-off restarting failed container wasm-container in pod wasmedge-test_default(30c30a71-4992-44e5-81ca-b78ca96da69e)
```

