# scuttle
[![GoDoc](https://pkg.go.dev/badge/github.com/poseidon/scuttle.svg)](https://pkg.go.dev/github.com/poseidon/scuttle)
[![Quay](https://img.shields.io/badge/container-quay-green)](https://quay.io/repository/poseidon/scuttle)
[![Workflow](https://github.com/poseidon/scuttle/actions/workflows/test.yaml/badge.svg)](https://github.com/poseidon/scuttle/actions/workflows/test.yaml?query=branch%3Amain)
[![Sponsors](https://img.shields.io/github/sponsors/poseidon?logo=github)](https://github.com/sponsors/poseidon)
[![Twitter](https://img.shields.io/badge/follow-news-1da1f2?logo=twitter)](https://twitter.com/poseidonlabs)
[![Mastodon](https://img.shields.io/badge/follow-news-6364ff?logo=mastodon)](https://fosstodon.org/@poseidon)

<img align="right" src="https://storage.googleapis.com/poseidon/scuttle.png" width="40%">

`scuttle` handles SIGTERM or spot termination notices by optionally draining or deleting the current Kubernetes node. It's best run as a systemd unit designed to gracefully stop on shutdown (shown below).

* Uncordon the node on start (reboot case)
* Handle SIGTERM (unit stop or shutdown)
* Monitor instance metadata for termination notices (AWS, Azure planned)
* Drain and/or delete (de-register) a Kubernetes node
* Evict Pods left by Kubelet's GracefulNodeShutdown

`scuttle` compliments Kubelet's [GracefulNodeShutdown](https://kubernetes.io/docs/concepts/architecture/nodes/#graceful-node-shutdown) feature, which only handles a part of gracefully stopping the Kubelet. See the [blog post](https://www.psdn.io/posts/kubelet-graceful-shutdown/) to learn more. In effect, `scuttle` is just a Go implementation of the bash scripts shown in the posts.

## Usage

`scuttle` must be run in a systemd unit that is designed to stop before shutdown. Systemd shutdown can be subtle. Read [systemd Shutdown Units](https://www.psdn.io/posts/systemd-shutdown-unit/) and [Kubelet Graceful Shutdown](https://www.psdn.io/posts/kubelet-graceful-shutdown/) for background.

```systemd
[Unit]
Description=Scuttle Kubelet before Shutdown
After=multi-user.target
[Service]
Type=simple
ExecStartPre=-/usr/bin/podman rm scuttle
ExecStart=/usr/bin/podman run \
  --name scuttle \
  --network host \
  --log-driver=k8s-file \
  --env KUBECONFIG=/var/lib/kubelet/kubeconfig \
  -v /var/lib/kubelet:/var/lib/kubelet:ro,z \
  --stop-timeout=60 \
  quay.io/poseidon/scuttle:v0.1.0 \
  -platform=aws
ExecStop=/usr/bin/podman stop scuttle
TimeoutStopSec=180
SuccessExitStatus=143
[Install]
WantedBy=multi-user.target
```

Users of Fedora CoreOS or Flatcar Linux should use the Butane Config:

```yaml
variant: fcos
version: 1.4.0
systemd:
  units:
    - name: scuttle.service
      contents: |
        [Unit]
        Description=Scuttle Kubelet before Shutdown
        After=multi-user.target
        [Service]
        Type=simple
        ExecStartPre=-/usr/bin/podman rm scuttle
        ExecStart=/usr/bin/podman run \
          --name scuttle \
          --network host \
          --log-driver=k8s-file \
          --env KUBECONFIG=/var/lib/kubelet/kubeconfig \
          -v /var/lib/kubelet:/var/lib/kubelet:ro,z \
          --stop-timeout=60 \
          quay.io/poseidon/scuttle:261fc0f \
          -platform=aws
        ExecStop=/usr/bin/podman stop scuttle
        TimeoutStopSec=180
        SuccessExitStatus=143
        [Install]
        WantedBy=multi-user.target
    - name: scuttle.path
      enabled: true
      contents: |
        [Unit]
        Description=Watch for Kubelet kubeconfig
        [Path]
        PathExists=/var/lib/kubelet/kubeconfig
        [Install]
        WantedBy=multi-user.target
```

### Spot Termination Notices

[AWS](https://aws.amazon.com/blogs/aws/new-ec2-spot-instance-termination-notices/) and [Azure](https://learn.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-terminate-notification) provide warnings via instance metadata (2 min) before spot terminations. `scuttle` can monitor platform specific instance metadata endpoints to trigger drain or delete actions before shutdown.

* [AWS Spot Termination Notifications](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/spot-instance-termination-notices.html)
* [Azure Spot Termination Notifications](https://learn.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-terminate-notification#get-terminate-notifications)

## Development

To develop locally, build and run the executable.

### Static Binary

Build the static binary or container image.

```
make build
make image
```

### Run

Run the executable.

```
export KUBECONFIG=some-dev-kubeconfig
export HOSTNAME=node-name
./bin/scuttle
```

Use Ctrl-C to emulate a node shutdown.

```
INFO[0000] main: watch for interrupt signals
INFO[0000] main: starting scuttle
INFO[0000] start scuttle                                 hostname=ip-10-0-35-141
INFO[0000] scuttle: uncordon node                        hostname=ip-10-0-35-141
INFO[0000] drainer: uncordoning node                     node=ip-10-0-35-141
^C
INFO[0004] main: detected interrupt
INFO[0004] scuttle: stopping...                          hostname=ip-10-0-35-141
INFO[0004] scuttle: cordoning node                       hostname=ip-10-0-35-141
INFO[0004] drainer: cordoning node                       node=ip-10-0-35-141
INFO[0004] scuttle: draining node                        hostname=ip-10-0-35-141
WARN[0005] WARNING: ignoring DaemonSet-managed Pods: kube-system/cilium-gpdk8, kube-system/kube-proxy-cvwx5, monitoring/promtail-k9slg
INFO[0005] evicting pod default/redacted
...
INFO[0009] scuttle: deleting node                        hostname=ip-10-0-35-141
INFO[0009] done
```
