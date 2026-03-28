# demucs:r

A self-hosted web app for splitting any song into its individual stems — bass, drums, vocals, and synth/guitar — powered by Meta's [Demucs](https://github.com/adefossez/demucs) AI model.

Upload a track, wait a few minutes, download your stems as WAV files. Runs entirely on your own infrastructure.

![demucs:r screenshot](docs/screenshot.png)

---

## How it works

Demucs uses a hybrid transformer neural network trained on thousands of songs to separate a mixed audio track into four isolated stems:

| Stem | Contains |
| --- | --- |
| **Vocals** | Lead and backing vocals |
| **Bass** | Bass guitar, sub bass |
| **Drums** | Kick, snare, hi-hats, cymbals |
| **Other** | Synths, guitars, keys, everything else |

After separation, each stem is automatically post-processed:

- **Silence removal** — gaps longer than 1 second below -40dB are stripped out, removing the near-silence bleed that source separation models produce between musical phrases
- **Dynamic normalization** — `dynaudnorm` levels out the volume across each stem so quiet sections aren't buried next to loud ones
- **Lossless output** — stems are written as 32-bit float WAV (`pcm_f32le`), the same format Demucs produces internally, with no quality loss

The model used is `htdemucs_ft` — the fine-tuned version of Demucs, which produces the highest quality results.

---

## Architecture

The app runs as a set of Kubernetes workloads:

| Pod | Role |
| --- | --- |
| **web** | Rails app served by Thruster (handles TLS, HTTP/2) |
| **worker** | Solid Queue job runner — submits tracks to the demucs service |
| **demucs** | Long-running Python HTTP service — runs the AI model, uploads stems to MinIO |
| **postgres** | Database for Rails |
| **minio** | S3-compatible object store for audio files and stems |

Rails is purely a UI layer. All audio processing happens in the demucs pod. Files move between services via MinIO — the worker tells the demucs pod where to find the input and where to write the output, and the demucs pod handles the rest.

---

## Requirements

**CPU deployment:**
- A [k3s](https://k3s.io/) node (single-node is fine)
- 6+ CPU cores and 16+ GB RAM recommended
- ~15 GB disk space for images and model checkpoints
- A domain name pointed at the node (Thruster handles TLS via Let's Encrypt)

**GPU deployment:**
- A k3s node with an NVIDIA GPU (RTX series recommended)
- NVIDIA drivers and container toolkit installed on the host
- No domain name required — runs on plain HTTP

---

## Deployment

Two independent settings control how the app runs:

| Setting | Controls |
| --- | --- |
| **Overlay** | `overlays/cpu/` for CPU inference, `overlays/gpu/` for GPU inference |
| **`TLS_DOMAIN` in secret** | Set to your domain for HTTPS, set to `""` for plain HTTP |

These combine freely:

| Overlay | `TLS_DOMAIN` | Result |
| --- | --- | --- |
| `overlays/cpu/` | `your.domain.com` | CPU + TLS |
| `overlays/cpu/` | `""` | CPU + no TLS |
| `overlays/gpu/` | `your.domain.com` | GPU + TLS |
| `overlays/gpu/` | `""` | GPU + no TLS |

### 1. Clone the repo

```bash
git clone https://github.com/ross-ethridge/demucs.git
cd demucs
```

### 2. Configure your image registry

`k8s/kustomization.yaml` is not committed. Copy the example and set your GitHub username:

```bash
cp k8s/kustomization.yaml.example k8s/kustomization.yaml
# edit k8s/kustomization.yaml and replace your-github-username
```

### 3. Create the namespace

```bash
kubectl apply -f k8s/namespace.yaml
```

### 4. Create secrets

```bash
# App secrets
kubectl -n demucs create secret generic demucs-secrets \
  --from-literal=POSTGRES_USER=demucs \
  --from-literal=POSTGRES_PASSWORD=$(openssl rand -hex 16) \
  --from-literal=AWS_ACCESS_KEY_ID=$(openssl rand -hex 16) \
  --from-literal=AWS_SECRET_ACCESS_KEY=$(openssl rand -hex 32) \
  --from-literal=AWS_REGION=us-east-1 \
  --from-literal=AWS_BUCKET=demucs \
  --from-literal=SECRET_KEY_BASE=$(openssl rand -hex 64) \
  --from-literal=TLS_DOMAIN=your.domain.com

# GHCR pull secret (create a GitHub PAT with read:packages scope)
kubectl -n demucs create secret docker-registry ghcr-pull-secret \
  --docker-server=ghcr.io \
  --docker-username=your-github-username \
  --docker-password=<github-pat>
```

Replace `your.domain.com` with your domain. Thruster obtains a TLS certificate automatically via Let's Encrypt.

### 5. Create host directory for MinIO storage

```bash
sudo mkdir -p /mnt/minio-data
```

### 6. Build and push images

```bash
docker build -t ghcr.io/your-github-username/demucs-web:latest ./web
docker build -t ghcr.io/your-github-username/demucs:latest .

docker push ghcr.io/your-github-username/demucs-web:latest
docker push ghcr.io/your-github-username/demucs:latest
```

The demucs image downloads model checkpoints during build. Allow 20–30 minutes on first build.

### 7. Deploy

```bash
kubectl apply -k k8s/
```

### 8. Verify

```bash
kubectl get all -n demucs
```

All pods should reach `1/1 Running`. The `minio-init` job will complete once and then show `Completed`.

---

## User management

The app requires a login. Accounts are managed via Rake tasks — there is no self-signup UI.

```bash
# Create a user (generates a random password)
kubectl -n demucs exec deploy/web -- bin/rails users:create EMAIL=you@example.com

# List all users
kubectl -n demucs exec deploy/web -- bin/rails users:list

# Delete a user
kubectl -n demucs exec deploy/web -- bin/rails users:delete EMAIL=you@example.com

# Reset a user's password to a new generated one
kubectl -n demucs exec deploy/web -- bin/rails users:reset EMAIL=you@example.com
```

`users:create` and `users:reset` both print the generated password to stdout. Users can change their password after logging in via the **Change password** link in the nav.

---

## Configuration

Tuning parameters are set directly in the manifests:

| Setting | Manifest | Default | Description |
| --- | --- | --- | --- |
| `OMP_NUM_THREADS` | `k8s/demucs.yaml` | `6` | PyTorch CPU threads — set to physical core count |
| `MKL_NUM_THREADS` | `k8s/demucs.yaml` | `6` | Intel MKL threads — keep in sync with above |
| `DEMUCS_SHIFTS` | `k8s/worker.yaml` | `3` | Prediction passes — higher is slower but better quality |
| `JOB_CONCURRENCY` | `k8s/worker.yaml` | `2` | Solid Queue worker threads |

After changing any manifest value:

```bash
kubectl apply -k k8s/
```

---

## GPU deployment

To run on a k3s node with an NVIDIA GPU. No TLS required — accessible over plain HTTP.

### 1. Install NVIDIA drivers and container toolkit

Install NVIDIA drivers for your GPU if not already present. Then install the container toolkit:

```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
```

Verify drivers are working:

```bash
nvidia-smi
```

### 2. Configure k3s containerd for NVIDIA

k3s uses its own embedded containerd instance. Two things need to be configured: the nvidia runtime must be set as the default, and CDI (Container Device Interface) must be enabled. A config template is included in the repo:

```bash
# Generate CDI device specs from the host driver
sudo mkdir -p /etc/cdi
sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml

# Install the containerd config template
sudo cp overlays/gpu/containerd-config.toml.tmpl \
  /var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl

# Restart k3s to apply the config
sudo systemctl restart k3s
```

The template (`overlays/gpu/containerd-config.toml.tmpl`) sets nvidia as the default container runtime and enables CDI. k3s regenerates its containerd config from this template on every restart.

### 3. Deploy the NVIDIA device plugin

The static DaemonSet from NVIDIA is designed to work with NVIDIA's GPU Operator and ships with locked-down defaults (no privileges, no driver mount) that prevent it from enumerating GPUs on a bare k3s node. A patched version is included in the repo:

```bash
kubectl apply -f overlays/gpu/nvidia-device-plugin.yaml
```

The patch adds `privileged: true` and mounts the host root at `/driver-root` so the plugin can access `libnvidia-ml.so` and enumerate GPUs.

Verify the GPU is visible to k3s:

```bash
kubectl describe node <node-name> | grep nvidia
# Should show: nvidia.com/gpu: 1
```

### 4. Create secrets

```bash
kubectl create namespace demucs

kubectl -n demucs create secret generic demucs-secrets \
  --from-literal=POSTGRES_USER=demucs \
  --from-literal=POSTGRES_PASSWORD=$(openssl rand -hex 16) \
  --from-literal=AWS_ACCESS_KEY_ID=$(openssl rand -hex 16) \
  --from-literal=AWS_SECRET_ACCESS_KEY=$(openssl rand -hex 32) \
  --from-literal=AWS_REGION=us-east-1 \
  --from-literal=AWS_BUCKET=demucs \
  --from-literal=SECRET_KEY_BASE=$(openssl rand -hex 64) \
  --from-literal=TLS_DOMAIN=""

# GHCR pull secret
kubectl -n demucs create secret docker-registry ghcr-pull-secret \
  --docker-server=ghcr.io \
  --docker-username=your-github-username \
  --docker-password=<github-pat>
```

If transferring secrets from another cluster (e.g. production), clear `TLS_DOMAIN` after copying — otherwise Thruster will redirect all traffic to HTTPS:

```bash
kubectl -n demucs patch secret demucs-secrets \
  --type='json' \
  -p='[{"op":"replace","path":"/data/TLS_DOMAIN","value":""}]'
```

### 5. Deploy

```bash
kubectl apply -k overlays/gpu/
```

The overlay patches two things relative to the base:

| Change | Why |
| --- | --- |
| `DEMUCS_DEVICE=cuda` on demucs pod | Forces GPU inference instead of CPU |
| `nvidia.com/gpu: 1` resource limit | Schedules the pod onto a GPU node |
| `JOB_CONCURRENCY=1` on worker | One GPU can only run one job at a time |

TLS is controlled separately by `TLS_DOMAIN` in your secret — see [Deployment](#deployment).

### GPU flag

`DEMUCS_DEVICE` controls device selection in the demucs service:

| Value | Behavior |
| --- | --- |
| unset | Auto-detects — uses CUDA if available, falls back to CPU |
| `cuda` | Forces GPU (fails if no GPU is present) |
| `cpu` | Forces CPU regardless of GPU availability |

The CPU deployment leaves `DEMUCS_DEVICE` unset (no GPU resource requested). The GPU deployment sets it to `cuda`.

---

## Processing time

Processing time depends on track length, CPU speed, and `DEMUCS_SHIFTS`:

| Shifts | Quality | Time (6-core CPU) |
| --- | --- | --- |
| `1` | Good | ~2–3 min |
| `3` | Better | ~6–9 min |
| `5` | Best | ~10–15 min |

With an NVIDIA GPU, all of the above take under a minute. The demucs image includes CUDA 11.8 wheels. GPU support is available via the GPU deployment — see [GPU deployment](#gpu-deployment).

---

## Operations

```bash
# View logs
kubectl -n demucs logs -f deployment/web
kubectl -n demucs logs -f deployment/worker
kubectl -n demucs logs -f deployment/demucs

# Restart a pod
kubectl -n demucs rollout restart deployment/demucs

# Scale worker concurrency (edit JOB_CONCURRENCY in k8s/worker.yaml, then)
kubectl apply -k k8s/

# Access MinIO console (port-forward since it's not exposed publicly)
kubectl -n demucs port-forward svc/minio 9001:9001
# Then browse to http://localhost:9001
# Credentials are the AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY from your secret
```

---

## License

MIT — see [LICENSE](LICENSE).

Demucs is developed by Meta Research and released under the MIT license. See the [Demucs repository](https://github.com/adefossez/demucs) for details.
