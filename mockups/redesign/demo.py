"""Build the public copy of the redesign mockup, without the easter egg.

    python demo.py . ../../../syrius-demo

Reads the mockup's src/*.html and never writes there. What is left out: the
set-originals screen, the unlabelled field at the end of Licences, and the
notes that describe either.
"""
import glob, os, re, shutil, sys

red, out = sys.argv[1], sys.argv[2]
src = ''.join(open(p, encoding='utf-8').read() for p in sorted(glob.glob(os.path.join(red, 'src', '*.html'))))


def cut(text, pattern, count=1, flags=0):
    new, n = re.subn(pattern, '', text, flags=flags)
    if n != count:
        sys.exit(f'expected {count} match(es), found {n}: {pattern[:60]}')
    return new


# The screen itself.
src = cut(src, r'<section class="scr" id="set-originals".*?</section>\n*', flags=re.S)
# The field under the last licence, in the Licences screen.
src = cut(src, r'[ \t]*<div style="padding:22px 16px 26px;border-top:1px solid var\(--line\)"><div class="field" style="width:132px;height:34px"></div></div>\n')
# Notes.
src = cut(src, r"[ \t]*'set-originals': \[.*?\]\],\n")
src = cut(src, r', \["The box", "[^"]*"\], \["Anything but 321", "[^"]*"\]')
src = cut(src, r' Nothing here says there is anything else\.')
# The README is not published: it describes what is left out here.
src = cut(src, r' README\.md has the plan\.')

for word in ('set-originals', 'Originals', 'Easter', 'easter', 'Anything but 321'):
    if word in src:
        sys.exit(f'still present: {word}')

home = open(os.path.join(red, '..', 'home', 'index.html'), encoding='utf-8').read()
fonts = re.findall(r'base64,([A-Za-z0-9+/=]+)\)', home)
if len(fonts) < 2:
    sys.exit('fonts not found')
page = src.replace('__SG__', fonts[0]).replace('__JB__', fonts[1])

os.makedirs(out, exist_ok=True)
open(os.path.join(out, 'index.html'), 'w', encoding='utf-8', newline='\n').write(page)
for d in ('art', 'vendor'):
    dst = os.path.join(out, d)
    if os.path.isdir(dst):
        shutil.rmtree(dst)
    shutil.copytree(os.path.join(red, d), dst)
open(os.path.join(out, '.nojekyll'), 'w').write('')
ids = re.findall(r'<section class="scr" id="([^"]+)"', src)
print(f'index.html {len(page)//1024} KB, {len(ids)} screens')
