# Eenvoudige synthesizer: maakt de muziek en geluidseffecten voor The Library Never Sleeps.
import numpy as np, subprocess, os, json, wave

SR = 44100
rng = np.random.default_rng(42)
# Schrijft naar assets/sounds (uitvoeren met: python3 tools/make_sounds.py; nodig: numpy en ffmpeg)
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sounds")

def t(sec): return np.arange(int(sec * SR)) / SR
def note(n): return 440.0 * 2 ** ((n - 69) / 12)  # MIDI -> Hz

def env(n, a=0.01, d=0.1, s=0.7, r=0.2, length=None):
    """ADSR-envelope over n samples."""
    a_, d_, r_ = int(a*SR), int(d*SR), int(r*SR)
    e = np.ones(n) * s
    e[:a_] = np.linspace(0, 1, a_) if a_ > 0 else e[:a_]
    if a_ + d_ < n: e[a_:a_+d_] = np.linspace(1, s, d_)
    if r_ > 0 and r_ < n: e[-r_:] *= np.linspace(1, 0, r_)
    return e

def osc(freq, dur, kind="sine", detune=0.0):
    tt = t(dur)
    ph = 2*np.pi*freq*(1+detune)*tt
    if kind == "sine": return np.sin(ph)
    if kind == "tri": return 2/np.pi*np.arcsin(np.sin(ph))
    if kind == "saw":  # zachte zaagtand (additief, zonder aliasing)
        out = np.zeros_like(tt)
        k = 1
        while k*freq < 9000 and k <= 24:
            out += np.sin(k*ph)/k; k += 1
        return out*0.6
    if kind == "square":
        out = np.zeros_like(tt); k = 1
        while k*freq < 9000 and k <= 25:
            out += np.sin(k*ph)/k; k += 2
        return out*0.8
    raise ValueError(kind)

def pluck(freq, dur=1.2, bright=1.0):
    """Getokkelde snaar / speeldoos: harmonischen die snel uitsterven."""
    tt = t(dur); out = np.zeros_like(tt)
    for k, amp in [(1,1),(2,0.5*bright),(3,0.25*bright),(4,0.12*bright)]:
        out += amp*np.sin(2*np.pi*freq*k*tt)*np.exp(-tt*(3+k*2.5))
    return out*0.6

def bell(freq, dur=2.0):
    tt = t(dur); out = np.zeros_like(tt)
    for ratio, amp, dec in [(1,1,2.0),(2.76,0.5,3.5),(5.4,0.25,6),(8.9,0.12,9)]:
        out += amp*np.sin(2*np.pi*freq*ratio*tt)*np.exp(-tt*dec)
    return out*0.5

def noise(dur): return rng.standard_normal(int(dur*SR))

def fft_filter(x, lo=None, hi=None, circular=True):
    """Band-filter via FFT (circulair, dus naadloos voor loops)."""
    n = len(x); X = np.fft.rfft(x); f = np.fft.rfftfreq(n, 1/SR)
    g = np.ones_like(f)
    if hi: g *= 1/(1+(f/hi)**4)
    if lo: g *= 1/(1+(lo/np.maximum(f,1e-3))**4)
    return np.fft.irfft(X*g, n)

def reverb(x, wet=0.3, circular=True, size=1.0):
    """Simpele galm met echo's; circulair zodat een loop naadloos blijft."""
    out = x.copy()
    for d, a in [(0.031,0.5),(0.047,0.45),(0.071,0.4),(0.113,0.32),(0.163,0.26),(0.229,0.2),(0.311,0.15),(0.419,0.1)]:
        s = int(d*size*SR)
        out += a*wet*(np.roll(x, s) if circular else np.concatenate([np.zeros(s), x[:-s]]))
    return fft_filter(out, hi=7000)

def place(buf, sig, at):
    i = int(at*SR)
    if i >= len(buf): return
    end = min(len(buf), i+len(sig))
    buf[i:end] += sig[:end-i]

def place_wrap(buf, sig, at):
    """Zet een klank in de buffer en laat de staart terug naar het begin lopen (voor loops)."""
    i = int(at*SR) % len(buf)
    for k in range(0, len(sig)):
        pass
    n = len(sig); first = min(n, len(buf)-i)
    buf[i:i+first] += sig[:first]
    if n > first: buf[:n-first] += sig[first:]

def normalize(x, peak=0.85): return x/np.max(np.abs(x))*peak

def save(name, x, stereo_width=0.0):
    x = normalize(x)
    if stereo_width > 0:  # klein beetje breedte met een kleine vertraging rechts
        d = int(0.012*SR); r = np.roll(x, d)
        data = np.stack([x, x*(1-stereo_width)+r*stereo_width], axis=1)
    else:
        data = np.stack([x, x], axis=1)
    pcm = (data*32767).astype(np.int16)
    wav = os.path.join(OUT, name + ".wav")
    with wave.open(wav, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
    mp3 = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg","-y","-loglevel","error","-i",wav,"-codec:a","libvorbis","-q:a","6",mp3], check=True)
    os.remove(wav)
    print("saved", name, round(len(x)/SR,2), "s")

# ---------------------------------------------------------------- muziek

def chord_pad(buf, notes, at, dur, vol=0.12, kind="tri"):
    for n in notes:
        s = osc(note(n), dur, kind)*env(int(dur*SR), a=0.4, d=0.3, s=0.8, r=0.6)
        s += 0.5*osc(note(n), dur, kind, detune=0.004)*env(int(dur*SR), a=0.4, d=0.3, s=0.8, r=0.6)
        place_wrap(buf, s*vol, at)

def lobby():
    bpm = 100; beat = 60/bpm; bars = 8; L = bars*4*beat
    buf = np.zeros(int(L*SR))
    prog = [[60,64,67],[57,60,64],[53,57,60],[55,59,62]]*2  # C Am F G
    melody_scale = [72,74,76,79,81,84]
    for b in range(bars):
        ch = prog[b]; at = b*4*beat
        chord_pad(buf, [n-12 for n in ch], at, 4*beat, 0.07)
        place_wrap(buf, pluck(note(ch[0]-24), 2.0, 0.6)*0.5, at)          # bas
        place_wrap(buf, pluck(note(ch[0]-24), 1.2, 0.6)*0.35, at+2*beat)
        for i in range(8):  # arpeggio
            n = ch[i % 3] + (12 if i >= 4 else 0)
            place_wrap(buf, pluck(note(n), 0.9)*0.22, at + i*beat/2)
    # speeldoosmelodie
    mel = [76,79,81,79,76,74,72,74, 76,79,84,81,79,76,74,72, 72,76,79,76,74,72,74,76, 79,81,79,76,74,74,72,72]
    for i, n in enumerate(mel):
        if i % 4 == 3 and rng.random() < 0.3: continue
        place_wrap(buf, bell(note(n+12), 1.4)*0.13, i*beat)
    return reverb(buf, 0.35)

def library():
    bpm = 76; beat = 60/bpm; bars = 8; L = bars*4*beat
    buf = np.zeros(int(L*SR))
    prog = [[57,60,64],[53,57,60],[48,52,55],[55,59,62],[57,60,64],[50,53,57],[52,56,59],[57,60,64]]  # Am F C G Am Dm E Am
    for b in range(bars):
        ch = prog[b]; at = b*4*beat
        chord_pad(buf, [n-12 for n in ch], at, 4*beat, 0.08, "sine")
        place_wrap(buf, pluck(note(ch[0]-24), 3.0, 0.4)*0.45, at)
        pattern = [0,1,2,1,0,2,1,2]
        for i, p in enumerate(pattern):  # harp
            n = ch[p] + 12
            place_wrap(buf, pluck(note(n), 1.6, 0.8)*0.2, at + i*beat/2)
    mel = [None,76,None,74, 72,None,71,None, 72,74,76,None, 79,None,76,None, None,76,None,77, 76,74,None,72, 71,None,72,74, 76,None,None,None]
    for i, n in enumerate(mel):
        if n: place_wrap(buf, bell(note(n), 2.0)*0.1, i*beat)
    return reverb(buf, 0.45, size=1.4)

def nightmare():
    L = 32.0; buf = np.zeros(int(L*SR)); tt = np.arange(len(buf))/SR
    # lage brom (D) met trage zweving
    for n, v in [(38,0.35),(45,0.18),(50,0.1)]:
        f = note(n)
        lfo = 1+0.003*np.sin(2*np.pi*tt/L*2)
        buf += v*np.sin(2*np.pi*f*np.cumsum(lfo)/SR)
        buf += v*0.6*np.sin(2*np.pi*f*1.006*tt)
    # wind
    w = fft_filter(rng.standard_normal(len(buf)), lo=300, hi=1400)
    wind_env = 0.5+0.5*np.sin(2*np.pi*tt/L*3)**2
    buf += 0.05*w/np.std(w)*wind_env
    # enge klokjes (tritonus)
    for at, n in [(2,74),(6.5,80),(11,73),(15,79),(19.5,74),(24,68),(28,81)]:
        place_wrap(buf, bell(note(n), 4.0)*0.18, at)
    # gekraak
    for at in [8.2, 21.7]:
        place_wrap(buf, fft_filter(noise(0.4), lo=800, hi=3000)*env(int(0.4*SR), 0.01, 0.1, 0.3, 0.2)*0.08, at)
    return reverb(buf, 0.6, size=1.8)

def chase():
    bpm = 140; beat = 60/bpm; bars = 8; L = bars*4*beat
    buf = np.zeros(int(L*SR))
    roots = [38,38,41,40, 38,38,43,44]  # D D F E D D G G#
    for b in range(bars):
        r = roots[b]; at = b*4*beat
        for i in range(8):  # staccato ostinato
            n = r + [0,0,12,0,0,0,10,12][i]
            s = osc(note(n), beat/2, "saw")*env(int(beat/2*SR), 0.005, 0.08, 0.2, 0.05)
            place_wrap(buf, fft_filter(s, hi=2200)*0.28, at + i*beat/2)
        for i in [0,2]:  # kick/hartslag
            k = np.sin(2*np.pi*np.cumsum(np.linspace(110,45,int(0.25*SR)))/SR)*np.exp(-t(0.25)*14)
            place_wrap(buf, k*0.7, at + i*beat); place_wrap(buf, k*0.45, at + i*beat + beat*0.35)
        # hoge onrustige strijkers
        hi = osc(note(r+36), 4*beat, "saw")*(0.5+0.5*np.sin(2*np.pi*12*t(4*beat)))*env(int(4*beat*SR), 0.1, 0.2, 0.6, 0.2)
        place_wrap(buf, fft_filter(hi, lo=600, hi=5000)*0.06, at)
        hi2 = osc(note(r+37), 4*beat, "sine")*env(int(4*beat*SR), 0.2, 0.2, 0.6, 0.3)
        place_wrap(buf, hi2*0.04, at)
    return reverb(buf, 0.2)

def countdown():
    bpm = 160; beat = 60/bpm; bars = 8; L = bars*4*beat
    buf = np.zeros(int(L*SR))
    for i in range(bars*4):  # tik-tak
        tick = fft_filter(noise(0.04), lo=2500, hi=8000)*np.exp(-t(0.04)*90)
        place_wrap(buf, tick*(0.35 if i % 2 == 0 else 0.22), i*beat)
    prog = [50,50,53,53,55,55,57,58]
    for b in range(bars):
        at = b*4*beat; r = prog[b]
        for i in range(8):
            n = r + [0,3,7,12,7,3,7,12][i] + 12
            place_wrap(buf, pluck(note(n), 0.5, 1.2)*0.22, at + i*beat/2)
        place_wrap(buf, osc(note(r-12), 4*beat, "saw")*env(int(4*beat*SR), 0.01, 0.2, 0.5, 0.1)*0.1, at)
    return reverb(buf, 0.2)

def win():
    L = 4.5; buf = np.zeros(int(L*SR))
    seq = [(0,72),(0.15,76),(0.3,79),(0.45,84),(0.75,84),(0.9,88),(1.05,91)]
    for at, n in seq:
        s = (osc(note(n), 0.9, "square")*0.3 + pluck(note(n), 0.9))*env(int(0.9*SR), 0.01, 0.2, 0.5, 0.3)
        place(buf, s*0.35, at)
    for n in [60,64,67,72]:
        place(buf, osc(note(n), 2.8, "tri")*env(int(2.8*SR), 0.05, 0.4, 0.6, 1.2)*0.15, 1.2)
    for i in range(10):
        place(buf, bell(note(96+rng.integers(0,8)), 1.5)*0.08, 1.2 + i*0.18)
    return reverb(buf, 0.35, circular=False)

def lose():
    L = 4.0; buf = np.zeros(int(L*SR))
    for i, n in enumerate([62,61,60,59]):
        dur = 0.55 if i < 3 else 1.8
        tt = t(dur)
        bend = np.ones_like(tt) if i < 3 else np.linspace(1, 0.94, len(tt))
        ph = 2*np.pi*note(n)*np.cumsum(bend)/SR
        vib = 1+0.25*np.sin(2*np.pi*5*tt)*(i == 3)
        s = (np.sin(ph)+0.5*np.sin(2*ph)+0.25*np.sin(3*ph))*vib*env(len(tt), 0.02, 0.1, 0.7, 0.25)
        place(buf, fft_filter(s, hi=2500)*0.4, i*0.6)
    return reverb(buf, 0.3, circular=False)

# ---------------------------------------------------------------- geluidseffecten (in één bestand)

def sfx_pickup():
    swish = fft_filter(noise(0.18), lo=1500, hi=6000)*env(int(0.18*SR), 0.02, 0.05, 0.4, 0.1)*0.4
    pop = osc(1, 0.15)*0  # placeholder
    tt = t(0.15); pop = np.sin(2*np.pi*np.cumsum(np.linspace(500, 900, len(tt)))/SR)*np.exp(-tt*25)*0.6
    out = np.zeros(int(0.35*SR)); place(out, swish, 0); place(out, pop, 0.08); return out
def sfx_place():
    tt = t(0.2); thud = np.sin(2*np.pi*np.cumsum(np.linspace(160, 70, len(tt)))/SR)*np.exp(-tt*22)*0.8
    out = np.zeros(int(0.9*SR)); place(out, thud, 0)
    place(out, bell(note(84), 0.7)*0.5, 0.06); place(out, bell(note(91), 0.7)*0.5, 0.16); return reverb(out, 0.2, circular=False)
def sfx_wrong():
    tt = t(0.45); f = np.linspace(220, 150, len(tt))
    s = np.sign(np.sin(2*np.pi*np.cumsum(f)/SR))*0.5 + np.sin(2*np.pi*np.cumsum(f*1.03)/SR)*0.5
    return fft_filter(s, hi=1800)*env(len(tt), 0.01, 0.05, 0.8, 0.12)*0.6
def sfx_key():
    out = np.zeros(int(1.2*SR))
    for i, n in enumerate([84,88,91,96,100]): place(out, bell(note(n), 0.9)*0.4, i*0.07)
    return reverb(out, 0.3, circular=False)
def sfx_shush():
    n = int(1.3*SR); s = fft_filter(noise(1.3), lo=2200, hi=7500)
    e = env(n, 0.15, 0.2, 0.8, 0.5)*(1+0.15*np.sin(2*np.pi*6*t(1.3)))
    return s/np.std(s)*e*0.3
def sfx_heartbeat():
    out = np.zeros(int(0.9*SR))
    for at, v in [(0, 1.0), (0.22, 0.7)]:
        tt = t(0.2); k = np.sin(2*np.pi*np.cumsum(np.linspace(80, 40, len(tt)))/SR)*np.exp(-tt*18)
        place(out, k*v, at)
    return fft_filter(out, hi=400)
def sfx_portal():
    n = int(1.0*SR); tt = t(1.0)
    s = fft_filter(noise(1.0), lo=300, hi=3000)*np.sin(np.pi*tt/1.0)**2*0.4
    s += np.sin(2*np.pi*np.cumsum(np.linspace(200, 900, n))/SR)*np.sin(np.pi*tt)**2*0.25
    return reverb(s, 0.3, circular=False)
def sfx_coins():
    out = np.zeros(int(0.6*SR)); place(out, bell(note(95), 0.5)*0.5, 0); place(out, bell(note(100), 0.5)*0.5, 0.09); return out
def sfx_caught():
    out = np.zeros(int(1.6*SR))
    for n in [48,49,54,55,61]:
        s = osc(note(n), 1.5, "saw")*env(int(1.5*SR), 0.005, 0.3, 0.5, 0.6)
        place(out, fft_filter(s, hi=3000)*0.2, 0)
    place(out, fft_filter(noise(0.8), lo=500, hi=5000)*env(int(0.8*SR), 0.005, 0.2, 0.3, 0.4)*0.25, 0)
    return reverb(out, 0.4, circular=False)

def sprite():
    effects = [("Pickup", sfx_pickup), ("Place", sfx_place), ("Wrong", sfx_wrong), ("Key", sfx_key),
               ("Shush", sfx_shush), ("Heartbeat", sfx_heartbeat), ("Portal", sfx_portal), ("Coins", sfx_coins), ("Caught", sfx_caught)]
    slot = 2.0
    buf = np.zeros(int(slot*len(effects)*SR)); regions = {}
    for i, (name, fn) in enumerate(effects):
        s = normalize(fn(), 0.9)
        place(buf, s, i*slot)
        regions[name] = [round(i*slot, 3), round(i*slot + len(s)/SR, 3)]
    return buf, regions

if __name__ == "__main__":
    save("Lobby", lobby(), 0.3)
    save("Library", library(), 0.3)
    save("Nightmare", nightmare(), 0.4)
    save("Chase", chase(), 0.2)
    save("Countdown", countdown(), 0.2)
    save("Win", win(), 0.2)
    save("Lose", lose(), 0.2)
    buf, regions = sprite()
    save("SoundEffects", buf)
    print(regions)
