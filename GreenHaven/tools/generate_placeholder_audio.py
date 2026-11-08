#!/usr/bin/env python3
"""Generates PLACEHOLDER sound effects and a background music loop.

Output: assets/placeholder/audio/*.wav (16-bit mono, 22050 Hz).
Synthesized from simple oscillators so the project has a coherent, soft
"cozy" sound palette until real audio is commissioned (see docs/ASSET_GUIDE.md).

Usage (from GreenHaven/):  python3 tools/generate_placeholder_audio.py
Requires numpy. Deterministic (fixed random seed).
"""

from __future__ import annotations

import os
import wave

import numpy as np

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "placeholder", "audio")
SR = 22050
rng = np.random.default_rng(20261108)


def t_axis(seconds: float) -> np.ndarray:
    return np.arange(int(SR * seconds)) / SR


def env(n: int, attack: float = 0.005, release: float = 0.1) -> np.ndarray:
    """Attack + exponential decay envelope over n samples."""
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0.0, 1.0)
    return a * np.exp(-t / max(release, 1e-4))


def tone(
    freq: float,
    seconds: float,
    wave_kind: str = "sine",
    release: float = 0.15,
    attack: float = 0.004,
    vibrato: float = 0.0,
) -> np.ndarray:
    t = t_axis(seconds)
    f = freq * (1.0 + vibrato * np.sin(2 * np.pi * 5.0 * t))
    phase = 2 * np.pi * np.cumsum(f) / SR
    if wave_kind == "sine":
        w = np.sin(phase)
    elif wave_kind == "triangle":
        w = 2.0 / np.pi * np.arcsin(np.sin(phase))
    elif wave_kind == "soft_square":
        w = np.tanh(3.0 * np.sin(phase)) * 0.7
    else:
        raise ValueError(wave_kind)
    return w * env(len(t), attack, release)


def noise(seconds: float, release: float = 0.05, lowpass: float = 0.2) -> np.ndarray:
    n = int(SR * seconds)
    x = rng.standard_normal(n)
    # One-pole low-pass: lowpass in (0, 1], smaller = darker.
    y = np.zeros(n)
    acc = 0.0
    for i in range(n):
        acc += lowpass * (x[i] - acc)
        y[i] = acc
    return y / (np.max(np.abs(y)) + 1e-9) * env(n, 0.002, release)


def place(buf: np.ndarray, sound: np.ndarray, at: float, gain: float = 1.0) -> None:
    i = int(at * SR)
    end = min(len(buf), i + len(sound))
    buf[i:end] += sound[: end - i] * gain


def note(name: str) -> float:
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    octave = int(name[-1])
    semis = names[name[0]] + (1 if "#" in name else 0) + (octave - 4) * 12
    return 440.0 * 2 ** (semis / 12.0)


def save(name: str, data: np.ndarray, peak: float = 0.6) -> None:
    os.makedirs(OUT, exist_ok=True)
    data = data / (np.max(np.abs(data)) + 1e-9) * peak
    pcm = (np.clip(data, -1.0, 1.0) * 32767).astype("<i2")
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("wrote", os.path.relpath(path, ROOT))


# --- Sound effects -----------------------------------------------------------
def sfx_click() -> np.ndarray:
    buf = tone(1320, 0.06, "triangle", release=0.015)
    place(buf, noise(0.03, 0.01, 0.5), 0.0, 0.3)
    return buf


def sfx_plant() -> np.ndarray:
    buf = np.zeros(int(SR * 0.35))
    place(buf, noise(0.25, 0.06, 0.08), 0.0, 1.0)  # soil "puff"
    place(buf, tone(330, 0.2, "sine", 0.08), 0.02, 0.5)
    place(buf, tone(494, 0.2, "sine", 0.08), 0.09, 0.35)
    return buf


def sfx_harvest() -> np.ndarray:
    buf = np.zeros(int(SR * 0.6))
    for k, n in enumerate(["C5", "E5", "G5", "C6"]):
        place(buf, tone(note(n), 0.35, "triangle", 0.12), k * 0.06, 0.7)
    place(buf, noise(0.15, 0.05, 0.3), 0.0, 0.25)  # leaves rustle
    return buf


def sfx_coins() -> np.ndarray:
    buf = np.zeros(int(SR * 0.5))
    for k, f in enumerate([1975, 2637, 2349]):
        place(buf, tone(f, 0.3, "sine", 0.09), k * 0.05, 0.6)
        place(buf, tone(f * 2.01, 0.15, "sine", 0.04), k * 0.05, 0.15)
    return buf


def sfx_buy() -> np.ndarray:
    buf = np.zeros(int(SR * 0.45))
    place(buf, tone(note("G5"), 0.2, "triangle", 0.07), 0.0, 0.6)
    place(buf, tone(note("D6"), 0.3, "triangle", 0.1), 0.08, 0.6)
    return buf


def sfx_level_up() -> np.ndarray:
    buf = np.zeros(int(SR * 1.2))
    for k, n in enumerate(["C5", "E5", "G5", "C6", "E6"]):
        place(buf, tone(note(n), 0.6, "triangle", 0.25, vibrato=0.004), k * 0.09, 0.6)
    place(buf, tone(note("C4"), 1.0, "sine", 0.4), 0.0, 0.3)
    return buf


def sfx_error() -> np.ndarray:
    buf = np.zeros(int(SR * 0.3))
    place(buf, tone(220, 0.12, "soft_square", 0.05), 0.0, 0.5)
    place(buf, tone(185, 0.16, "soft_square", 0.06), 0.1, 0.5)
    return buf


def sfx_pickup() -> np.ndarray:
    buf = np.zeros(int(SR * 0.2))
    t = t_axis(0.15)
    sweep = np.sin(2 * np.pi * np.cumsum(np.linspace(300, 700, len(t))) / SR) * env(len(t), 0.005, 0.06)
    place(buf, sweep, 0.0, 0.6)
    return buf


def sfx_place() -> np.ndarray:
    # Wooden "knock": short low tone + dark noise.
    buf = np.zeros(int(SR * 0.25))
    place(buf, tone(160, 0.15, "sine", 0.04), 0.0, 0.9)
    place(buf, noise(0.08, 0.02, 0.15), 0.0, 0.6)
    return buf


def sfx_panel() -> np.ndarray:
    buf = np.zeros(int(SR * 0.18))
    place(buf, noise(0.12, 0.04, 0.12), 0.0, 0.4)  # paper/wood swish
    place(buf, tone(880, 0.1, "sine", 0.04), 0.02, 0.25)
    return buf


# --- Music ---------------------------------------------------------------------
def music_loop() -> np.ndarray:
    """Calm 80 BPM loop: I–vi–IV–V in C, soft pad + plucked arpeggio.
    Exactly 8 bars so it loops seamlessly (tails are wrapped around)."""
    bpm = 80.0
    beat = 60.0 / bpm
    bars = 8
    length = bars * 4 * beat
    n = int(SR * length)
    buf = np.zeros(n + SR * 3)
    chords = [["C3", "E4", "G4", "C5"], ["A2", "E4", "A4", "C5"], ["F2", "F4", "A4", "C5"], ["G2", "D4", "G4", "B4"]]
    for bar in range(bars):
        chord = chords[bar % 4]
        t0 = bar * 4 * beat
        # Pad: soft sustained triangle notes.
        for nn in chord[1:]:
            place(buf, tone(note(nn), 4 * beat * 1.1, "triangle", 2.2, attack=0.4, vibrato=0.002), t0, 0.12)
        place(buf, tone(note(chord[0]), 4 * beat, "sine", 1.5, attack=0.05), t0, 0.35)
        # Pluck arpeggio on eighth notes.
        pattern = [1, 2, 3, 2, 1, 2, 3, 2]
        for k, idx in enumerate(pattern):
            f = note(chord[idx]) * (2.0 if bar % 2 == 1 and k == 6 else 1.0)
            place(buf, tone(f, 0.6, "sine", 0.25), t0 + k * beat / 2, 0.16)
    # Fold the tail that spills past the loop end back to the start.
    out = buf[:n].copy()
    tail = buf[n:]
    out[: len(tail)] += tail
    return out


def main() -> None:
    effects = {
        "sfx_click": sfx_click,
        "sfx_plant": sfx_plant,
        "sfx_harvest": sfx_harvest,
        "sfx_coins": sfx_coins,
        "sfx_buy": sfx_buy,
        "sfx_level_up": sfx_level_up,
        "sfx_error": sfx_error,
        "sfx_pickup": sfx_pickup,
        "sfx_place": sfx_place,
        "sfx_panel": sfx_panel,
    }
    for name, fn in effects.items():
        save(name, fn())
    save("music_home_garden", music_loop(), peak=0.45)


if __name__ == "__main__":
    main()
