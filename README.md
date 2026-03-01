# Docker Facebook Demucs

## What is Demucs?

[Demucs](https://github.com/adefossez/demucs) is an open-source music source separation model developed by Meta Research (Facebook AI). It uses a deep neural network to split a mixed audio track into its individual stems: **bass**, **drums**, **vocals**, and **other** instruments.

It is one of the highest-quality open-source tools available for this task, capable of producing clean, usable stems from most genres of music. Common use cases include remixing, karaoke track generation, music practice, and audio production.

Several model variants are available, trading off speed and quality:

| Model | Description |
| --- | --- |
| `htdemucs` | Default hybrid transformer model — best balance of quality and speed |
| `htdemucs_ft` | Fine-tuned version of `htdemucs` — highest quality, slower |
| `mdx` | MDX-Net model, competitive on vocals |
| `mdx_extra` | MDX-Net with extra training data |

This repository wraps Demucs in a Docker container so it can be run without manually managing Python environments or CUDA dependencies.

## Prerequisites
- [Docker](https://docs.docker.com/get-docker/)
- An Nvidia GPU with CUDA support is optional but strongly recommended for reasonable performance. The image uses CUDA 11.8 wheels and supports Ada Lovelace GPUs (e.g. RTX 4060) and earlier. Nvidia drivers 450.80.02+ are required for GPU use.

## Usage

1. Clone this repository:
```bash
git clone git@github.com:ross-ethridge/demucs.git
cd demucs
```
2. Build the Docker image:
```bash
make build
```
The build clones the Demucs source, installs PyTorch with CUDA 11.8 support, patches torchaudio for compatibility, and pre-downloads the default `htdemucs` model (~80 MB). **Expect this to take 10–20 minutes** on the first run — it needs to download PyTorch, torchaudio, and all other Python dependencies before the model itself.

3. Copy the track you want to split into the `input` folder (e.g., `input/mysong.mp3`).
4. Run `demucs`:
```bash
make run track=mysong.mp3
```

Separated stems are written to `output/<model>/<track-name>/` as individual `.wav` files.

#### Options

Option | Default Value | Description
--- | --- | ---
`gpu`           | `false`    | Enable Nvidia CUDA support (requires an Nvidia GPU and the [Nvidia Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)).
`model`         | `htdemucs` | The model used for audio separation. See the [Demucs docs](https://github.com/facebookresearch/demucs#separating-tracks) for a list of available models.
`mp3output`     | `false`    | Output separated stems in `mp3` format instead of the default `wav`.
`shifts`        | `1`        | Perform multiple predictions with random shifts of the input and average them. Makes prediction `N` times slower — only useful with a GPU.
`overlap`       | `0.25`     | Amount of overlap between prediction windows (25%). Can be reduced to `0.1` to speed up separation.
`jobs`          | `1`        | Number of parallel jobs. Multiplies RAM usage by the same factor.
`splittrack`    |            | Extract only one stem (e.g. `drums`). Valid values: `bass`, `drums`, `vocals`, `other`.

#### Examples
```bash
# GPU-accelerated separation with mp3 output
make run track=mysong.mp3 gpu=true mp3output=true

# Use the fine-tuned htdemucs model, extract only vocals
make run track=mysong.mp3 model=htdemucs_ft splittrack=vocals

# CPU-only, reduce overlap for faster (lower quality) results
make run track=mysong.mp3 overlap=0.1 jobs=4
```

### Run Interactively

To experiment with other `demucs` options on the command line, run the container interactively:

```bash
make run-interactive
make run-interactive gpu=true
```

This drops you into a bash shell inside the container with the `input`, `output`, and `models` directories mounted. Only the `gpu` option applies to this target.

## License
This repository is released under the MIT license as found in the [LICENSE](LICENSE) file.
