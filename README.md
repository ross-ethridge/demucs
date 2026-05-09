# demucs-cli

A Python CLI for splitting audio into stems — vocals, drums, bass, and other — powered by Meta's [htdemucs_ft](https://github.com/adefossez/demucs) model. Runs locally on an NVIDIA GPU.

## Requirements

- Python 3.8+
- NVIDIA GPU with CUDA support
- pip
- ffmpeg (`sudo apt install ffmpeg` on Ubuntu/WSL)

## Installation

```bash
make install
```

This runs two steps: installs PyTorch and torchaudio with CUDA 12.6 support from the official PyTorch wheel index, then installs demucs and remaining dependencies from PyPI. The first time you run the app it will also download the `htdemucs_ft` model weights (~1GB) and cache them in `./models/`.

## Usage

```bash
python demucs_cli.py /path/to/song.wav
```

Stems are saved to `./output/htdemucs_ft/<trackname>/`:

```
output/
  htdemucs_ft/
    song/
      vocals.wav
      drums.wav
      bass.wav
      other.wav
```

### Options

| Flag | Default | Description |
| --- | --- | --- |
| `--output`, `-o` | `./output` | Directory to write stems into |
| `--model`, `-n` | `htdemucs_ft` | Demucs model to use |
| `--shifts` | `10` | Shifts averaged per prediction — higher is better quality but slower |

### Examples

```bash
# Basic usage
python demucs_cli.py /path/to/song.wav

# Write stems to a specific directory
python demucs_cli.py /path/to/song.wav --output ~/stems
```

## Output format

Stems are written as 32-bit float WAV files at 44.1kHz. No dynamic processing or normalization is applied — the stems are at their natural levels relative to the original mix.
