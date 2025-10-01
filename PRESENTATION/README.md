---

marp: true
theme: uncover
class: invert

---

## LFX Mentorship with __WasmEdge__

### __*Use Runwasi with WasmEdge runtime to test multiple WASM apps as cloud services*__

```sh

  Mentee - github@vatsalkeshav

  Mentors - Vincent Lin, Yi Huang  

```

---

### __Goals?__

1. __How to configure the WASI-NN plugin system in k8s__

2. __Explore how to integrate HTTP service and the plugin system in a multi-node k8s setup__ 

---

### __Goal 1__
####  *Verifying configuration of the WASI-NN plugin system in k8s*

  - *how to configure the env-vars and dy-libs (plugin and plugin dependencies) loading paths*
   
  - *CI to verify the result*

---

<small>__Goal 1__ - *Verifying configuration of the WASI-NN in k8s*</small>

### __Knowledge__

- __WASI-NN plugin__

  wasi-nn is a WASI API for performing ML inference. Its name derives from the fact that ML models are also known as neural networks (nn).

  It can be utilized as a WasmEdge plugin.

---

<small>__Goal 1__ - *Verifying configuration of the WASI-NN in k8s*</small>

### __Knowledge__

- __WasmEdge__

  It's a WASM runtime for cloud native, edge etc. applications
  
  Has major role in replacing traditional linux containers

- __Runwasi's WasmEdge Runtime__

  Facilitates running WASM workloads managed by containerd either directly (ie. through ctr) or as directed by Kubelet via the CRI plugin.

---

#### How WASM replaces traditional containers?

![height:5in](./diagrams/runwasi-working.png) 

---
<small>__Goal 1__ - *Verifying configuration of the WASI-NN in k8s*</small>

#### How WASM replaces traditional containers?
### Benefits
  - sandboxed environment running WASM binary
  - When tradional container technology like docker is replaced by runwasi's wasmedge container runtime, the image size, its build time and container-boot-up time all get reduced to as low as 90% 
  (and that's WASM being humble)

---

#### __Goal 1__ - *Verifying configuration of the WASI-NN plugin system in k8s*

Achieved by mounting of all the dependencies of `/.wasmedge/plugin/libwasmedgePluginWasiNN.so` (as listed by `ldd`) to the pod.

- [deployment.yaml](https://github.com/second-state/runwasi-wasmedge-demo/pull/1/files#diff-fbbf711e740b281368e1b83c7748555ce060f6431087f93b504e904f437a8179)

---
#### Like this

```yaml
volumeMounts:
            - name: wasi-nn-plugin-file
              mountPath: /home/runner/.wasmedge/plugin/libwasmedgePluginWasiNN.so
              readOnly: true
            - name: wasi-nn-plugin-lib
              mountPath: /home/runner/.wasmedge/lib
              readOnly: true
              .
              .
volumes:
            - name: wasi-nn-plugin-file
              hostPath:
                path: /home/runner/.wasmedge/plugin/libwasmedgePluginWasiNN.so
                type: File
            - name: wasi-nn-plugin-lib
              hostPath:
                path: /home/runner/.wasmedge/lib
                type: Directory
                .
                .
```
---

<small>__Goal 1__ - *Verifying configuration of the WASI-NN in k8s*</small>

#### Helm usage

Since the volume mounts were
  1. many
  2. repetetive

a helm template was also made
- [usage](https://github.com/second-state/runwasi-wasmedge-demo/pull/4/files#diff-ea1e2069ffb1ab80506d93b285fbf7f914db2aed351cb05ec0a34955df15bc4f)
- [template](https://github.com/second-state/runwasi-wasmedge-demo/pull/4/files#diff-e7839de248ccbc127370394582491fe095c9ce356762c9d71ab7d76a5fc3329c)

<sub>*__Helm Charts__ is used to define, install, and upgrade even the most complex Kubernetes application*</sub>

---

<small>__Goal 1__ - *Verifying configuration of the WASI-NN in k8s*</small>

#### [Pod Tests](https://github.com/second-state/runwasi-wasmedge-demo/pull/2)

  - pre-request and post-request pod health checks - generating reports on pod status, container readiness, restarts, events, and resource usage, saved in $HOME/logs/

  - service health check - logs endpoints, service status, service info etc. also saved in $HOME/logs/

  - final test summary report - aggregating service, pod, and API test results, documenting the logs directory structure etc.

---

<small>__Goal 1__ - *Verifying configuration of the WASI-NN in k8s*</small>

#### [CI](https://github.com/second-state/runwasi-wasmedge-demo/actions/runs/18052415235/job/51376714128) to verify the result

---

Goal 1 achieved :D

---

### __Goals?__

1. __How to configure the WASI-NN plugin system in k8s__

2. __Explore how to integrate HTTP service and the plugin system in a multi-node k8s setup__ 

---

### __Goal 2__
####  *Explore how to integrate HTTP service and the plugin system in a multi-node k8s setup*

  - *The goal being to showcase how this ecosystem can be effectively deployed in the cloud*

  - *CI to verify the result*

---

<small>__Goal 2__ - *integrate HTTP service and the plugin system in k8s*</small>


- #### Prototype - [multi-pod-wasm-demo](https://github.com/vatsalkeshav/multi-pod-demo-wasm)

- ### Final Deliverable - [load-bal-llamaedge-demo](https://github.com/vatsalkeshav/load-bal-llamaedge-demo)

---

<small>__Goal 2__ - *integrate HTTP service and the plugin system in k8s*</small>

### Dynamic Service Registration
(demo)

---

<small>__Goal 2__ - *integrate HTTP service and the plugin system in k8s*</small>

### [CI and Pod Tests]
[link](https://github.com/vatsalkeshav/load-bal-llamaedge-demo/actions/runs/18084587501/job/51453450494)

---

Goal 2 achieved :D :D

---

Thanks 
`_||_`

.
.
.

Please read the blog - 
<sub>[dev.to/vatsalkeshav/a-journey-with-k3s-through-wasm32-wasip1-gb8](dev.to/vatsalkeshav/a-journey-with-k3s-through-wasm32-wasip1-gb8)</sub>

---