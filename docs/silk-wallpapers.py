#!/usr/bin/env python3
"""silk-wallpapers.py -- recolours Tokyo Night's 05-dark-waves.jpg to a theme's own colours (its picture -> grey -> a gradient
from the theme's dark background through its background to a tint of its accent; light themes get light backgrounds).
Written as NN-silk-waves.jpg in the theme folder. Shipped for Vantablack and Graphite only (the default below); the other
themes look better with their own pictures, and Tokyo Night keeps the original.
Usage:  docs/silk-wallpapers.py [--out DIR] [Theme ...]     (default: Vantablack Graphite; default out = the repo's dots/Pictures/Wallpapers)
Needs ffmpeg."""
import os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
WALLS = os.path.join(HERE, "..", "dots", "Pictures", "Wallpapers")
SOURCE = os.path.join(WALLS, "Tokyo Night", "05-dark-waves.jpg")

def palette(folder):
    p = {}
    for line in open(os.path.join(folder, "colors.toml"), encoding="utf-8"):
        m = re.match(r'\s*([a-z_0-9]+)\s*=\s*"(#[0-9a-fA-F]{6})"', line)
        if m: p[m.group(1)] = m.group(2).lower()
        m = re.match(r'\s*mode\s*=\s*"(\w+)"', line)
        if m: p["mode"] = m.group(1)
    return p

def rgb(h): return [int(h[i:i + 2], 16) for i in (1, 3, 5)]
def mix(a, b, t): return [round(x + (y - x) * t) for x, y in zip(a, b)]

def stops(p):
    """colour at brightness 0, the middle, and 255 of the grey picture"""
    bg, acc = rgb(p["background"]), rgb(p["accent"])
    fg = rgb(p.get("foreground", "#ffffff"))
    if p.get("mode") == "light":      # light background; the waves are darker, tinted streaks
        return mix(bg, [255, 255, 255], 0.35), mix(bg, acc, 0.25), mix(acc, [0, 0, 0], 0.18)
    dark = rgb(p.get("darker_background", p["background"]))
    return mix(dark, bg, 0.35), mix(bg, acc, 0.20), mix(acc, fg, 0.80)

def lut(c0, c1, c2, k):
    mid = 80
    return f"if(lt(val,{mid}),{c0[k]}+({c1[k]}-{c0[k]})*val/{mid},{c1[k]}+({c2[k]}-{c1[k]})*(val-{mid})/{255 - mid})"

def make(name, out):
    folder = os.path.join(WALLS, name); p = palette(folder)
    c0, c1, c2 = stops(p)
    for old in os.listdir(folder):
        if old.endswith("-silk-waves.jpg") and os.path.abspath(out) == os.path.abspath(WALLS): os.remove(os.path.join(folder, old))
    nums = [int(m.group(1)) for f in os.listdir(folder) if (m := re.match(r"(\d+)-", f))]
    path = os.path.join(out, name, f"{max(nums or [0]) + 1:02d}-silk-waves.jpg")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    vf = f"format=gray,format=rgb24,lutrgb=r='{lut(c0, c1, c2, 0)}':g='{lut(c0, c1, c2, 1)}':b='{lut(c0, c1, c2, 2)}'"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", SOURCE, "-vf", vf, "-q:v", "2", path], check=True)
    return path

if __name__ == "__main__":
    a = sys.argv[1:]; out = WALLS
    if "--out" in a: i = a.index("--out"); out = a[i + 1]; a = a[:i] + a[i + 2:]
    for n in a or ["Vantablack", "Graphite"]:
        print(make(n, out))
