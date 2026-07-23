#!/usr/bin/env python3
"""Add a host-voice + effects audio bed to the silent M6 package reel.

The progress-package MP4 was stitched from frames only (no audio track).
This script muxes representative Guy Smiley lines and game cues onto the
timeline so reviewers hear what players will hear in the app.

Usage (from app/):
  python3 tools/remux_m6_package_video.py
"""
from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path

import imageio_ffmpeg

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "app"
AUDIO = APP / "assets" / "audio"
VOICE = AUDIO / "voice"

VIDEO_IN = ROOT / (
    "docs/client-deliverables/m8-progress-package/videos/"
    "02-m6-host-voice-animation-disconnect.mp4"
)
VIDEO_OUT = VIDEO_IN  # replace in place
PACKAGE_AUDIO = (
    ROOT / "docs/client-deliverables/m8-progress-package/audio/"
    "m6-host-voice-sample.mp3"
)
MILESTONE_AUDIO = ROOT / "docs/screenshots/milestone6/host-voice-sample.mp3"

# Approximate scene starts (seconds) for the 5-scene M6 reel (~16.3s total).
SCENES = [
    (0.0, [AUDIO / "announcer_intro.mp3", VOICE / "rules_intro.mp3"]),
    (3.3, []),  # sound-settings scene — visuals only
    (6.6, [AUDIO / "round_start.mp3", VOICE / "your_turn.mp3", VOICE / "nice_guess.mp3"]),
    (9.9, [AUDIO / "alert.mp3", AUDIO / "awooga.mp3", VOICE / "disconnect.mp3"]),
    (13.2, [AUDIO / "halftime.mp3", VOICE / "halftime.mp3"]),
]


def _ffmpeg() -> str:
    return imageio_ffmpeg.get_ffmpeg_exe()


def _duration(path: Path) -> float:
    ff = _ffmpeg()
    r = subprocess.run(
        [ff, "-hide_banner", "-i", str(path)],
        capture_output=True,
        text=True,
        check=False,
    )
    for line in (r.stdout + r.stderr).splitlines():
        if "Duration:" in line:
            # Duration: 00:00:16.28,
            part = line.split("Duration:")[1].split(",")[0].strip()
            h, m, s = part.split(":")
            return int(h) * 3600 + int(m) * 60 + float(s)
    raise RuntimeError(f"could not read duration: {path}")


def _build_audio_bed(video_dur: float, out_wav: Path) -> None:
    ff = _ffmpeg()
    inputs: list[str] = []
    filters: list[str] = []
    idx = 0
    mix_labels: list[str] = []

    for start, clips in SCENES:
        t = start
        for clip in clips:
            if not clip.is_file():
                raise FileNotFoundError(clip)
            inputs += ["-i", str(clip)]
            delay_ms = int(t * 1000)
            filters.append(f"[{idx}:a]adelay={delay_ms}|{delay_ms}[a{idx}]")
            mix_labels.append(f"[a{idx}]")
            idx += 1
            t += _duration(clip) + 0.15

    # Pad to full video length.
    filters.append(
        f"{''.join(mix_labels)}amix=inputs={len(mix_labels)}:duration=longest,"
        f"apad=pad_dur={video_dur:.3f},volume=1.15[aout]"
    )
    cmd = [ff, "-y", *inputs, "-filter_complex", ";".join(filters), "-map", "[aout]", str(out_wav)]
    subprocess.run(cmd, check=True, capture_output=True)


def main() -> None:
    if not VIDEO_IN.is_file():
        raise SystemExit(f"missing video: {VIDEO_IN}")

    dur = _duration(VIDEO_IN)
    ff = _ffmpeg()

    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "bed.wav"
        out = Path(tmp) / "muxed.mp4"
        _build_audio_bed(dur, wav)
        subprocess.run(
            [
                ff,
                "-y",
                "-i",
                str(VIDEO_IN),
                "-i",
                str(wav),
                "-c:v",
                "copy",
                "-c:a",
                "aac",
                "-b:a",
                "160k",
                "-shortest",
                str(out),
            ],
            check=True,
            capture_output=True,
        )
        out.replace(VIDEO_OUT)

    # Refresh the standalone audition clip too.
    sample_src = VOICE / "your_turn.mp3"
    if sample_src.is_file():
        for dest in (PACKAGE_AUDIO, MILESTONE_AUDIO):
            if dest.parent.is_dir():
                subprocess.run(
                    [ff, "-y", "-i", str(sample_src), "-c:a", "libmp3lame", "-b:a", "128k", str(dest)],
                    check=True,
                    capture_output=True,
                )

    print("wrote", VIDEO_OUT, f"({dur:.1f}s with audio)")


if __name__ == "__main__":
    main()
