"""Turn the wallet's own Lottie files into art/<name>.js for the mockup page.

The page runs from file://, where fetch() of a JSON file is refused, so each
animation is a script that sets window.LOTTIE_DATA[name]. Nothing is redrawn:
the files are assets/lottie/*.json as the wallet ships them. The launch
animation alone is changed, and only in weight: its 56 frames of 2560x1440
JPEG are halved to 1280x720 so the review page loads it in a moment; the
composition keeps its size, so it plays the same.

    python art.py
"""
import base64, io, json, os
from PIL import Image

here = os.path.dirname(os.path.abspath(__file__))
src = os.path.join(here, '..', '..', 'assets', 'lottie')
out = os.path.join(here, 'art')
os.makedirs(out, exist_ok=True)

NAMES = ['splash', 'welcome', 'map', 'pillar', 'pillar_small', 'sentinel', 'sentinel_small',
         'zts', 'zts_small', 'plasma_generation', 'eye', 'no_data']

for name in NAMES:
    j = json.load(open(os.path.join(src, f'ic_anim_{name}.json'), encoding='utf-8'))
    if name == 'splash':
        for a in j['assets']:
            p = a.get('p', '')
            if p.startswith('data:image'):
                im = Image.open(io.BytesIO(base64.b64decode(p.split(',', 1)[1]))).convert('RGB')
                im = im.resize((1280, 720), Image.LANCZOS)
                b = io.BytesIO(); im.save(b, 'JPEG', quality=78, optimize=True)
                a['p'] = 'data:image/jpeg;base64,' + base64.b64encode(b.getvalue()).decode()
    body = json.dumps(j, separators=(',', ':'))
    path = os.path.join(out, name + '.js')
    open(path, 'w', encoding='utf-8', newline='\n').write(
        '(window.LOTTIE_DATA=window.LOTTIE_DATA||{})["%s"]=%s;\n' % (name, body))
    print(f'{name:18s} {os.path.getsize(path)//1024:6d} KB  {j["w"]}x{j["h"]}  {(j["op"]-j["ip"])/j["fr"]:.2f} s')
