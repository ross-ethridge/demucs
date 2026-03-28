#!/usr/bin/env python3
"""Long-running demucs HTTP service.
Accepts processing jobs, fetches input from MinIO, runs demucs + ffmpeg
normalization, and stores stems back in MinIO.

POST /jobs        { job_id, bucket, input_key, filename, model, shifts }
GET  /jobs/:id    { status, progress, error? }
GET  /health
"""

import os
import re
import subprocess
import threading
import tempfile
import shutil
from pathlib import Path

import boto3
from flask import Flask, request, jsonify

app = Flask(__name__)
_jobs: dict = {}
_lock = threading.Lock()


# ── MinIO / S3 ────────────────────────────────────────────────────────────────

def _s3():
    return boto3.client(
        "s3",
        endpoint_url=os.environ["S3_ENDPOINT"],
        aws_access_key_id=os.environ["AWS_ACCESS_KEY_ID"],
        aws_secret_access_key=os.environ["AWS_SECRET_ACCESS_KEY"],
        region_name=os.environ.get("AWS_REGION", "us-east-1"),
    )


# ── Job state ─────────────────────────────────────────────────────────────────

def _set(job_id: str, state: dict):
    with _lock:
        _jobs[job_id] = state


def _get(job_id: str) -> dict:
    with _lock:
        return dict(_jobs.get(job_id, {"status": "not_found"}))


# ── Routes ────────────────────────────────────────────────────────────────────

@app.get("/health")
def health():
    return jsonify({"status": "ok"})


@app.post("/jobs")
def create_job():
    data   = request.get_json(force=True)
    job_id = data["job_id"]
    _set(job_id, {"status": "accepted", "progress": 0})
    threading.Thread(target=_process, args=(job_id, data), daemon=True).start()
    return jsonify({"job_id": job_id, "status": "accepted"}), 202


@app.get("/jobs/<job_id>")
def get_job(job_id):
    return jsonify(_get(job_id))


# ── Processing ────────────────────────────────────────────────────────────────

def _process(job_id: str, data: dict):
    workdir = tempfile.mkdtemp(prefix="demucs-")
    try:
        bucket    = data["bucket"]
        input_key = data["input_key"]
        filename  = data["filename"]           # e.g. "song.mp3"
        model     = data.get("model", "htdemucs_ft")
        shifts    = str(data.get("shifts", 1))
        stem_name = Path(filename).stem        # "song"

        input_dir  = Path(workdir) / "input"
        output_dir = Path(workdir) / "output"
        input_dir.mkdir()
        output_dir.mkdir()

        _set(job_id, {"status": "processing", "progress": 0})

        # Download input from MinIO
        input_path = input_dir / filename
        _s3().download_file(bucket, input_key, str(input_path))

        # Run demucs, streaming output to parse progress
        run_index = 0
        last_pct  = -1
        n_runs    = int(shifts) * 4   # 4 sources × shifts

        device = os.environ.get("DEMUCS_DEVICE")  # "cpu", "cuda", or unset (auto-detect)
        cmd = [
            "python3", "-m", "demucs",
            "-n", model,
            "--out", str(output_dir),
            "--shifts", shifts,
            "--overlap", "0.25",
            "-j", "1",
        ]
        if device:
            cmd += ["-d", device]
        cmd.append(str(input_path))

        with subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, bufsize=1
        ) as proc:
            for line in proc.stdout:
                m = re.search(r"(\d+)%\|", line)
                if m:
                    pct = int(m.group(1))
                    if pct < last_pct:
                        run_index += 1
                    last_pct = pct
                    overall  = int((run_index * 100 + pct) / n_runs)
                    _set(job_id, {"status": "processing", "progress": overall})
            proc.wait()

        if proc.returncode != 0:
            _set(job_id, {"status": "failed", "error": "demucs exited non-zero"})
            return

        # Trim silence + normalize each stem in place
        stems_dir = output_dir / model / stem_name
        _trim_stems(stems_dir)

        # Upload stems to MinIO using key format matching Rails S3Storage.key:
        #   stems/{stem_name}/{stem_name}_{stem}.wav
        client = _s3()
        for wav in stems_dir.glob("*.wav"):
            key = f"stems/{stem_name}/{stem_name}_{wav.stem}.wav"
            client.upload_file(str(wav), bucket, key)

        _set(job_id, {"status": "done", "progress": 100})

    except Exception as exc:
        _set(job_id, {"status": "failed", "error": str(exc)})
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


def _trim_stems(stems_dir: Path):
    for wav in stems_dir.glob("*.wav"):
        tmp = str(wav) + ".tmp.wav"
        result = subprocess.run(
            [
                "ffmpeg", "-i", str(wav),
                "-af",
                "silenceremove=start_periods=1:start_duration=0.1:start_threshold=-40dB:"
                "stop_periods=-1:stop_duration=1.0:stop_threshold=-40dB,"
                "dynaudnorm=f=500:g=31:p=0.95:m=10",
                "-c:a", "pcm_f32le", tmp, "-y",
            ],
            capture_output=True,
        )
        if result.returncode == 0 and os.path.exists(tmp):
            os.replace(tmp, str(wav))
        else:
            if os.path.exists(tmp):
                os.unlink(tmp)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
