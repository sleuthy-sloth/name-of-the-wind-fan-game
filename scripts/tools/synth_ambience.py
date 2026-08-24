#!/usr/bin/env python3
"""Synthesize seamless 30 s ambience loops for The Name of the Wind (fan game).

Outputs (WAV intermediates -> OGG via ffmpeg):
  audio/ambience/campfire_loop.ogg      brown-noise bed + crackle pops
  audio/ambience/forest_night_loop.ogg  wind bed + sparse cricket chirps

Original synthesized content (CC BY-NC-SA like other project assets).
"""
import os
import subprocess

import numpy as np

SR = 44100
DUR = 30.0
N = int(SR * DUR)
XFADE = int(2.0 * SR)
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "audio", "ambience")


def _lowpass(x, alpha):
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += alpha * (x[i] - acc)
        y[i] = acc
    return y


def _bandpass(x, lo_alpha, hi_alpha):
    return _lowpass(_lowpass(x, lo_alpha) - _lowpass(x, hi_alpha), lo_alpha)


def _seamless(x):
    """Crossfade tail into head so loop point is inaudible."""
    out = x.copy()
    ramp = np.linspace(0.0, 1.0, XFADE)
    out[:XFADE] = out[:XFADE] * ramp + x[-XFADE:] * (1.0 - ramp)
    return out[: N - XFADE]


def _write(name, x):
    x = np.clip(x, -1.0, 1.0)
    pcm = (x * 32767.0).astype(np.int16)
    import wave

    wav_path = os.path.join("/tmp", name + ".wav")
    with wave.open(wav_path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    ogg_path = os.path.join(OUT_DIR, name + ".ogg")
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path,
         "-c:a", "vorbis", "-strict", "experimental", "-ac", "2", "-q:a", "3", ogg_path],
        check=True,
    )
    print(f"wrote {ogg_path} ({os.path.getsize(ogg_path)} bytes)")


def synth_campfire():
    rng = np.random.default_rng(7)
    white = rng.standard_normal(N)
    bed = _lowpass(white, 0.02)  # ~roughly <400 Hz at 44.1 kHz
    wander = 0.55 + 0.25 * _lowpass(rng.standard_normal(N), 0.00005)
    bed = bed / (np.max(np.abs(bed)) + 1e-9) * wander
    crackle = np.zeros(N)
    n_pops = rng.poisson(9.0 * DUR)
    for _ in range(n_pops):
        start = rng.integers(0, N - 2000)
        length = int(rng.uniform(120, 900))
        pop_t = np.arange(length) / SR
        env = np.exp(-pop_t * rng.uniform(40, 140))
        carrier = np.sin(
            2 * np.pi * rng.uniform(1000, 4000) * pop_t
            + rng.uniform(0, 6.28)
        )
        crackle[start : start + length] += env * carrier * rng.uniform(0.15, 0.5)
    mix = 0.8 * bed + 0.35 * crackle
    _seamless(mix)
    return _seamless(mix)


def synth_forest_night():
    rng = np.random.default_rng(11)
    wind = _lowpass(rng.standard_normal(N), 0.004)
    gusts = 0.35 + 0.3 * np.abs(_lowpass(rng.standard_normal(N), 0.00008))
    wind = wind / (np.max(np.abs(wind)) + 1e-9) * gusts
    chirps = np.zeros(N)
    t_chirp = np.arange(int(0.06 * SR)) / SR
    carrier = np.sin(2 * np.pi * 4200.0 * t_chirp)
    tremolo = 0.5 * (1.0 + np.sin(2 * np.pi * 24.0 * t_chirp))
    unit = carrier * tremolo * np.exp(-t_chirp * 30.0)
    for _ in range(int(2.2 * DUR)):
        start = rng.integers(0, N - len(unit) - 1)
        chirps[start : start + len(unit)] += unit * rng.uniform(0.02, 0.07)
    mix = 0.85 * wind + chirps
    return _seamless(mix)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    print("synthesizing campfire_loop ...")
    _write("campfire_loop", synth_campfire())
    print("synthesizing forest_night_loop ...")
    _write("forest_night_loop", synth_forest_night())
    print("AMBIENCE_SYNTH: PASS")


if __name__ == "__main__":
    main()
