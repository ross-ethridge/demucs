# demucs:r

A self-hosted web app for splitting any song into its individual stems — bass, drums, vocals, and synth/guitar — powered by Meta's [Demucs](https://github.com/adefossez/demucs) AI model.

Upload a track, wait a few minutes, download your stems as WAV files. No account required. Runs entirely on your machine.

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

## Requirements

- [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/)
- ~10 GB disk space for the model and Docker images
- A reasonably modern CPU (6+ cores recommended) or an Nvidia GPU for faster processing

---

## Quick start

```bash
git clone https://github.com/ross-ethridge/demucs.git
cd demucs
make setup
docker compose up --build -d
```

Then open **http://localhost** in your browser.

`make setup` generates a `.env` with unique random values for all secrets — database password, MinIO credentials, and Rails secret key. No manual editing required. Just run `docker compose up --build -d` straight after.

If you want to review or adjust any values (e.g. change the number of shifts or enable GPU), open `.env` in any text editor — all options are explained in the Configuration section below. Running `make setup` again will not overwrite an existing `.env`.

On first run Docker will build the images and download the model checkpoints (~2 GB). This takes 10–20 minutes. Subsequent starts are fast.

---

## Configuration

Copy `env.template` to `.env`:

```bash
cp env.template .env
```

The app will not start without a `.env` file. Here is what each variable does and whether you need to change it for local use:

### Required to run locally

| Variable | Default | What to do |
| --- | --- | --- |
| `POSTGRES_PASSWORD` | `changeme` | Change to anything — this is the password for the local Postgres container |
| `SECRET_KEY_BASE` | *(blank)* | Must be set. Generate one with: `docker run --rm ruby:4.0.1-slim ruby -e "require 'securerandom'; puts SecureRandom.hex(64)"` — then paste the output into `.env` |

### Optional / tuning

| Variable | Default | Description |
| --- | --- | --- |
| `POSTGRES_USER` | `demucs` | Database username — fine to leave as-is |
| `DEMUCS_GPU` | `false` | Set to `true` to use an Nvidia GPU (see GPU section below) |
| `DEMUCS_SHIFTS` | `1` | Number of prediction passes. Higher = better quality but slower. `3`–`5` is a good balance |
| `DEMUCS_THREADS` | `4` | CPU threads allocated to Demucs |

### Not needed for local use

The AWS/S3 variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `AWS_BUCKET`) are only needed if you want to store stems in S3. Leave them blank and stems will be stored on the local `output` volume instead — no AWS account required.

A minimal `.env` for local use looks like this:

```
POSTGRES_USER=demucs
POSTGRES_PASSWORD=something_secret
SECRET_KEY_BASE=paste_generated_value_here
DEMUCS_GPU=false
DEMUCS_SHIFTS=3
DEMUCS_THREADS=4
```

---

## GPU acceleration (optional)

An Nvidia GPU dramatically speeds up processing — from ~5–10 minutes per track to under a minute.

1. Install the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) on your host
2. Set in `.env`:
   ```
   DEMUCS_GPU=true
   ```
3. Restart:
   ```bash
   docker compose up -d
   ```

The image includes CUDA 11.8 wheels and supports RTX 4060 and earlier Ada Lovelace GPUs.

---

## Processing time

Processing time depends on track length, CPU speed, and `DEMUCS_SHIFTS`:

| Shifts | Quality | Time (CPU, 6-core) |
| --- | --- | --- |
| `1` | Good | ~2–3 min |
| `3` | Better | ~6–9 min |
| `5` | Best | ~10–15 min |

With a GPU (RTX 4060), all of the above take under a minute regardless of shifts.

---

## Stopping and restarting

```bash
# Stop
docker compose down

# Start again (no rebuild needed)
docker compose up -d

# View logs
docker compose logs -f web
```

---

## License

MIT — see [LICENSE](LICENSE).

Demucs is developed by Meta Research and released under the MIT license. See the [Demucs repository](https://github.com/adefossez/demucs) for details.
