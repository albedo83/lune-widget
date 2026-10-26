# MoonRender

Pre-renders the moon frames shown by the widget (`Shared/Moon.xcassets`, one frame every 5° of elongation).

Each frame is a sphere seen from Earth (sub-Earth point, lunar north up, no libration), textured with NASA's
colour map and lit for the phase:

- albedo from `nasa/lroc_color_2k.jpg` (mip-mapped, slightly desaturated);
- relief from `nasa/ldem_4_uint.tif`: bump normals plus cast shadows along the terminator (relief ×3);
- Lunar-Lambert reflectance `L·2μ0/(μ0+μ) + (1−L)·μ0`, L = 0.8, so the full moon stays flat to the limb;
- faint earthshine on the night side; 2× supersampling; sRGB PNG with a transparent background.

## Regenerate

```sh
cd Tools/MoonRender
swift test
swift run -c release moonrender ../../Shared/Moon.xcassets   # options: --size 256 --step 5
```

The widget extension ships the catalog; the app loads it from the embedded extension (`MoonFrame.bundle`).

## Credit

Moon maps: NASA's Scientific Visualization Studio, "CGI Moon Kit" (https://svs.gsfc.nasa.gov/4720).
The maps in `nasa/` and the frames rendered from them are not covered by the MIT license (see `NOTICE`);
credit "NASA's Scientific Visualization Studio" when reusing them.
