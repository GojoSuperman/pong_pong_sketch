#!/usr/bin/env python3
"""퐁퐁 스케치 — 8비트 칩튠 사운드 합성 스크립트.

numpy로 파형을 직접 합성하고 ffmpeg(libmp3lame)로 MP3 인코딩한다.
인터넷 다운로드 없이 100% 코드로 생성하므로 저작권이 완전히 자유롭다(CC0 동등).

생성물 → assets/audio/
  - bgm_sketch_world.mp3 : 경쾌하게 무한 루프되는 8비트 배경음악
  - sfx_jump.mp3         : 아래→위로 솟는 상승형 점프음
  - sfx_purify.mp3       : 영롱한 차임벨/트윙클 정화음
  - sfx_stomp.mp3        : 장난감을 밟은 듯한 '뾱!' 타격음
  - sfx_victory.mp3      : 3~4초 8비트 승리 팡파르

실행: python tools/generate_chiptune_audio.py
"""

import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

# Windows 콘솔(cp949)에서도 유니코드 출력이 깨지지 않도록 stdout을 UTF-8로 고정.
try:
    sys.stdout.reconfigure(encoding='utf-8')
except (AttributeError, OSError):
    pass

SR = 44100  # 샘플레이트 (Hz)
OUT_DIR = os.path.normpath(
    os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')
)

# ─────────────────────────────────────────────
# 음이름 → 주파수
# ─────────────────────────────────────────────
_SEMITONE = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}


def freq(name):
    """'C4', 'A#4', 'Bb5' 같은 음이름을 주파수(Hz)로 변환한다."""
    semi = _SEMITONE[name[0].upper()]
    i = 1
    if name[i] in '#b':
        semi += 1 if name[i] == '#' else -1
        i += 1
    midi = 12 * (int(name[i:]) + 1) + semi
    return 440.0 * 2 ** ((midi - 69) / 12)


# ─────────────────────────────────────────────
# 파형·엔벨로프 유틸
# ─────────────────────────────────────────────
def _time(dur):
    """길이 dur초에 해당하는 시간축 배열."""
    return np.arange(int(SR * dur)) / SR


def pluck_env(n, decay=7.0, attack=0.004):
    """현을 튕긴 듯한 엔벨로프 — 빠른 어택 + 지수 감쇠. (마림바/실로폰 느낌)"""
    t = np.arange(n) / SR
    return np.clip(t / attack, 0, 1) * np.exp(-decay * t)


def normalize(buf, peak=0.9):
    """버퍼 진폭을 peak 기준으로 정규화한다."""
    m = float(np.max(np.abs(buf)))
    return buf * (peak / m) if m > 0 else buf


def edge_fade(buf, ms=4):
    """클릭 노이즈 방지 — 버퍼 양 끝을 짧게 페이드한다."""
    k = int(SR * ms / 1000)
    if 2 * k < len(buf):
        ramp = np.linspace(0, 1, k)
        buf[:k] *= ramp
        buf[-k:] *= ramp[::-1]
    return buf


def add_at(master, clip, start_sec):
    """master 버퍼의 start_sec 위치에 clip을 더한다 (범위는 자동 클램프)."""
    i = int(start_sec * SR)
    j = min(i + len(clip), len(master))
    if i < j:
        master[i:j] += clip[:j - i]


def render_note(name, dur, wave_type='triangle', amp=1.0, decay=7.0, gate=0.9):
    """한 음(note)을 plucky 엔벨로프로 렌더한다. gate=실제 발음 비율(<1이면 스타카토)."""
    n = int(SR * dur)
    out = np.zeros(n)
    if name is None:  # 쉼표
        return out
    f = freq(name)
    body = max(1, int(n * gate))
    t = np.arange(body) / SR
    phase = (t * f) % 1.0
    if wave_type == 'square':
        w = np.where(phase < 0.5, 1.0, -1.0)
    elif wave_type == 'sine':
        w = np.sin(2 * np.pi * f * t)
    else:  # triangle — NES 삼각 채널 톤, 부드러운 마림바 느낌
        w = 2 * np.abs(2 * phase - 1) - 1
    out[:body] = w * pluck_env(body, decay=decay) * amp
    return out


# ─────────────────────────────────────────────
# 1) BGM — 경쾌한 8비트 루프
# ─────────────────────────────────────────────
def build_bgm():
    """멜로디(삼각)·베이스(사각)·아르페지오(삼각) 3성부의 8마디 루프곡.

    8마디(32박) 길이를 정확히 맞추고 모든 음을 plucky 엔벨로프로 렌더해,
    버퍼의 처음·끝이 무음에 수렴 → 파일을 이어 붙여도 끊김 없이 루프된다.
    """
    bpm = 132
    beat = 60.0 / bpm
    chords = ['C', 'G', 'Am', 'F', 'C', 'G', 'F', 'C']  # I V vi IV I V IV I
    chord_tones = {
        'C': ('C', 'E', 'G'), 'G': ('G', 'B', 'D'),
        'Am': ('A', 'C', 'E'), 'F': ('F', 'A', 'C'),
    }
    # 멜로디 — (음이름, 길이[박]). 코드 톤 위를 통통 튀는 동요풍 라인.
    melody = [
        ('E5', .5), ('G5', .5), ('C5', .5), ('E5', .5), ('G5', 1), ('E5', 1),
        ('D5', .5), ('G5', .5), ('B4', .5), ('D5', .5), ('G5', 1), ('D5', 1),
        ('C5', .5), ('E5', .5), ('A4', .5), ('C5', .5), ('E5', 1), ('A4', 1),
        ('C5', .5), ('F5', .5), ('A4', .5), ('C5', .5), ('F5', 1), ('A5', 1),
        ('G5', .5), ('E5', .5), ('C5', .5), ('E5', .5), ('G5', 1), ('C6', 1),
        ('B5', .5), ('G5', .5), ('D5', .5), ('G5', .5), ('B5', 1), ('D6', 1),
        ('A5', .5), ('F5', .5), ('C5', .5), ('F5', .5),
        ('A5', .5), ('G5', .5), ('F5', .5), ('E5', .5),
        ('C5', .5), ('E5', .5), ('G5', .5), ('E5', .5), ('C5', 2),
    ]
    total = np.zeros(int(SR * 32 * beat))

    # 멜로디 — 부드러운 삼각파.
    pos = 0.0
    for name, dur in melody:
        add_at(total, render_note(name, dur * beat, 'triangle',
                                  amp=0.55, decay=5.0, gate=0.9), pos)
        pos += dur * beat

    # 베이스·아르페지오 — 마디별 코드를 따라 자동 생성.
    for bar, chord in enumerate(chords):
        bar_t = bar * 4 * beat
        root, third, fifth = chord_tones[chord]
        # 베이스 — 사각파, 루트·5도를 4분음표로 통통 바운스.
        for q, bn in enumerate([root, fifth, root, fifth]):
            add_at(total, render_note(bn + '2', beat, 'square',
                                      amp=0.30, decay=4.0, gate=0.85),
                   bar_t + q * beat)
        # 아르페지오 — 삼각파, 트라이어드를 8분음표로 반짝반짝.
        arp = [root, third, fifth, third, root, third, fifth, third]
        for e, an in enumerate(arp):
            add_at(total, render_note(an + '5', beat * 0.5, 'triangle',
                                      amp=0.14, decay=9.0, gate=0.8),
                   bar_t + e * 0.5 * beat)
    return normalize(total, 0.9)


# ─────────────────────────────────────────────
# 2) SFX 점프 — 상승형 '뿅~'
# ─────────────────────────────────────────────
def build_jump():
    """주파수가 아래→위로 빠르게 치솟는 아케이드 점프음."""
    dur = 0.19
    t = _time(dur)
    # 270Hz → 1350Hz로 솟았다가(78% 지점) 잠깐 머문다.
    inst_f = 270 * (1350 / 270) ** np.clip(t / (dur * 0.78), 0, 1)
    phase = 2 * np.pi * np.cumsum(inst_f) / SR
    wave_sq = np.where(np.sin(phase) > 0, 1.0, -1.0)  # 사각파 — 8비트 톤
    env = np.clip(t / 0.004, 0, 1) * np.exp(-11 * t)
    return edge_fade(normalize(wave_sq * env, 0.9), ms=3)


# ─────────────────────────────────────────────
# 3) SFX 정화 — 영롱한 차임벨/트윙클
# ─────────────────────────────────────────────
def build_purify():
    """크리스탈이 터지듯 고음역대에서 반짝이는 차임벨 합성음."""
    dur = 0.75
    master = np.zeros(int(SR * dur))
    # 상행 차임 — 배음을 얹어 영롱한 종소리, 살짝 흔들리는 반짝임 추가.
    for i, name in enumerate(['C6', 'E6', 'G6', 'C7']):
        onset = i * 0.06
        f = freq(name)
        t = np.arange(int(SR * (dur - onset))) / SR
        bell = (np.sin(2 * np.pi * f * t)
                + 0.5 * np.sin(2 * np.pi * 2 * f * t)
                + 0.25 * np.sin(2 * np.pi * 3.01 * f * t))
        shimmer = 1 + 0.06 * np.sin(2 * np.pi * 7 * t)
        add_at(master, bell * np.exp(-5.5 * t) * shimmer * 0.5, onset)
    # 꼬리에 아주 짧은 고음 스파클 — 마법가루가 흩날리는 느낌.
    for k in range(4):
        f = freq('C7') * (1.0 + 0.18 * k)
        t = np.arange(int(SR * 0.12)) / SR
        add_at(master, np.sin(2 * np.pi * f * t) * np.exp(-22 * t) * 0.18,
               0.18 + k * 0.085)
    return edge_fade(normalize(master, 0.85), ms=3)


# ─────────────────────────────────────────────
# 4) SFX 몬스터 밟기 — 장난감 '뾱!'
# ─────────────────────────────────────────────
def build_stomp():
    """장난감 오리를 밟은 듯 짧게 튕기는 스퀴크음."""
    dur = 0.16
    t = _time(dur)
    # 피치: 빠르게 솟았다가(35% 지점) 쑥 내려오는 장난감 스퀴크 곡선.
    pitch = np.interp(t / dur, [0, 0.35, 1.0], [620, 1080, 430])
    phase = 2 * np.pi * np.cumsum(pitch) / SR
    cycle = (phase / (2 * np.pi)) % 1.0
    wave_sq = np.where(cycle < 0.32, 1.0, -1.0)  # duty 0.32 — 쥐어짜는 톤
    env = np.clip(t / 0.003, 0, 1) * np.exp(-9 * t)
    buf = wave_sq * env * 0.85
    # 시작 5ms에 노이즈 임팩트를 살짝 얹어 타격감을 더한다.
    n_imp = int(SR * 0.005)
    rng = np.random.default_rng(42)
    buf[:n_imp] += rng.uniform(-1, 1, n_imp) * np.linspace(0.5, 0, n_imp)
    return edge_fade(normalize(buf, 0.9), ms=2)


# ─────────────────────────────────────────────
# 5) SFX 승리 — 8비트 팡파르
# ─────────────────────────────────────────────
def _fanfare_tone(f, length, amp, duty=0.5, decay=4.0, vib=0.0):
    """팡파르용 사각파 음 — 비브라토(vib)와 지수 감쇠 적용."""
    t = np.arange(int(SR * length)) / SR
    ff = f * (1 + vib * np.sin(2 * np.pi * 5.5 * t))
    cycle = (np.cumsum(ff) / SR) % 1.0
    wave_sq = np.where(cycle < duty, 1.0, -1.0)
    env = np.clip(t / 0.005, 0, 1) * np.exp(-decay * t)
    return wave_sq * env * amp


def build_victory():
    """상승 런 → '따-따-따-따아' 모티프 → 길게 뻗는 C장조 화음의 승리 멜로디."""
    dur = 3.4
    master = np.zeros(int(SR * dur))

    # 1) 상승 런 — 도미솔도 아르페지오.
    pos = 0.0
    for name in ['C5', 'E5', 'G5', 'C6']:
        add_at(master, _fanfare_tone(freq(name), 0.16, 0.5, decay=5.0), pos)
        pos += 0.12
    # 2) 살짝 띄우는 플러리시.
    for name in ['A5', 'B5']:
        add_at(master, _fanfare_tone(freq(name), 0.14, 0.45, decay=6.0), pos)
        pos += 0.10
    # 3) '따-따-따' 모티프 → 길게 뻗는 도.
    for name in ['G5', 'G5', 'G5']:
        add_at(master, _fanfare_tone(freq(name), 0.16, 0.5, decay=6.0), pos)
        pos += 0.15
    add_at(master, _fanfare_tone(freq('C6'), 0.6, 0.5, decay=1.6, vib=0.01), pos)
    pos += 0.55
    # 4) 피날레 — C장조 화음(멜로디+화성+베이스)을 길게 울린다.
    hold = 1.7
    add_at(master, _fanfare_tone(freq('C6'), hold, 0.40, decay=1.0, vib=0.012), pos)
    add_at(master, _fanfare_tone(freq('G5'), hold, 0.22, duty=0.25, decay=1.0), pos)
    add_at(master, _fanfare_tone(freq('E5'), hold, 0.22, duty=0.25, decay=1.0), pos)
    add_at(master, _fanfare_tone(freq('C3'), hold, 0.30, decay=1.2), pos)
    # 화음 위로 흩날리는 고음 스파클.
    for k in range(5):
        f = freq('C7') * (1.0 + 0.16 * k)
        t = np.arange(int(SR * 0.14)) / SR
        add_at(master, np.sin(2 * np.pi * f * t) * np.exp(-20 * t) * 0.16,
               pos + 0.05 + k * 0.11)
    return edge_fade(normalize(master, 0.92), ms=4)


# ─────────────────────────────────────────────
# WAV → MP3 인코딩
# ─────────────────────────────────────────────
def write_mp3(buf, filename, bitrate):
    """모노 PCM 버퍼를 임시 WAV로 쓴 뒤 ffmpeg로 MP3 인코딩한다."""
    pcm = (np.clip(buf, -1, 1) * 32767).astype('<i2')
    fd, wav_path = tempfile.mkstemp(suffix='.wav')
    os.close(fd)
    try:
        with wave.open(wav_path, 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        out_path = os.path.join(OUT_DIR, filename)
        subprocess.run(
            ['ffmpeg', '-y', '-loglevel', 'error', '-i', wav_path,
             '-codec:a', 'libmp3lame', '-b:a', bitrate, '-ar', str(SR),
             '-ac', '1', out_path],
            check=True,
        )
        size = os.path.getsize(out_path)
        print(f'  ✓ {filename:<24} {size / 1024:7.1f} KB')
    finally:
        os.remove(wav_path)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    print(f'칩튠 사운드 합성 → {OUT_DIR}')
    # (파일명, 빌더, 비트레이트) — BGM은 길어 96k, 짧은 SFX는 128k.
    tracks = [
        ('bgm_sketch_world.mp3', build_bgm, '96k'),
        ('sfx_jump.mp3', build_jump, '128k'),
        ('sfx_purify.mp3', build_purify, '128k'),
        ('sfx_stomp.mp3', build_stomp, '128k'),
        ('sfx_victory.mp3', build_victory, '128k'),
    ]
    for filename, builder, bitrate in tracks:
        write_mp3(builder(), filename, bitrate)
    print('완료 — 5개 MP3 생성됨.')


if __name__ == '__main__':
    main()
