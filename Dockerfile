# Base image supports Nvidia CUDA but does not require it and can also run demucs on the CPU
FROM nvidia/cuda:12.6.2-base-ubuntu22.04

USER root
ENV TORCH_HOME=/data/models
ENV OMP_NUM_THREADS=1

# Install required tools
# Notes:
#  - build-essential and python3-dev are included for platforms that may need to build some Python packages (e.g., arm64)
#  - torchaudio >= 0.12 now requires ffmpeg on Linux, see https://github.com/facebookresearch/demucs/blob/main/docs/linux.md
RUN apt update && apt install -y --no-install-recommends \
    build-essential \
    curl \
    ffmpeg \
    git \
    python3 \
    python3-dev \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Clone Demucs (now maintained in the original author's github space)
RUN git clone --single-branch --branch main https://github.com/adefossez/demucs /lib/demucs
WORKDIR /lib/demucs

# Upgrade pip first — the Ubuntu 22.04 system pip has a broken read timeout on large downloads
RUN python3 -m pip install --upgrade pip
# torchaudio 2.1+ drops encoding param from save(); 2.0.x is last working version per demucs requirements
# cu118 (CUDA 11.8) supports RTX 4060 (sm_89/Ada Lovelace) and avoids library conflicts with base image
RUN python3 -m pip install "torch==2.0.1+cu118" "torchaudio==2.0.2+cu118" --index-url https://download.pytorch.org/whl/cu118 --no-cache-dir
# Install demucs and remaining dependencies; soundfile needed for audio.py patch below
RUN python3 -m pip install -e . "numpy<2" soundfile --no-cache-dir
# Patch audio.py: torchaudio 2.x save() encoding param requires dispatcher which is unavailable;
# use soundfile directly instead (it is already a demucs dependency via requirements.txt)
RUN python3 -c "content=open('demucs/audio.py').read();old=\"        if as_float:\n            bits_per_sample = 32\n            encoding = 'PCM_F'\n        else:\n            encoding = 'PCM_S'\n        ta.save(str(path), wav, sample_rate=samplerate,\n                encoding=encoding, bits_per_sample=bits_per_sample)\";new=\"        import soundfile as sf\n        subtype='FLOAT' if as_float else 'PCM_%d'%bits_per_sample\n        sf.write(str(path),wav.cpu().numpy().T,samplerate,subtype=subtype)\";assert old in content,'Patch target not found in audio.py';open('demucs/audio.py','w').write(content.replace(old,new));print('audio.py patched')"
# Download model with retry support — torch.hub's downloader stalls on large files
RUN mkdir -p /data/models/hub/checkpoints && \
    curl --retry 10 --retry-delay 5 -L \
    -o /data/models/hub/checkpoints/955717e8-8726e21a.th \
    "https://dl.fbaipublicfiles.com/demucs/hybrid_transformer/955717e8-8726e21a.th"
# Run once to ensure demucs works and verify the build is correct
RUN python3 -m demucs -d cpu test.mp3
# Cleanup output - we just used this to download the model
RUN rm -r separated

VOLUME /data/input
VOLUME /data/output
VOLUME /data/models

ENTRYPOINT ["/bin/bash", "--login", "-c"]
