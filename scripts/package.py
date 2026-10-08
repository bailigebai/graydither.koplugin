"""Build the plugin ZIP and synthetic gray-ramp CBZ using only Python stdlib."""
from __future__ import annotations
import hashlib
import json
import re
import shutil
import struct
import zlib
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
PLUGIN = ROOT/"graydither.koplugin"
DIST = ROOT/"dist"
VERSION = re.search(r'\bversion\s*=\s*"(\d+\.\d+\.\d+)"',
                    (PLUGIN/"_meta.lua").read_text(encoding="utf-8")).group(1)

def chunk(kind, data):
    return struct.pack(">I", len(data))+kind+data+struct.pack(">I", zlib.crc32(kind+data)&0xffffffff)

def png(width, height, pixel):
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        raw.extend(pixel(x,y) for x in range(width))
    return (b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">IIBBBBB",width,height,8,0,0,0,0))
            +chunk(b"IDAT",zlib.compress(bytes(raw),9))+chunk(b"IEND",b""))

def gradient(x,y):
    if y<400:
        return x*255//799
    if y<800:
        return min(15,x*16//800)*17
    if y<1000:
        return 51
    return 0 if x%20==0 or y%20==0 else 255

def radial(x,y):
    if y>=1050:
        return 0 if (x//4+(y-1050)//4)%2 else 255
    radius=((x-400)**2+(y-525)**2)**0.5
    return max(0,min(255,int(radius*255/660)))

def blocks(x,y):
    levels=(0,51,52,128,200,255)
    return levels[min(5,y//200)]

def main():
    for name in ("README.md","LICENSE","THIRD_PARTY.md"):
        shutil.copyfile(ROOT/name,PLUGIN/name)
    DIST.mkdir(exist_ok=True)
    archive=DIST/f"graydither-{VERSION}.zip"
    with ZipFile(archive,"w",ZIP_DEFLATED) as z:
        for file in sorted(PLUGIN.rglob("*")):
            if file.is_file():
                z.write(file,"graydither.koplugin/"+file.relative_to(PLUGIN).as_posix())
    pages=[png(800,1200,gradient),png(800,1200,radial),png(800,1200,blocks)]
    book=DIST/"graydither-test.cbz"
    with ZipFile(book,"w",ZIP_DEFLATED) as z:
        for index,page in enumerate(pages,1):
            z.writestr(f"{index:02d}.png",page)
    (DIST/"sample-preview.png").write_bytes(pages[0])
    # Read the finished archives and compare installed files byte-for-byte.
    with ZipFile(archive) as z:
        expected={"graydither.koplugin/"+p.relative_to(PLUGIN).as_posix()
                  for p in PLUGIN.rglob("*") if p.is_file()}
        assert set(z.namelist())==expected
        assert z.testzip() is None
        for name in z.namelist():
            assert z.read(name)==(ROOT/name).read_bytes()
        assert "graydither.koplugin/main.lua" in expected
        assert "graydither.koplugin/LICENSE" in expected
        assert not any("tests/" in name or name.endswith(".py") for name in expected)
    with ZipFile(book) as z:
        assert z.namelist()==["01.png","02.png","03.png"]
        assert z.testzip() is None
        for name in z.namelist():
            data=z.read(name)
            assert data[:8]==b"\x89PNG\r\n\x1a\n"
            assert struct.unpack(">II",data[16:24])==(800,1200)
    manifest={"version":VERSION,"files":{}}
    for file in [archive,book,DIST/"sample-preview.png"]:
        manifest["files"][file.name]={"bytes":file.stat().st_size,
            "sha256":hashlib.sha256(file.read_bytes()).hexdigest()}
    (DIST/"manifest.json").write_text(json.dumps(manifest,indent=2),encoding="utf-8")
    print(json.dumps(manifest,indent=2))

if __name__=="__main__":
    main()
