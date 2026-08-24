#!/usr/bin/env python3
"""Karplus-Strong plucked-string lute sample synthesizer.

Generates a pentatonic-coherent set of lute notes as mono 16-bit WAV files
and converts them to OGG Vorbis with ffmpeg. The generated samples are
original content for this project and licensed under the same terms as the
other creative assets (CC BY-NC-SA 4.0).
"""

import math
import os
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

PROJECT_ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = PROJECT_ROOT / "audio" / "sfx"
SAMPLE_RATE = 44100
BIT_DEPTH = 16
DURATION_SECONDS = 1.2
DAMPING = 0.996

# Pentatonic-coherent lute note set (D major-ish / DADGAD-adjacent).
NOTE_FREQUENCIES = {
    "D3": 146.83,
    "G3": 196.00,
    "A3": 220.00,
    "B3": 246.94,
    "D4": 293.66,
    "E4": 329.63,
    "G4": 392.00,
    "A4": 440.00,
}


def _excitation_burst(length: int, sample_rate: int) -> np.ndarray:
    """Return a short low-passed noise burst to pluck the string."""
    # White noise burst with a mild exponential decay envelope.
    noise = np.random.uniform(-1.0, 1.0, size=length)
    envelope = np.exp(-np.linspace(0.0, 4.0, length))
    burst = noise * envelope

    # Simple one-pole low-pass filter to soften the burst.
    alpha = 0.3
    filtered = np.zeros_like(burst)
    filtered[0] = burst[0]
    for i in range(1, length):
        filtered[i] = alpha * burst[i] + (1.0 - alpha) * filtered[i - 1]
    return filtered


def karplus_strong(
    frequency: float,
    duration: float = DURATION_SECONDS,
    sample_rate: int = SAMPLE_RATE,
    damping: float = DAMPING,
) -> np.ndarray:
    """Synthesize a plucked string tone using the Karplus-Strong algorithm."""
    if frequency <= 0.0:
        raise ValueError("frequency must be positive")

    total_samples = int(round(sample_rate * duration))
    delay_line_length = max(1, int(round(sample_rate / frequency)))

    # Initialize the delay line with a low-passed noise burst.
    burst_length = min(delay_line_length, total_samples)
    delay_line = _excitation_burst(burst_length, sample_rate)
    if burst_length < delay_line_length:
        padding = np.zeros(delay_line_length - burst_length)
        delay_line = np.concatenate([delay_line, padding])

    output = np.zeros(total_samples, dtype=np.float64)
    index = 0
    for n in range(total_samples):
        current = delay_line[index]
        next_index = (index + 1) % delay_line_length
        next_sample = delay_line[next_index]
        # Two-sample averaging + damping.
        delay_line[index] = damping * 0.5 * (current + next_sample)
        output[n] = current
        index = next_index

    # Normalize to prevent clipping, then apply a gentle exponential decay
    # tail so the loop stays clean even if the KS energy hasn't fully died.
    max_amp = np.max(np.abs(output))
    if max_amp > 0.0:
        output = output / max_amp * 0.85

    tail = np.exp(-np.linspace(0.0, 3.5, total_samples))
    output = output * tail
    return output


def _wav_path_for_note(temp_dir: Path, note: str) -> Path:
    return temp_dir / f"lute_{note}.wav"


def _ogg_path_for_note(output_dir: Path, note: str) -> Path:
    return output_dir / f"lute_{note}.ogg"


def write_wav(path: Path, samples: np.ndarray, sample_rate: int) -> None:
    """Write a mono 16-bit PCM WAV file."""
    # Hard clip to [-1, 1] before int16 conversion.
    clipped = np.clip(samples, -1.0, 1.0)
    int_samples = (clipped * 32767.0).astype(np.int16)

    with wave.open(str(path), "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(int_samples.tobytes())


def convert_to_ogg(wav_path: Path, ogg_path: Path) -> None:
    """Convert a WAV file to OGG Vorbis using ffmpeg."""
    ffmpeg = os.environ.get("FFMPEG", "/opt/homebrew/bin/ffmpeg")
    command = [
        ffmpeg,
        "-y",
        "-i",
        str(wav_path),
        "-c:a",
        "libvorbis",
        "-q:a",
        "4",
        str(ogg_path),
    ]
    subprocess.run(command, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def main() -> int:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    print("Synthesizing lute notes with Karplus-Strong...")
    written: list[str] = []

    with tempfile.TemporaryDirectory(prefix="lute_synth_") as temp_dir_str:
        temp_dir = Path(temp_dir_str)
        for note, frequency in NOTE_FREQUENCIES.items():
            print(f"  {note} ({frequency:.2f} Hz)...", end="", flush=True)
            samples = karplus_strong(frequency)
            wav_path = _wav_path_for_note(temp_dir, note)
            ogg_path = _ogg_path_for_note(OUTPUT_DIR, note)
            write_wav(wav_path, samples, SAMPLE_RATE)
            convert_to_ogg(wav_path, ogg_path)
            file_size = ogg_path.stat().st_size
            print(f" -> {ogg_path.name} ({file_size} bytes)")
            written.append(f"{ogg_path.name}: {DURATION_SECONDS:.2f}s")

    print("Wrote lute samples:")
    for entry in written:
        print(f"  {entry}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
