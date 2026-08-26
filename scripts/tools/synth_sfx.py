#!/usr/bin/env python3
"""Synthesize original SFX one-shots + weather layers for the audio pipeline.

Fills `review: "standard"` unfilled events from
tools/audio-pipeline/metadata/requirements.json that can be convincingly
procedurally synthesized. Music, crowd/voice ambience, and signature sounds
(sympathy / Naming / Chandrian / lute performances) stay OUT — they either
need human approval or real recorded sources.

Outputs OGG originals to
  tools/audio-pipeline/sources/original/notw_synthesized_sfx/<stem>.ogg
plus a manifest.json there mapping EVENT_ID -> [filenames], which
scripts/register-synth-sfx.mjs merges into metadata/licenses.json.

Deterministic: every variant uses its own fixed seed (event, index).
"""
import json
import os
import subprocess
import sys

import numpy as np

SR = 44100
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PIPELINE = os.path.join(ROOT, "tools", "audio-pipeline")
OUT_DIR = os.path.join(PIPELINE, "sources", "original", "notw_synthesized_sfx")
REQ_FILE = os.path.join(PIPELINE, "metadata", "requirements.json")

# Events we deliberately do NOT synthesize (need recordings or approval).
SKIP_EVENTS = {
    # ambience needing real-world texture (crowd/voice/birds)
    "AMB_TAVERN_MURMUR", "AMB_CROWD_DISTANT_STUDENTS", "AMB_BIRDS_LAYER",
    "AMB_CITY_TARBEAN_NIGHT", "AMB_ARCHIVES_ROOMTONE",
    "AMB_UNDERTHING_BASE", "AMB_UNIVERSITY_COURTYARD_BASE",
}

# ---------------------------------------------------------------------------
# DSP helpers
# ---------------------------------------------------------------------------

def lowpass(x, alpha):
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += alpha * (x[i] - acc)
        y[i] = acc
    return y


def band(x, lo_alpha, hi_alpha):
    """Band-limit via difference of two one-pole lowpasses."""
    return lowpass(lowpass(x, lo_alpha), lo_alpha) - lowpass(x, hi_alpha)


def env_exp(n, rate):
    return np.exp(-np.arange(n) / SR * rate)


def env_adsr(n, a=0.005, d=0.08, s_level=0.35, r=0.15):
    t_a, t_d, t_r = int(a * SR), int(d * SR), int(r * SR)
    t_s = max(0, n - t_a - t_d - t_r)
    parts = []
    if t_a: parts.append(np.linspace(0, 1, t_a))
    if t_d: parts.append(np.linspace(1, s_level, t_d))
    if t_s: parts.append(np.full(t_s, s_level))
    if t_r: parts.append(np.linspace(s_level, 0, t_r))
    e = np.concatenate(parts) if parts else np.zeros(n)
    if len(e) < n:
        e = np.pad(e, (0, n - len(e)))
    return e[:n]


def place(buf, snd, at):
    i = int(at * SR)
    j = min(len(buf), i + len(snd))
    if j > i:
        buf[i:j] += snd[: j - i]


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def finish(x, peak=0.85):
    m = np.max(np.abs(x)) + 1e-9
    return np.clip(x / m * peak, -1, 1)


def _vorbis_args():
    """Mirror pipeline common.mjs vorbisEncoder(): prefer libvorbis, fall back
    to FFmpeg's native encoder (stereo-only), else None -> keep WAV."""
    try:
        out = subprocess.run(["ffmpeg", "-hide_banner", "-encoders"],
                             capture_output=True, text=True, check=True).stdout
    except Exception:
        return None
    if " libvorbis " in out:
        return ["-c:a", "libvorbis", "-q:a", "4"]
    if " vorbis " in out:
        return ["-c:a", "vorbis", "-strict", "-2", "-ac", "2"]
    return None


def write_ogg(name, x):
    import wave
    x = finish(x)
    pcm = (x * 32767.0).astype(np.int16)
    wav_path = os.path.join(OUT_DIR, name + ".wav")
    with wave.open(wav_path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    args = _vorbis_args()
    if args is None:
        os.rename(wav_path, os.path.join(OUT_DIR, name + ".wav"))
        return name + ".wav"
    ogg_path = os.path.join(OUT_DIR, name + ".ogg")
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path,
         *args, "-ar", str(SR), ogg_path],
        check=True,
    )
    os.remove(wav_path)
    return os.path.basename(ogg_path)


# ---------------------------------------------------------------------------
# Sound families
# ---------------------------------------------------------------------------

def _noise(rng, n):
    return rng.standard_normal(n)


def footstep(surface, rng):
    dur = float(rng.uniform(0.10, 0.17))
    n = int(dur * SR)
    out = np.zeros(n)
    white = _noise(rng, n)

    if surface == "dirt":
        grit = band(white, 0.04, 0.35) * env_exp(n, 55)
        thump = lowpass(white, 0.03) * env_exp(n, 90)
        out = grit * 0.8 + thump * 1.1
    elif surface == "grass":
        rustle = band(white, 0.35, 0.75) * env_exp(n, 70)
        out = rustle * 1.2
        # heel-toe second phase
        phase = band(_noise(rng, n // 2), 0.30, 0.70) * env_exp(n // 2, 80) * 0.7
        out[n // 3 : n // 3 + len(phase)] += phase
    elif surface == "stone":
        click = band(white, 0.55, 0.9) * env_exp(n, 160)
        body = lowpass(white, 0.06) * env_exp(n, 110) * 0.6
        out = click * 1.2 + body
    elif surface == "wood":
        t = np.arange(n) / SR
        knock = sum(np.sin(2 * np.pi * f * t + rng.uniform(0, 6)) *
                    np.exp(-t * rng.uniform(50, 90)) * a
                    for f, a in [(190, 1.0), (330, 0.6), (520, 0.35)])
        grit = band(white, 0.05, 0.4) * env_exp(n, 100) * 0.5
        out = knock * 0.8 + grit
    elif surface == "mud":
        squelch = lowpass(white, 0.02) * env_exp(n, 45)
        t = np.arange(n // 2) / SR
        blip = np.sin(2 * np.pi * (240 - 500 * t) * t) * env_exp(len(t), 60) * 0.5
        out = squelch * 1.3
        out[len(out) // 4 : len(out) // 4 + len(blip)] += blip
    elif surface == "water":
        splash = band(white, 0.20, 0.85) * env_exp(n, 40)
        t = np.arange(n) / SR
        wob = np.sin(2 * np.pi * (600 + 900 * np.sin(2 * np.pi * 11 * t)) * t)
        bubbles = wob * env_exp(n, 18) * 0.22
        out = splash * 0.9 + bubbles
    elif surface == "metal":
        t = np.arange(n) / SR
        ring = sum(np.sin(2 * np.pi * f * t + rng.uniform(0, 6)) *
                   np.exp(-t * rng.uniform(24, 60)) * a
                   for f, a in [(1700, 1.0), (2450, 0.7), (3900, 0.5), (5200, 0.3)])
        strike = band(white, 0.4, 0.9) * env_exp(n, 200) * 0.9
        out = ring * 0.55 + strike
    else:
        raise ValueError("unknown surface " + surface)
    return out


def whoosh(rng, heavy=False):
    dur = float(rng.uniform(0.34, 0.46) if heavy else rng.uniform(0.22, 0.32))
    n = int(dur * SR)
    white = _noise(rng, n)
    lo = 0.010 if heavy else 0.02
    body = band(white, lo, lo + 0.14)
    # amplitude swell then cut (swing arc)
    t = np.linspace(0, 1, n)
    amp = np.sin(np.pi * t ** 1.6)
    # downward spectral motion: crossfade two bands
    bright = band(white, 0.10, 0.30)
    dark = lowpass(body, 0.05)
    morph = np.linspace(0.9, 0.2, n)
    out = (bright * morph + dark * (1 - morph)) * amp
    if heavy:
        out *= 1.25
    return out


def metal_scrape(rng, rise=True, bright=1.0, dur=None):
    dur = dur or float(rng.uniform(0.28, 0.42))
    n = int(dur * SR)
    out = np.zeros(n)
    n_pings = rng.integers(7, 13)
    span = np.linspace(0, dur * 0.92, n_pings)
    if not rise:
        span = span[::-1]
    for k, at in enumerate(span):
        plen = int(rng.uniform(0.02, 0.05) * SR)
        t = np.arange(plen) / SR
        f = rng.uniform(2200, 6500) * bright
        ping = (np.sin(2 * np.pi * f * t) +
                0.4 * np.sin(2 * np.pi * f * 2.31 * t)) * env_exp(plen, 90)
        hiss = band(_noise(rng, plen), 0.4, 0.85) * env_exp(plen, 130) * 0.5
        place(out, (ping * 0.5 + hiss), at)
    bed = band(_noise(rng, n), 0.25, 0.7) * env_adsr(n, 0.01, dur * 0.5, 0.5, 0.1) * 0.25
    return out + bed


def material_hit(kind, rng):
    dur = float(rng.uniform(0.26, 0.42))
    n = int(dur * SR)
    t = np.arange(n) / SR
    white = _noise(rng, n)
    if kind == "flesh":
        thud = lowpass(white, 0.012) * env_exp(n, 55) * 1.3
        slap = band(white, 0.08, 0.3) * env_exp(n, 150) * 0.7
        return thud + slap
    if kind == "wood":
        knock = sum(np.sin(2 * np.pi * f * t + rng.uniform(0, 6)) *
                    np.exp(-t * rng.uniform(38, 70)) * a
                    for f, a in [(230, 1.0), (480, 0.55), (810, 0.3)])
        return knock * 1.1 + band(white, 0.05, 0.4) * env_exp(n, 130) * 0.5
    if kind == "metal":
        ring = sum(np.sin(2 * np.pi * f * t + rng.uniform(0, 6)) *
                   np.exp(-t * rng.uniform(16, 40)) * a
                   for f, a in [(1350, 1.0), (2100, 0.65), (3400, 0.45), (4900, 0.3)])
        return ring * 0.9 + band(white, 0.35, 0.9) * env_exp(n, 180) * 0.7
    if kind == "stone":
        crack = band(white, 0.30, 0.85) * env_exp(n, 120) * 1.2
        body = lowpass(white, 0.03) * env_exp(n, 70) * 0.9
        return crack + body
    raise ValueError(kind)


def metal_clash(rng, parry=False):
    dur = float(rng.uniform(0.5, 0.75) if parry else rng.uniform(0.3, 0.45))
    n = int(dur * SR)
    t = np.arange(n) / SR
    base = rng.uniform(1800, 2600)
    partials = [(base, 1.0), (base * 1.51, 0.7), (base * 2.07, 0.5),
                (base * 2.89, 0.35), (base * 3.83, 0.22)]
    decay = rng.uniform(14, 24) if parry else rng.uniform(24, 40)
    ring = sum(np.sin(2 * np.pi * f * t + rng.uniform(0, 6)) *
               np.exp(-t * decay) * a for f, a in partials)
    burst = band(_noise(rng, n), 0.35, 0.95) * env_exp(n, 260) * 0.8
    shimmer = np.sin(2 * np.pi * base * 1.02 * t) * np.exp(-t * 8) * 0.2
    return ring * (0.75 if parry else 0.9) + burst + shimmer


def clatter(rng, bounces=3, tone=(900, 1400)):
    total = 0.55
    n = int(total * SR)
    out = np.zeros(n)
    at = 0.0
    for b in range(bounces):
        plen = int(rng.uniform(0.09, 0.16) * SR)
        t = np.arange(plen) / SR
        f = rng.uniform(*tone)
        hit = (sum(np.sin(2 * np.pi * h * t + rng.uniform(0, 6)) *
                   np.exp(-t * rng.uniform(40, 80)) * w
                   for h, w in [(f, 1.0), (f * 1.7, 0.5)]) +
               band(_noise(rng, plen), 0.3, 0.8) * env_exp(plen, 200) * 0.6)
        gain = 0.9 ** b * rng.uniform(0.7, 1.0)
        place(out, hit * gain, at)
        at += rng.uniform(0.12, 0.19) * (0.8 ** b)
    return out


def cloth_swish(rng, soft=False):
    dur = float(rng.uniform(0.25, 0.4))
    n = int(dur * SR)
    white = _noise(rng, n)
    lo = 0.06 if soft else 0.12
    body = band(white, lo, lo + 0.22)
    t = np.linspace(0, 1, n)
    amp = np.sin(np.pi * t ** (1.4 if soft else 1.1))
    flutter = 1 + 0.25 * np.sin(2 * np.pi * rng.uniform(9, 16) * t * SR / SR * n / n)
    return body * amp * flutter


def creak(rng, dur=None):
    dur = dur or float(rng.uniform(0.6, 1.0))
    n = int(dur * SR)
    t = np.arange(n) / SR
    # stick-slip: narrowband noise whose center frequency wobbles upward
    steps = 14
    out = np.zeros(n)
    seg = n // steps
    f0 = rng.uniform(320, 520)
    for s in range(steps):
        f = f0 * (1 + 0.5 * s / steps) * rng.uniform(0.97, 1.03)
        sl = band(_noise(rng, seg * 2), f / (SR / 2) * 0.9, min(0.9, f / (SR / 2) * 1.15))
        win = env_adsr(seg, 0.002, 0.05, 0.8, 0.02)
        i = s * seg
        out[i : i + seg] += sl[:seg] * win[:seg] * rng.uniform(0.6, 1.0)
    return lowpass(out, 0.35) * 1.1


def door_close(rng, heavy=False):
    n = int(1.0 * SR)
    out = np.zeros(n)
    if heavy:
        boom_len = int(0.35 * SR)
        t = np.arange(boom_len) / SR
        boom = (np.sin(2 * np.pi * 62 * t) * np.exp(-t * 14) +
                0.6 * np.sin(2 * np.pi * 41 * t) * np.exp(-t * 10))
        place(out, boom * 1.2, 0.02)
        latch_len = int(0.06 * SR)
        lt = np.arange(latch_len) / SR
        latch = band(_noise(rng, latch_len), 0.4, 0.85) * env_exp(latch_len, 260)
        place(out, latch * 0.7, 0.30)
    else:
        thud_len = int(0.16 * SR)
        t = np.arange(thud_len) / SR
        thud = (np.sin(2 * np.pi * 128 * t) * np.exp(-t * 30) +
                band(_noise(rng, thud_len), 0.05, 0.35) * env_exp(thud_len, 90) * 0.8)
        place(out, thud, 0.01)
        latch_len = int(0.05 * SR)
        lt = np.arange(latch_len) / SR
        latch = band(_noise(rng, latch_len), 0.5, 0.9) * env_exp(latch_len, 300)
        place(out, latch * 0.6, 0.14)
    return out


def door_open(rng):
    n = int(1.1 * SR)
    out = np.zeros(n)
    place(out, creak(rng, 0.55) * 0.9, 0.05)
    latch_len = int(0.05 * SR)
    lt = np.arange(latch_len) / SR
    latch = band(_noise(rng, latch_len), 0.45, 0.9) * env_exp(latch_len, 280)
    place(out, latch * 0.8, 0.0)
    return out


def crackle_bed(rng, dur, density, size_lo=120, size_hi=900, bed=0.35):
    n = int(dur * SR)
    out = np.zeros(n)
    brown = lowpass(_noise(rng, n), 0.008)
    brown /= np.max(np.abs(brown)) + 1e-9
    out += brown * bed
    for _ in range(int(density * dur)):
        plen = int(rng.uniform(size_lo, size_hi))
        pt = np.arange(plen) / SR
        pop = np.sin(2 * np.pi * rng.uniform(900, 4200) * pt + rng.uniform(0, 6)) * \
            env_exp(plen, rng.uniform(50, 160))
        place(out, pop * rng.uniform(0.2, 0.6), rng.uniform(0, dur - 0.02))
    return out


def rain_bed(rng, dur, heavy=False):
    n = int(dur * SR)
    white = _noise(rng, n)
    hiss = band(white, 0.25 if heavy else 0.35, 0.9)
    drops = np.zeros(n)
    count = int((60 if heavy else 26) * dur)
    for _ in range(count):
        plen = int(rng.uniform(60, 260))
        pt = np.arange(plen) / SR
        drop = np.sin(2 * np.pi * rng.uniform(1400, 3800) * pt) * \
            env_exp(plen, rng.uniform(180, 420))
        place(drops, drop * rng.uniform(0.05, 0.16), rng.uniform(0, dur - 0.01))
    wander = 0.7 + 0.3 * lowpass(_noise(rng, n), 0.00008)
    return (hiss * (0.8 if heavy else 0.55) + drops) * wander


def thunder(rng):
    dur = 3.2
    n = int(dur * SR)
    crack_len = int(0.25 * SR)
    crack = band(_noise(rng, crack_len), 0.25, 0.95) * env_exp(crack_len, 26) * 1.2
    rumble_n = n - crack_len
    rumble = lowpass(_noise(rng, rumble_n), 0.004) * env_exp(rumble_n, 1.6)
    growl = 0.4 * np.sin(2 * np.pi * rng.uniform(38, 55) *
                         np.arange(rumble_n) / SR) * env_exp(rumble_n, 1.2)
    out = np.concatenate([crack, rumble + growl])
    return out


def wind_bed(rng, dur, strength=0.5, interior=False):
    n = int(dur * SR)
    white = _noise(rng, n)
    alpha = 0.02 + 0.03 * (1 - strength)
    body = lowpass(white, alpha)
    gusts = lowpass(_noise(rng, n), 0.00004)
    gusts = 0.55 + 0.45 * (gusts / (np.max(np.abs(gusts)) + 1e-9))
    howl_t = np.arange(n) / SR
    howl_f = rng.uniform(280, 420)
    howl = np.sin(2 * np.pi * howl_f * howl_t +
                  3 * np.sin(2 * np.pi * 0.13 * howl_t)) * \
        lowpass(gusts, 0.0001) * (1 - strength) * 0.25
    out = body * gusts * (0.6 + 0.8 * strength) + howl
    if interior:
        out = lowpass(out, 0.012) * 0.7
    # make seamless loop
    xfade = int(1.5 * SR)
    ramp = np.linspace(0, 1, xfade)
    out[:xfade] = out[:xfade] * ramp + out[-xfade:] * (1 - ramp)
    return out[: n - xfade]


def drip(rng):
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    f0 = rng.uniform(900, 1500)
    freq = f0 * (1 + 1.6 * np.exp(-t * 90))
    phase = 2 * np.pi * np.cumsum(freq) / SR
    ping = np.sin(phase) * env_exp(n, 26)
    return ping


def stream_bed(rng, dur=3.5):
    n = int(dur * SR)
    white = _noise(rng, n)
    flow = band(white, 0.10, 0.65)
    bubbles = np.zeros(n)
    for _ in range(int(dur * 14)):
        plen = int(rng.uniform(80, 300))
        pt = np.arange(plen) / SR
        f = rng.uniform(500, 1600)
        bub = np.sin(2 * np.pi * (f + 600 * pt) * pt) * env_exp(plen, 70)
        place(bubbles, bub * rng.uniform(0.08, 0.2), rng.uniform(0, dur - 0.02))
    return flow * 0.8 + bubbles


def paper_action(rng, kind):
    if kind == "rustle":
        dur = rng.uniform(0.3, 0.45)
        n = int(dur * SR)
        crinkles = np.zeros(n)
        for _ in range(rng.integers(9, 16)):
            plen = int(rng.uniform(0.008, 0.03) * SR)
            pt = np.arange(plen) / SR
            c = band(_noise(rng, plen), 0.45, 0.95) * env_exp(plen, rng.uniform(120, 300))
            place(crinkles, c * rng.uniform(0.3, 0.8), rng.uniform(0, dur - 0.01))
        return crinkles
    if kind == "quill":
        dur = rng.uniform(0.9, 1.3)
        n = int(dur * SR)
        out = np.zeros(n)
        strokes = rng.integers(4, 7)
        bounds = sorted(rng.uniform(0.02, dur - 0.1, strokes))
        for s in range(strokes):
            slen = int(rng.uniform(0.12, 0.22) * SR)
            scratch = band(_noise(rng, slen), 0.5, 0.92) * \
                env_adsr(slen, 0.01, 0.05, 0.7, 0.04)
            at = bounds[s] + rng.uniform(-0.02, 0.02)
            place(out, scratch * rng.uniform(0.5, 0.9), max(0, at))
            tick = int(0.012 * SR)
            tt = np.arange(tick) / SR
            tap = band(_noise(rng, tick), 0.5, 0.9) * env_exp(tick, 350)
            place(out, tap * 0.5, max(0, at) + 0.14)
        return out
    if kind == "close":
        n = int(0.35 * SR)
        slap = band(_noise(rng, n), 0.15, 0.6) * env_exp(n, 90) * 1.1
        t = np.arange(n) / SR
        thump = np.sin(2 * np.pi * 150 * t) * env_exp(n, 60) * 0.5
        return slap + thump
    if kind == "place":
        n = int(0.3 * SR)
        t = np.arange(n) / SR
        thump = np.sin(2 * np.pi * 190 * t) * env_exp(n, 70)
        slide = band(_noise(rng, n), 0.3, 0.7) * env_exp(n, 140) * 0.4
        return thump + slide
    if kind == "pickup":
        n = int(0.25 * SR)
        slide = band(_noise(rng, n), 0.25, 0.75) * env_adsr(n, 0.004, 0.1, 0.4, 0.06)
        t = np.arange(n) / SR
        tap = np.sin(2 * np.pi * 240 * t) * env_exp(n, 120) * 0.3
        return slide + tap
    if kind == "parchment":
        dur = rng.uniform(0.4, 0.6)
        n = int(dur * SR)
        out = band(_noise(rng, n), 0.4, 0.9) * env_adsr(n, 0.01, 0.2, 0.5, 0.12)
        flutter = 1 + 0.4 * np.sin(2 * np.pi * rng.uniform(14, 22) *
                                   np.arange(n) / SR * rng.uniform(2, 4))
        return out * flutter
    raise ValueError(kind)


def ui_blip(rng, kind):
    n = int(0.28 * SR)
    t = np.arange(n) / SR
    if kind == "save":
        seq = [(660, 0.0), (880, 0.09)]
        wave_kind = np.sin
    elif kind == "load":
        seq = [(880, 0.0), (660, 0.09)]
        wave_kind = np.sin
    elif kind == "open":
        seq = [(520, 0.0), (700, 0.07)]
        wave_kind = np.sin
    else:  # close
        seq = [(700, 0.0), (520, 0.07)]
        wave_kind = np.sin
    out = np.zeros(n)
    for f, at in seq:
        plen = int(0.12 * SR)
        pt = np.arange(plen) / SR
        tone = wave_kind(2 * np.pi * f * pt) * env_exp(plen, 22)
        click = band(_noise(rng, plen), 0.5, 0.9) * env_exp(plen, 400) * 0.12
        place(out, tone * 0.5 + click, at)
    return out


def coins(rng, size="medium"):
    n = int(0.6 * SR)
    out = np.zeros(n)
    count = {"small": 4, "medium": 6, "large": 9, "pouch": 8}[size]
    for i in range(count):
        plen = int(rng.uniform(0.05, 0.12) * SR)
        pt = np.arange(plen) / SR
        f = rng.uniform(3200, 5600) if size != "pouch" else rng.uniform(1800, 3000)
        ting = (np.sin(2 * np.pi * f * pt) +
                0.5 * np.sin(2 * np.pi * f * 1.618 * pt)) * env_exp(plen, rng.uniform(50, 110))
        at = rng.uniform(0, 0.28)
        place(out, ting * rng.uniform(0.3, 0.7) * (0.85 ** i), at)
    if size == "pouch":
        rustle = paper_action(rng, "rustle") * 0.4
        place(out, rustle, 0.02)
    return out


def rope_slide(rng):
    dur = rng.uniform(0.5, 0.8)
    n = int(dur * SR)
    fib = band(_noise(rng, n), 0.15, 0.55)
    t = np.linspace(0, 1, n)
    amp = np.sin(np.pi * t) ** 0.7
    fibers = np.zeros(n)
    for _ in range(rng.integers(6, 10)):
        plen = int(rng.uniform(0.01, 0.03) * SR)
        pt = np.arange(plen) / SR
        snap = band(_noise(rng, plen), 0.3, 0.8) * env_exp(plen, 220)
        place(fibers, snap * rng.uniform(0.2, 0.5), rng.uniform(0, dur - 0.02))
    return fib * amp + fibers


def mechanism(rng):
    n = int(0.8 * SR)
    out = np.zeros(n)
    at = 0.0
    while at < 0.6:
        plen = int(0.03 * SR)
        pt = np.arange(plen) / SR
        click = (np.sin(2 * np.pi * rng.uniform(800, 1400) * pt) * env_exp(plen, 200) +
                 band(_noise(rng, plen), 0.3, 0.8) * env_exp(plen, 300) * 0.7)
        place(out, click * rng.uniform(0.6, 1.0), at)
        at += rng.uniform(0.05, 0.09)
    return out


# ---------------------------------------------------------------------------
# Event table: EVENT_ID -> (generator fn(args), seconds, extra variants)
# ---------------------------------------------------------------------------

def build_plan():
    req = json.load(open(REQ_FILE))

    def iter_events():
        for group in ("music", "ambience"):
            for e in req.get(group, []):
                yield e
        for subgroup, events in req.get("sfx", {}).items():
            for e in events:
                yield e

    plan = {}
    for e in iter_events():
        eid = e["id"]
        if eid in SKIP_EVENTS:
            continue
        if e.get("review") != "standard":
            continue
        if e.get("status") == "filled":  # not present pre-index, harmless guard
            continue
        gen = SYNTH_TABLE.get(eid)
        if not gen:
            continue
        min_v = int(e.get("variants", {}).get("min", 1))
        plan[eid] = {
            "dir": e["dir"],
            "min": min_v,
            "gen": gen,
        }
    return plan


def v_foot(surface):
    return lambda rng, i: footstep(surface, rng)

def v_whoosh(heavy):
    return lambda rng, i: whoosh(rng, heavy)

def v_hit(kind):
    return lambda rng, i: material_hit(kind, rng)

def v_paper(kind):
    return lambda rng, i: paper_action(rng, kind)

def v_ui(kind):
    return lambda rng, i: ui_blip(rng, kind)

def v_coins(size):
    return lambda rng, i: coins(rng, size)

SYNTH_TABLE = {
    # footsteps still missing
    "SFX_FOOT_DIRT":   v_foot("dirt"),
    "SFX_FOOT_WATER":  v_foot("water"),
    "SFX_FOOT_METAL":  v_foot("metal"),
    # weapons
    "SFX_SWORD_SHEATHE":     lambda rng, i: metal_scrape(rng, rise=False),
    "SFX_SWORD_SWING_HEAVY": v_whoosh(True),
    "SFX_SWORD_BLOCK":       lambda rng, i: metal_clash(rng, parry=False),
    "SFX_SWORD_PARRY":       lambda rng, i: metal_clash(rng, parry=True),
    "SFX_SWORD_DROP":        lambda rng, i: clatter(rng, bounces=3),
    "SFX_KNIFE_DRAW":        lambda rng, i: metal_scrape(rng, rise=True, bright=1.3, dur=rng.uniform(0.18, 0.28)),
    "SFX_KNIFE_SWING":       v_whoosh(False),
    "SFX_KNIFE_HIT":         lambda rng, i: material_hit("flesh", rng) * 0.8,
    "SFX_KNIFE_BLOCK":       lambda rng, i: metal_clash(rng, parry=False) * 0.8,
    "SFX_BOW_DRAW":          lambda rng, i: creak(rng, rng.uniform(0.4, 0.6)) * 0.8,
    "SFX_BOW_RELEASE":       lambda rng, i: mix(
        whoosh(rng, False) * 0.9,
        metal_scrape(rng, True, 1.6, 0.15) * 0.3),
    "SFX_ARROW_FLY":         v_whoosh(False),
    "SFX_ARROW_HIT_WOOD":    v_hit("wood"),
    "SFX_ARROW_HIT_STONE":   v_hit("stone"),
    "SFX_ARROW_HIT_FLESH":   v_hit("flesh"),
    # clothing
    "SFX_CLOAK_MOVE":    lambda rng, i: cloth_swish(rng, soft=True),
    "SFX_LEATHER_MOVE":  lambda rng, i: cloth_swish(rng, soft=False),
    # doors & furniture
    "SFX_DOOR_WOOD_CLOSE":  lambda rng, i: door_close(rng, heavy=False),
    "SFX_DOOR_HEAVY_OPEN":  lambda rng, i: door_open(rng),
    "SFX_DOOR_HEAVY_CLOSE": lambda rng, i: door_close(rng, heavy=True),
    "SFX_CHEST_OPEN":       lambda rng, i: mix(
        creak(rng, 0.5) * 0.9, mechanism(rng) * 0.4),
    "SFX_CHEST_CLOSE":      lambda rng, i: door_close(rng, heavy=False) * 0.9,
    "SFX_WOOD_CREAK":       lambda rng, i: creak(rng),
    # fire
    "SFX_FIRE_CAMP":   lambda rng, i: crackle_bed(rng, 3.0, 9.0),
    "SFX_FIRE_LARGE":  lambda rng, i: crackle_bed(rng, 3.5, 16.0, 100, 1400, 0.5),
    # weather
    "SFX_RAIN_LIGHT":  lambda rng, i: rain_bed(rng, 4.0, heavy=False),
    "SFX_RAIN_HEAVY":  lambda rng, i: rain_bed(rng, 4.0, heavy=True),
    "SFX_THUNDER":     lambda rng, i: thunder(rng),
    "SFX_WIND_LIGHT":  lambda rng, i: wind_bed(rng, 4.0, 0.3),
    "SFX_WIND_STRONG": lambda rng, i: wind_bed(rng, 4.0, 0.9),
    "SFX_WIND_INTERIOR": lambda rng, i: wind_bed(rng, 4.0, 0.35, interior=True),
    # water
    "SFX_WATER_DRIP":  lambda rng, i: drip(rng),
    "SFX_WATER_STREAM": lambda rng, i: stream_bed(rng),
    # objects
    "SFX_ROPE":             lambda rng, i: rope_slide(rng),
    "SFX_METAL_MECHANISM":  lambda rng, i: mechanism(rng),
    # books & paper
    "SFX_BOOK_CLOSE":    v_paper("close"),
    "SFX_PAPER_RUSTLE":  v_paper("rustle"),
    "SFX_QUILL_WRITE":   v_paper("quill"),
    "SFX_BOOK_PLACE":    v_paper("place"),
    "SFX_BOOK_PICKUP":   v_paper("pickup"),
    "SFX_PARCHMENT":     v_paper("parchment"),
    # UI
    "SFX_UI_SAVE":           v_ui("save"),
    "SFX_UI_LOAD":           v_ui("load"),
    "SFX_UI_JOURNAL_OPEN":   v_ui("open"),
    "SFX_UI_JOURNAL_CLOSE":  v_ui("close"),
    # coins
    "SFX_COIN_MEDIUM": v_coins("medium"),
    "SFX_COIN_LARGE":  v_coins("large"),
    "SFX_COIN_POUCH":  v_coins("pouch"),
}


def stem_for(event_id, seq):
    base = event_id.lower()
    for prefix in ("sfx_", "amb_", "mus_", "instr_"):
        if base.startswith(prefix):
            base = base[len(prefix):]
            break
    return f"{base}_{seq:02d}"


def main():
    only_dry = "--dry-run" in sys.argv
    os.makedirs(OUT_DIR, exist_ok=True)
    plan = build_plan()
    print(f"{len(plan)} events planned")
    manifest = {}
    for eid in sorted(plan):
        spec = plan[eid]
        count = spec["min"]
        files = []
        for i in range(count):
            seed = hash((eid, i)) % (2 ** 32)
            rng = np.random.default_rng(seed)
            x = spec["gen"](rng, i)
            stem = stem_for(eid, i + 1)
            if only_dry:
                print(f"  would write {stem}.ogg ({spec['dir']})")
                continue
            fname = write_ogg(stem, x)
            files.append(fname)
            print(f"  {fname} -> {spec['dir']}")
        if not only_dry:
            manifest[eid] = {"dir": spec["dir"], "files": files}
    if not only_dry:
        with open(os.path.join(OUT_DIR, "manifest.json"), "w") as f:
            json.dump(manifest, f, indent=2, sort_keys=True)
        print(f"manifest: {os.path.join(OUT_DIR, 'manifest.json')}")


if __name__ == "__main__":
    main()
