# TODO

- Verify playback page flipping on real Sprinter/DSS builds. The renderer now
  writes dirty rectangles to a hidden video screen, loads the matching palette,
  waits one interrupt with `HALT`, flips via `RGMOD`, and then syncs the newly
  hidden page. Global palette is initialized for both hardware screens; local
  palettes are written to the hidden screen palette base before the flip.
  In 320x256 row access, screen B is addressed as row offset `#0140`, not as
  page `#55`; `PAGE1` must stay mapped to `#50` while drawing both screens.
- Investigate whether `HALT` is synchronized closely enough to Sprinter VSync
  on the target DSS versions; if not, switch to an explicit VSync wait before
  changing `RGMOD`.
- Verify accelerator-based canvas fills on real Sprinter/DSS builds. Initial
  canvas background fill and disposal method 2 background rectangles now use
  Sprinter accelerator block fills instead of CPU `LDIR`/per-pixel loops.
- Verify GIF disposal method 3 (`restore to previous`) on real-world samples.
  It now allocates a backup canvas only when such frames are present, saves the
  frame rectangle before decode, and restores it after the frame delay.
- Continue moving hot decode/render routines into cache. Current cache block
  contains LZW initialization, the main LZW decode loop, dictionary expand/add/pop routines,
  GIF sub-block stream byte reader, per-pixel canvas output and dirty-row video
  blit, frame canvas setup, dirty-rect marking, and disposal method 2
  accelerator fills. Low-level canvas page mapping used by the cache path now
  also has cache-local helpers. Next candidate is deeper LZW inner-loop
  optimization.
- Replace CPU `LDIR`/byte loops in dirty-rect blits and canvas fills with
  Sprinter accelerator commands. Prefer preparing rectangular blocks so that
  `LD A,A`/vertical copy can move screen columns or strips in a tight loop;
  split widths larger than one accelerator block where needed.
- Verify accelerator-based disposal-3 backup/restore rectangle copies on real
  Sprinter/DSS builds. The copy path now uses `LD L,L` accelerator segments
  between mapped canvas and backup pages.
- Rework the renderer so the hidden video screen can be used as the active GIF
  canvas instead of always decoding into a separate RAM canvas and then blitting
  it to VRAM. The target design is: keep the hidden screen coherent with the
  currently visible composited image, decode LZW output directly into the hidden
  screen, skip transparent pixels in place, apply disposal/fill operations on
  the hidden target, load the hidden screen palette, then flip. Keep the RAM
  canvas only as a fallback/backup if a disposal mode requires it.
- Revisit the experimental `CacheLzwReadCodeFast` bit-buffer reader only after
  adding diagnostics that compare emitted LZW code sequences against the stable
  bit-by-bit reader; the previous 24-bit version was faster but unstable.
- Continue reducing call overhead in `CacheLzwOutputCodeString`. The stack
  reset/push/pop helpers, common LZW code comparisons, and dictionary
  prefix/suffix table address helpers are now inlined in the cache path. The
  cache LZW string stack pointer now stays in `IX`, avoiding `LzwStackPtr`
  memory reads/writes in the hot expand/pop loop. For opaque frames,
  cache-local pixel output calls are patched to a no-transparency writer at
  frame start, skipping the per-pixel transparency-flag branch. Cache-local
  transparent/opaque pixel writers now keep the current pixel in `C` instead of
  round-tripping it through `CanvasOutputByte`.
- Avoid the post-flip sync blit when both video buffers can be kept coherent by
  a cheaper rectangle copy/fill strategy; this may remove one dirty-rect render
  pass per frame.
- Verify table-driven LZW powers and code masks on real-world samples; the
  cache path now uses lookup tables instead of recomputing powers or deriving
  masks at runtime.
