"""Build original procedural arcade cues; no third-party recordings."""
from pathlib import Path
import math
import random
import struct
import wave


def build(destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    rate = 22050
    for name, duration in [('boot', .32), ('throw', .36), ('impact', .45), ('success', .65)]:
        noise = random.Random(48)
        samples = []
        for index in range(int(rate * duration)):
            t = index / rate
            envelope = min(1, t / .008) * max(0, 1 - t / duration) ** 2
            if name == 'impact':
                signal = .65 * noise.uniform(-1, 1) + .35 * math.sin(2 * math.pi * 80 * t)
            elif name == 'throw':
                signal = .5 * noise.uniform(-1, 1) + .5 * math.sin(2 * math.pi * (700 * t - 600 * t * t))
            else:
                notes = (523.25, 659.25, 783.99, 1046.5) if name == 'success' else (330, 660, 990)
                frequency = notes[min(len(notes) - 1, int(t / duration * len(notes)))]
                signal = math.sin(2 * math.pi * frequency * t)
            samples.append(struct.pack('<h', int(10000 * envelope * signal)))
        with wave.open(str(destination / (name + '.wav')), 'wb') as audio:
            audio.setnchannels(1)
            audio.setsampwidth(2)
            audio.setframerate(rate)
            audio.writeframes(b''.join(samples))


if __name__ == '__main__':
    build(Path(__file__).resolve().parents[1] / 'assets/finishers/shared/audio')
