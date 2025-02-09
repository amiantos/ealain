# Ealain for macOS

Ealain is a macOS screensaver that displays abstract art generated with Stable Diffusion using the [AI Horde](https://aihorde.net). Limitless generative art gracing your screen, forever.

## Examples

These are some examples of the kind of art you may see on your screen, but you will never see these specific images.

![Ealain generative art example images, showing abstract are in the bauhaus, de stijl art styles](/images/default-examples.jpg?raw=true)

## Download

- [Download Ealain v1.0 for macOS](https://amiantos.s3.amazonaws.com/ealain-1.0.zip)

## Feature Detail
### Custom Styles

Ealain uses [AI Horde Styles](https://haidra.net/styles-on-the-ai-horde/) to power its image generation, meaning you can create your own style and tell the screensaver to use it instead. To learn more, check out [STYLES.md](/STYLES.md). If you create a great style, feel free to submit it in a PR to the repo, or contact me in some way so we can collaborate.

### Monitor Orientation and Aspect Ratio

Ealain detects if you have your monitors in landscape or portrait orientation and will generate unique art for both orientations if needed. Ealain only generates images in 16:9 or 9:16, if your monitor is a unique aspect ratio, image will stretch to fill the full screen.

### Local Cache

Ealain caches up to ~100 images (for each monitor orientation) on your local filesystem. You can find these images under: `~/Library/Containers/com.apple.ScreenSaver.Engine.legacyScreenSaver/Data/Library/Application Support/Ealain`

## Authors

* Brad Root - [amiantos](https://github.com/amiantos)