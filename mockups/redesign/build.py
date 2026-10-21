"""Build index.html from src/*.html and render every screen to shots/.

Fonts: the two woff2 files are taken from ../home/index.html, where they were
inlined for the home mockups, so nothing is fetched. Screenshots: headless
Chrome at 1280x780, one per screen per theme, named NN-<id>-<theme>.png.

    python build.py          build only
    python build.py shots    build and render
"""
import glob, os, re, subprocess, sys

here = os.path.dirname(os.path.abspath(__file__))
src = ''.join(open(p, encoding='utf-8').read() for p in sorted(glob.glob(os.path.join(here, 'src', '*.html'))))
open(os.path.join(here, 'index.src.html'), 'w', encoding='utf-8', newline='\n').write(src)

home = open(os.path.join(here, '..', 'home', 'index.html'), encoding='utf-8').read()
fonts = re.findall(r'base64,([A-Za-z0-9+/=]+)\)', home)
if len(fonts) < 2:
    sys.exit('fonts not found in ../home/index.html')
out = src.replace('__SG__', fonts[0]).replace('__JB__', fonts[1])
open(os.path.join(here, 'index.html'), 'w', encoding='utf-8', newline='\n').write(out)
ids = re.findall(r'<section class="scr" id="([^"]+)"', src)
print(f'index.html: {len(out)//1024} KB, {len(ids)} screens')

if len(sys.argv) > 1 and sys.argv[1] == 'shots':
    chrome = next(p for p in [
        r'C:\Program Files\Google\Chrome\Application\chrome.exe',
        r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'] if os.path.exists(p))
    shots = os.path.join(here, 'shots')
    os.makedirs(shots, exist_ok=True)
    url = 'file:///' + os.path.join(here, 'index.html').replace('\\', '/')
    for n, sid in enumerate(ids, 1):
        for theme in ('dark', 'light'):
            png = os.path.join(shots, f'{n:02d}-{sid}-{theme}.png')
            subprocess.run([chrome, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--window-size=1280,780',
                            '--force-device-scale-factor=1', '--virtual-time-budget=6000',
                            f'--screenshot={png}', f'{url}?shot={sid}&theme={theme}'],
                           check=True, capture_output=True)
            print(os.path.basename(png))
