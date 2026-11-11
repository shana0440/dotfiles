# Wallpapers

All wallpaper dependencies are declared in `wallpaper.nix`: ImageMagick, Python,
NumPy, Pillow, OpenCV, ONNX Runtime GPU, CUDA/cuDNN, the pinned BiRefNet model,
Quickshell IPC, and Qt shader compilation tools. No pip environment or runtime
model download is required. Initial installation downloads large CUDA libraries.

## Picker

Put JPG/JPEG, PNG, or WebP images in `~/Pictures/Wallpapers` (capital W).
Subdirectories are not scanned. The directory is not populated automatically.

- **Super + Shift + W**: toggle the picker on the focused monitor.
- **Left / Right**, mouse wheel, or click a card: select a wallpaper.
- **Enter** or double-click a card: apply to all monitors.
- **Escape** or click outside: cancel without changing the wallpaper.

Cards have parallelogram frames with clipped, upright artwork. Opening refreshes
thumbnails asynchronously and centers the current wallpaper before fading in,
without scrolling from the first image. Invalid images are skipped with a warning;
application errors keep/reopen the picker with an error. Theme colours are unchanged.

## Outline transitions

Opening the picker starts asynchronous GPU preprocessing. For a prepared image with
a sufficiently clear foreground subject, the change takes approximately 2 seconds:

1. Two strokes trace its silhouette from the top in opposite directions.
2. Its original colours fill inward from the outline.
3. The remaining wallpaper spreads outward from the subject.

The temporary Quickshell surface is above awww and below application windows. Once
it covers the old wallpaper, it switches awww underneath with `--transition-type
none`. It ends on exactly the new image, then disappears. Each screen has its own
old image and centred-cover crop, including portrait and fractional-scale outputs.
The picker fades out before the drawing begins.

A cold cache, unsuitable mask, first wallpaper over a solid colour, missing shell,
GPU initialization failure, or failed/timed-out renderer uses a normal fade instead.
Switching never waits for model inference. Rapid `wallpaper-set` calls serialize
complete transitions rather than changing awww underneath an existing animation.

### GPU requirements

GPU preprocessing currently targets **x86_64 Linux with NVIDIA CUDA**, verified on
an RTX 3070. Unsupported systems retain normal wallpaper switching. CPU inference
is deliberately disabled; image/map processing itself uses NumPy/OpenCV on the CPU.
ONNX Runtime may use CPU shape/bookkeeping nodes, but the diagnostic rejects CPU
convolutions, matrix multiplication, and GridSample.

The stock 1024px ONNX export exceeded available VRAM on the busy 8GB desktop GPU.
We instead pin the MIT-licensed dynamic BiRefNet_lite export, fix its input to 512px,
and convert it to FP16 during the Nix build. Its CPU-only native DeformConv nodes
are rewritten into CUDA-supported GridSample plus convolution. Sampling coordinates
stay FP32 to avoid positional rounding; convolution weights/activations use FP16.
Numerical tests compare the rewrite against an independent NumPy reference.

The pinned CUDA wheel matches the pinned nixpkgs Python 3.13 runtime. Update the
wheel/tag/hash together if changing Python. CUDA initialization must succeed;
ONNX Runtime's automatic Python fallback is disabled before any inference runs.

### Cache

- Thumbnails: `${XDG_CACHE_HOME:-~/.cache}/wallpaper/thumbnails`.
- Outline maps and metadata: `${XDG_CACHE_HOME:-~/.cache}/wallpaper/outlines`.
- `WALLPAPER_DIR` overrides the library/preprocessing source directory.

Thumbnail generation is bounded to four decoders and uses atomic writes and a
refresh lock. Removed/replaced thumbnails are pruned. Outline maps are keyed by
canonical source path, modification time, size, and pipeline/model version. A
warm-up lock prevents duplicate workers for a cache; per-image locks prevent
partial results. Invalid masks are cached; GPU errors are not. No source image is
modified. Increment `VERSION` in `outline.py` when changing model/map semantics.

## Commands

```sh
wallpaper-set '/path/to/my wallpaper.png'
wallpaper-library                      # JSON catalog; refresh thumbnails
wallpaper-outline warm                 # prepare the configured folder on GPU
wallpaper-outline prepare '/path/image.png'
wallpaper-outline cached '/path/image.png' # cache lookup only; never infer
wallpaper-outline doctor               # run/profile inference; verify CUDA kernels
wallpaper-check -v                      # library/switching regression tests
wallpaper-outline-check -v              # map/cache and CUDA conversion tests
quickshell --path ~/.config/quickshell ipc call wallpaper toggle
quickshell --path ~/.config/quickshell ipc call wallpaper state
```

`wallpaper-set` remains the switching entry point. For a prepared transition it
prints `transition-ready` before starting, allowing the picker to close; successful
exit still means the complete awww handoff finished. `WALLPAPER_SHELL` overrides the
Quickshell configuration path for isolated tests. `WALLPAPER_SHADER` overrides the
compiled shader path for renderer diagnostics.

## Verification

- `wallpaper-check`: filtering/sorting, cache reuse/invalidation/cleanup, special
  filenames, daemon errors, ready/done handshakes, renderer abort, and fade fallback.
- `wallpaper-outline-check`: mask validation, map encoding, cached results,
  invalidation, GPU failure handling, and numerical CUDA operator validation.
- `wallpaper-outline doctor`: verified 102 convolutions on CUDA; no CPU Conv,
  MatMul, Gemm, or GridSample. Hiding CUDA devices correctly prevents inference.
- Private agent workspace: nested Sway on X11 with separate runtime/cache/awww,
  including single-output and landscape/portrait dual-output tests (scale 1.5),
  picker-to-renderer handoff, cold cache, missing shell/assets, and concurrent CLI
  requests. Private shader rendering uses software OpenGL; actual model inference
  is independently verified on the NVIDIA GPU. Host wallpapers were not changed
  by the visual tests.

Recordings (outside the repository):

- `~/Videos/agent-recordings/wallpaper-outline.mp4`
- `~/Videos/agent-recordings/wallpaper-outline-dual-output.mp4`

## Model provenance

- Model authors: [ZhengPeng7/BiRefNet](https://github.com/ZhengPeng7/BiRefNet), MIT.
- Dynamic export: [senty-au/BiRefNet_lite-ONNX-dynamic](https://huggingface.co/senty-au/BiRefNet_lite-ONNX-dynamic),
  pinned to revision `173d635935b93839608b9b9039da8d1d212471e9` and SHA-256 in Nix.
- Model conversion and shader are built from the sources in this directory.
- See `BiRefNet-LICENSE`, also installed under `~/.local/share/wallpaper/`.
- Design reference: [diegoMalagrida/pocket-dots](https://github.com/diegoMalagrida/pocket-dots).
  This implementation does not copy its GPL shader or preprocessing source.
