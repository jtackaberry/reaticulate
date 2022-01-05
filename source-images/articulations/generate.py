#!/usr/bin/env python3
import math
import re
import sys
import subprocess

import numpy as np
from PIL import Image, ImageOps

# 1x icons are 32x28 in dimension
ICON_ASPECT = 32/28

class IconGrid:
    def __init__(self, specfile):
        self.groups = self.read_spec(specfile)

    def read_spec(self, specfile):
        """
        Returns a dict (x, y) -> name where x,y are row/column indexes (not pixels).
        """
        # [ [images, {(x, y) -> name}, numrows], ...]
        # [name, [image, ...], {(x, y): iconname, ...}, numrows]
        groups = []
        for line in open(specfile).readlines():
            line = line.strip()
            if not line:
                continue
            if line.startswith('#<'):
                filenames = line[3:].strip().split()
                icons = {}
                x = y = 0
                images = [self.load_image(fname) for fname in filenames]
                if len(groups) > 0 and len(images) != len(groups[-1][0]):
                    print(f'ERROR: group {len(groups)+1} has inconsistent number of input files')
                    sys.exit(1)
                group = [images, icons, 1]
                groups.append(group)
            elif line.startswith('#|'):
                y += 1
                x = 0
                group[-1] += 1
            elif not line.startswith('#'):
                icons[(x, y)] = line
                x += 1
        return groups

    def load_image(self, fname):
        """
        Loads an image, and inverts all but the alpha channel, effectively converting
        black input icons to white.
        """
        img = Image.open(fname)
        buf = np.array(img)
        rgb = buf[:, :, :3]
        a = buf[:, :, 3]
        ivt = np.dstack((255 - rgb, a))
        newimg = Image.fromarray(ivt)
        m = re.search(r'(@[\d.]+x)', fname)
        newimg.suffix = m.group(1) if m else ''
        return newimg

    def generate(self, outname):
        # Total number of icons across all groups
        count = sum(len(group[1]) for group in self.groups)
        # First pass to create individual images for each DPI
        outputs = []
        for (images, icons, nrows) in self.groups:
            for img in images:
                icon_h = int(img.height / nrows)
                icon_w = int(icon_h * ICON_ASPECT)
                all_cols = math.ceil(math.sqrt(count))
                all_rows = math.ceil(count / all_cols)
                outimg = Image.new('RGBA', (all_cols * icon_w, all_rows * icon_h))
                outputs.append((outimg, icon_w, icon_h, all_cols))
            # We assume (i.e. require) all groups use the same icon resolutions
            break
        luarows = []
        nimg = 0
        for (images, icons, nrows) in self.groups:
            for (srccol, srcrow), name in icons.items():
                for nout, (srcimg, (dstimg, icon_w, icon_h, all_cols)) in enumerate(zip(images, outputs)):
                    dstcol = nimg % all_cols
                    dstrow = int(nimg / all_cols)
                    sx = srccol * icon_w
                    sy = srcrow * icon_h
                    dx = dstcol * icon_w
                    dy = dstrow * icon_h
                    dstimg.alpha_composite(srcimg, (dx, dy), (sx, sy, sx + icon_w, sy + icon_h))
                    if nout == 0:
                        if dstcol == 0:
                            luarows.append([])
                        luarows[-1].append(name)
                        # Useful for debugging: output individual icons as files
                        if True:
                            icon = Image.new('RGBA', (icon_w, icon_h))
                            icon.alpha_composite(srcimg, (0, 0), (sx, sy, sx + icon_w, sy + icon_h))
                            icon.save('individual/{}.png'.format(name))

                nimg += 1
        outw = max(outimg.width for outimg, *_ in outputs)
        outh = sum(outimg.height for outimg, *_ in outputs)
        pack = Image.new('RGBA', (outw, outh))
        y = 0
        for outimg, *_ in outputs:
            pack.alpha_composite(outimg, (0, y), (0, 0))
            y = y + outimg.height
        outfile = f'../../img/{outname}'
        pack.save(outfile)
        subprocess.run(['pngcrush', '-ow', outfile])

        with open('articons.lua', 'w') as luaout:
            luaout.write('articons.rows = {\n')
            for row in luarows:
                luaout.write('    {\n')
                for name in row:
                    luaout.write(f"        '{name}',\n")
                luaout.write('    },\n')
            luaout.write('}\n')

if __name__ == '__main__':
    grid = IconGrid('artnames.txt')
    grid.generate('articulations.png')
