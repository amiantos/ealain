# Ealain for macOS

Ealain is a macOS screensaver that displays abstract art generated with Stable Diffusion using the [AI Horde](https://aihorde.net). Limitless generative art gracing your screen, forever.

## Examples

These are some examples of the kind of art you may see on your screen, but you will never see these specific images.

![Ealain generative art example images, showing abstract are in the bauhaus, de stijl art styles](/images/default-examples.jpg?raw=true)

## Download

- [Download Ealain v1.0 for macOS](https://amiantos.s3.amazonaws.com/ealain-1.0.zip)

## Features
### Always Changing Generative Art
Ealain uses the [AI Horde](https://aihorde.net) to generate the art, for free, using GPUs located all around the world. Older images are replaced by new art over time, so your screensaver should have something new every time it runs.

### Custom Styles

Ealain uses [AI Horde Styles](https://haidra.net/styles-on-the-ai-horde/) to power its image generation, meaning you can create your own style and tell the screensaver to use it instead. To learn more, check out [STYLES.md](/STYLES.md). If you create a great style, feel free to submit it in a PR to the repo, or contact me in some way so we can collaborate.

### Monitor Orientation and Aspect Ratio

Ealain detects if you have your monitors in landscape or portrait orientation and will generate unique art for both orientations if needed. Ealain only generates images in 16:9 or 9:16, if your monitor is a unique aspect ratio, image will stretch to fill the full screen.

### Local Cache

Ealain caches between 100-200 images on your local filesystem. You can find these images under: `~/Library/Containers/com.apple.ScreenSaver.Engine.legacyScreenSaver/Data/Library/Application Support/Ealain`

# Community
- Discuss Ealain on [the AI Horde Discord](https://discord.gg/Vc8fsQgW5E)

# Credits
- Ealain was built and is maintained by [Brad Root](https://github.com/amiantos)

# License
- The screensaver is licensed under the terms of the [Mozilla Public License 2.0](https://www.mozilla.org/en-US/MPL/2.0/)
