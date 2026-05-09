#!/usr/bin/env python3
import argparse
import sys
from pathlib import Path

import torch
import soundfile as sf
from demucs.pretrained import get_model
from demucs.apply import apply_model
from demucs.audio import AudioFile


def main():
    parser = argparse.ArgumentParser(
        description="Split audio into stems (vocals, drums, bass, other) using demucs"
    )
    parser.add_argument("track", type=Path, help="Path to audio file")
    parser.add_argument(
        "--output", "-o", type=Path, default=Path("output"),
        help="Output directory (default: ./output)"
    )
    parser.add_argument(
        "--model", "-n", default="htdemucs_ft",
        help="Demucs model (default: htdemucs_ft)"
    )
    parser.add_argument(
        "--shifts", type=int, default=10,
        help="Random shifts for averaging — higher is better quality (default: 10)"
    )
    args = parser.parse_args()

    if not args.track.exists():
        sys.exit(f"Error: file not found: {args.track}")

    device = "cuda" if torch.cuda.is_available() else "cpu"
    if device == "cpu":
        print("Warning: CUDA not available, falling back to CPU (will be slow)", file=sys.stderr)
    else:
        print(f"GPU: {torch.cuda.get_device_name(0)}")

    print(f"Loading model: {args.model}")
    model = get_model(args.model)
    model.to(device)
    model.eval()

    print(f"Loading audio: {args.track.name}")
    wav = AudioFile(args.track).read(
        streams=0,
        samplerate=model.samplerate,
        channels=model.audio_channels,
    )
    ref = wav.mean(0)
    wav = (wav - ref.mean()) / ref.std()

    print(f"Separating (shifts={args.shifts}, overlap=0.5)...")
    with torch.no_grad():
        sources = apply_model(
            model,
            wav.unsqueeze(0).to(device),
            shifts=args.shifts,
            split=True,
            overlap=0.5,
            progress=True,
            num_workers=0,
        )[0]

    sources = sources * ref.std() + ref.mean()

    out_dir = args.output / args.model / args.track.stem
    out_dir.mkdir(parents=True, exist_ok=True)

    print(f"\nSaving stems to {out_dir}/")
    for name, source in zip(model.sources, sources):
        path = out_dir / f"{name}.wav"
        sf.write(str(path), source.cpu().numpy().T, model.samplerate, subtype="FLOAT")
        print(f"  {name}.wav")

    print("Done.")


if __name__ == "__main__":
    main()
