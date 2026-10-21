"""Writes film.webp, the animated WebP the LaunchFilm tests decode.

Eight frames of 16 by 9, each one solid colour, so a test names the frame on
screen by reading one pixel. Lossless, so the colour read back is the colour
written. The durations differ, so a test can tell a frame held for its own
time from one held for its neighbour's. The loop count is 0, which in WebP
means for ever: the player must stop at the last frame all the same.

Keep COLOURS and DURATIONS_MS the same as in launch_film_test.dart.

    python make_film.py
"""

from pathlib import Path

from PIL import Image

SIZE = (16, 9)

COLOURS = [
    (255, 0, 0),
    (0, 255, 0),
    (0, 0, 255),
    (255, 255, 0),
    (0, 255, 255),
    (255, 0, 255),
    (255, 128, 0),
    (255, 255, 255),
]

DURATIONS_MS = [40, 40, 40, 120, 40, 40, 40, 80]

OUT = Path(__file__).with_name("film.webp")


def main() -> None:
    frames = [Image.new("RGB", SIZE, colour) for colour in COLOURS]
    frames[0].save(
        OUT,
        save_all=True,
        append_images=frames[1:],
        duration=DURATIONS_MS,
        loop=0,
        lossless=True,
        # Nothing clever: every frame whole, in the order given.
        minimize_size=False,
        allow_mixed=False,
    )
    with Image.open(OUT) as film:
        assert film.n_frames == len(COLOURS), film.n_frames
        for index, colour in enumerate(COLOURS):
            film.seek(index)
            # Pillow fills in the duration when it decodes the frame.
            film.load()
            assert film.info["duration"] == DURATIONS_MS[index], index
            assert film.convert("RGB").getpixel((8, 4)) == colour, index
    print(f"{OUT.name}: {OUT.stat().st_size} bytes, {len(COLOURS)} frames")


if __name__ == "__main__":
    main()
