# Store art

Everything the Creator Hub needs, already at the right pixel size.

| File | Size | Where it goes |
|---|---|---|
| `icon-512.png` | 512 x 512 | Settings -> Basic Info -> experience icon |
| `icon-halloween-512.png` | 512 x 512 | swap in for the Halloween event, swap back after Nov 4 |
| `thumb1-secret-slime.png` | 1920 x 1080 | Thumbnails, position 1 |
| `thumb2-protect-base.png` | 1920 x 1080 | Thumbnails, position 2 |
| `thumb3-collection.png` | 1920 x 1080 | Thumbnails, position 3 |

Thumbnail order matters: position 1 is the image most players ever see, so the
secret-slime pull goes first.

## Where these came from

Generated with Nano Banana Pro (Gemini 3 Pro image), then processed to size.
The raw generations live in `raw/`, which is gitignored because they are 1024px
previews superseded by the files above.

The icons were downscaled 1024 -> 512, so they are genuinely sharp. The three
thumbnails were upscaled from 1024 x 572 with a two-step Lanczos resize plus
unsharp mask; they hold up at tile size but are not as crisp as a native 1920px
render would be. If a future generation comes out at 2K, redo them with:

```python
from PIL import Image, ImageFilter
src = Image.open("raw/<file>.jpg").convert("RGB")
w, h = src.size
mid = src.resize((round(w * 1.4), round(h * 1.4)), Image.LANCZOS)
mid = mid.filter(ImageFilter.UnsharpMask(radius=1.2, percent=60, threshold=3))
scale = 1080 / mid.size[1]
nw = round(mid.size[0] * scale)
big = mid.resize((nw, 1080), Image.LANCZOS)
big = big.filter(ImageFilter.UnsharpMask(radius=1.8, percent=80, threshold=3))
left = (nw - 1920) // 2
big.crop((left, 0, left + 1920, 1080)).save("<out>.png", "PNG", optimize=True)
```

## Known nits

- `thumb3-collection`: the six rarity nameplates under the slimes are blank.
  Reads fine as design; regenerate asking for COMMON / UNCOMMON / RARE / EPIC /
  LEGENDARY / MYTHIC on the bars if you want them labelled.
- `icon-halloween-512`: the word SLIME sits close to the bottom edge, and Roblox
  masks icons with rounded corners in some surfaces. Watch for clipped letter
  bottoms.

## Still missing

Pass and product icons. Each game pass and developer product needs its own
512 x 512 image; the emoji in `src/shared/Config/Monetization.luau` is the
intended motif for each one.
