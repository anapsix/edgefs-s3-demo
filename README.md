# Demo of EdgeFS Cluster with S3 service in Docker

> Based on [Data Geo-Transparency with EdgeFS on Mac for Developers][source-article].

[EdgeFS][edgefs] is a high performance highly-available multi-cloud geo-distributed storage system with deep Kubernetes integration supporting NFS, iSCSI, S3, S3X, and [CSI][csi-spec] (also see [K8s CSI][k8s-csi]).


## Usage

1. Clone the repo
    > If you a Mac user, make sure to clone it into one of the (sub)directories shared with Docker on Mac; by default user's home directory is shared, so anything under `/Users` should work. You can check which directories shared with Docker for Mac via `Preferences > File Sharing`

2. For basic demo cluster setup with S3 service, use included `init.sh` script:
    ```bash
    ./init.sh
    ```

3. Feel free to change `docker-compose.yml`, experiment with [ISGW][isgw] (inter-segment gateway), iSCSI service, etc..


[Link Reference]::
[source-article]: https://medium.com/edgefs/data-geo-transparency-with-edgefs-on-mac-for-developers-58d95f8672de
[edgefs]: http://edgefs.io/
[csi-spec]: https://github.com/container-storage-interface/spec
[k8s-csi]: https://kubernetes-csi.github.io/docs/
[isgw]: https://rook.io/docs/rook/master/edgefs-isgw-crd.html
