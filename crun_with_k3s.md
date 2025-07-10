# Steps to use crun as default k3s' OCI runtime instead of runc

### 1. *First install crun, then k3s*
this saves time - as k3s recognizes crun as a runtime upon installation only

```sh
# install crun
sudo apt update
sudo apt install -y crun

# install k3s
curl -sfL https://get.k3s.io | sh - 
```

### 2. *Configure k3s' containerd's config to deffault to crun as OCI runtime*
k3s uses its own containerd which comes bundled with it
 
```sh
# check out-of-the-box default runtime
sudo crictl info | grep -A 10 "defaultRuntime"
# o/p :
      # "defaultRuntimeName": "runc",
      # "ignoreBlockIONotEnabledErrors": false,
      # "ignoreRdtNotEnabledErrors": false,
      # "runtimes": {
      #   "crun": {
      #     "ContainerAnnotations": null,
      #     "PodAnnotations": null,
      #     "baseRuntimeSpec": "",
      #     "cniConfDir": "",
      #     "cniMaxConfNum": 0,
      #     "io_type": "",

# configure k3s own containerd (k3s comes bundled with its own plugin)
sudo chmod 777 -R /var

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

# Restart k3s
sudo systemctl restart k3s

# check default runtime now
sudo crictl info | grep -A 10 "defaultRuntime"
# o/p :
      # "defaultRuntimeName": "crun",
      # "ignoreBlockIONotEnabledErrors": false,
      # "ignoreRdtNotEnabledErrors": false,
      # "runtimes": {
      #   "crun": {
      #     "ContainerAnnotations": null,
      #     "PodAnnotations": null,
      #     "baseRuntimeSpec": "",
      #     "cniConfDir": "",
      #     "cniMaxConfNum": 0,
      #     "io_type": "",
```

### *References* - 
1. https://docs.k3s.io/advanced#configuring-containerd
2. https://github.com/containerd/containerd/blob/release/2.0/docs/cri/config.md#runtime-classes