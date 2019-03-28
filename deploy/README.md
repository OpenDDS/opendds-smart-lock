
## Deploy RTPS Relay

### Download GCP SDK tools

These can be obtained [here](https://cloud.google.com/sdk/). Although many commands
can be run in the cloud shell, local files need to be copied into the Genesis
instance (see below) in order to bootstrap the base Debian packages.

### Add firewall rules to allow relay traffic

Prior to running the commands below, make sure the current project is 

```bash
gcloud compute firewall-rules create rtps-relay \
    --direction=INGRESS --priority=1000 --network=default \
    --action=ALLOW --rules=tcp:3478-3479,udp:3478-3479,udp:4444-4446 \
    --source-ranges=0.0.0.0/0 --target-tags=rtps-relay
```

### Create relay instance

```bash
gcloud compute instances create relay-01 \
    --machine-type=n1-standard-1 --image=debian-9-stretch-v20190312 \
    --image-project=debian-cloud --boot-disk-size=10GB \
    --boot-disk-type=pd-standard --boot-disk-device-name=relay-01 \
    --tags=rtps-relay
```

### Copy and run the deployment script

```bash
gcloud compute scp ./relay-deploy.sh relay-01:
```

### Bootstrap the machine and run the relay

```bash
gcloud compute ssh relay-01 --command='sudo bash $HOME/relay-deploy.sh'
```
