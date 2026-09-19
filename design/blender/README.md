# EquipSeva headquarters source

`equipseva-headquarters.blend` is the editable Blender scene. All campus meshes,
offices, furniture, robots and release gates were created in Blender by
`scripts/build_hq_scene.py`. Robot animations are illustrative, never telemetry.
The user-supplied SVG is unchanged in `website/progress-assets/equipsevalogo.svg`.
Its SHA-256 is `b11f2da3cb67ab6599f83f80074a1aaaae7129cc7ebd34de03e673e6aa23861f`.
`equipsevalogo.png` is its exact 1024px rasterization for the embedded GLB texture.

## Rebuild

Use Blender 4.5.9 LTS:

```powershell
& 'C:/Users/lokes/Documents/Codex/2026-09-07/im/tools/blender/blender-4.5.9-windows-x64/blender.exe' -b --python scripts/build_hq_scene.py
```

This writes the editable blend and PNG poster here, and the GLB + scene manifest
to `website/progress-assets/`. The saved scene packs its logo texture. The script
prefers CUDA when available and otherwise renders on CPU. The original render
used Cycles, 24 samples, denoising, 1500x1200. Convert the PNG poster to WebP with
Sharp at quality 85; the WebP is the public static fallback.

Blender was downloaded from the official Blender 4.5 release directory. ZIP
SHA-256 verified against its published checksum before execution:
`41da973b9bf95bb312cbeff4d1982feb13259b43c821686b9bafea4dfe5477cf`.
Portable tools stay outside the repository; no system installation was needed.

## Browser dependency

Three.js 0.180.0 came from the official npm registry tarball. Its SHA-512 integrity
was checked against registry metadata:
`sha512-o+qycAMZrh+TsE01GqWUxUIKR1AL0S8pq7zDkYOQw8GqfX8b8VoCKYUoHbhiX5j+7hr8XsuHDVU6+gkQJQKg9w==`.
Only the renderer core/module, GLTFLoader, OrbitControls, BufferGeometryUtils
and MIT license are vendored. Imports are rewritten to relative local paths.
The page makes no runtime CDN requests.

## Delivery

The public packager has a 19-file allowlist. Editable `.blend`, source PNGs,
Python, private handoffs and configs are excluded. Runtime GLB is approximately
5.2 MB. The static WebP fallback is approximately 41 KB. The logo in the GLB is
embedded; no external texture URL is required.

The webpage summarizes evidence. It cannot enforce GitHub branch protection or
verify the authenticity of manually authored review references. Its Android
release indicator requires matching scope/tree, provenance, all mandatory
checks, no blockers, separate QA/critic labels, overall and four critical scores
at least 9.5. A separate remote-main observation establishes recorded integration.
Signed-release verification remains separate.
