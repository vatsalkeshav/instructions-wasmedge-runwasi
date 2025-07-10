# How to configure k3s' containerd for


K3s comes bundled with its own containerd
  - So, don't install containerd any other way if stricly needed
  - it can be accessed using `k3s ctr` or just `ctr`



  ## 1. crun as OCI runtime
  1. `crun` can said to be the key to properly support wasmedge and wasmedge-shim in containerd and k3s environment
  2. Build and install `crun with wasmedge support`
  ```sh

  ```


  ## 2. Runwasi shims as plugins
 ### 1. Wasmedge shim
As we're mostly working with `wasmedge` and `runwasi's wasmedge shim`,
1. Install wasmedge