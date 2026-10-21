"""Writes launch_NN.rgb, what launch_asset_test.dart holds the shipped launch
files against.

Each is one frame of the master (tool/lottie_masters/ic_anim_splash.json, in
the order it plays), reduced to 64 by 36 by the plain mean of each 40 by 40
block and stored as raw RGB, 6912 bytes. The test takes the same mean over
the frames the engine decodes, so the two differ by the codec's loss alone,
and a box left over from an earlier frame shows as a block that is far off.

The mean is taken here from the JPEG and not from launch.webp, so the test
does not check the file against itself.

Keep FRAMES the same as in launch_asset_test.dart.

    python make_launch_refs.py
"""

import io
import json
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageStat

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent.parent
sys.path.insert(0, str(ROOT / "tool"))

from lottie_reencode import LAUNCH_MASTER, _play_order  # noqa: E402

SIZE = (64, 36)

# The first, the second (the first to be stored as a box on the frame
# before), the middle, the last that moves, the first of the still ending
# (stored as one pixel) and the last.
FRAMES = [0, 1, 27, 49, 50, 55]


def main() -> None:
    played = _play_order(json.loads(LAUNCH_MASTER.read_text(encoding="utf-8")))
    small = []
    for raw, _ in played:
        frame = Image.open(io.BytesIO(raw)).convert("RGB")
        small.append(frame.reduce(frame.width // SIZE[0]))
        assert small[-1].size == SIZE
    for index in FRAMES:
        (HERE / f"launch_{index:02}.rgb").write_bytes(small[index].tobytes())
    # How far apart neighbours are, which is what the test's tolerance has
    # to stay under to tell a frame from the one before it.
    for index in range(1, len(small)):
        stat = ImageStat.Stat(ImageChops.difference(small[index - 1], small[index]))
        worst = max(high for _, high in stat.extrema)
        print(f"{index - 1:2} -> {index:2}  mean {sum(stat.mean) / 3:6.3f}  max {worst}")


if __name__ == "__main__":
    main()
