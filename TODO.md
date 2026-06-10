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
  canvas background fill still uses Sprinter accelerator block fills, but
  disposal method 2 background rectangles are back on the conservative
  per-pixel canvas writer until the accelerator segment path is checked against
  transparent/disposal-heavy GIFs.
- Fix the accelerator-based disposal method 2 background fill before enabling
  it again. The regression is reproducible with `demo/batman-and-robin.gif`
  copied into the test image as `/DEMO/BATMAN.GIF`: the broken path produced
  short lower-frame artifacts and long horizontal strips on later frames, while
  the conservative per-pixel clear renders cleanly.
- Verify GIF disposal method 3 (`restore to previous`) on real-world samples.
  It now allocates a backup canvas only when such frames are present, saves the
  frame rectangle before decode, and restores it after the frame delay.
- Continue moving hot decode/render routines into cache. Current cache block
  contains LZW initialization, the main LZW decode loop, dictionary expand/add/pop routines,
  GIF sub-block stream byte reader, per-pixel canvas output and dirty-row video
  blit, frame canvas setup, dirty-rect marking, and disposal method 2
  background clears. Low-level canvas page mapping used by the cache path now
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
- Continue optimizing palette updates. Playback now tracks whether each
  hardware screen palette is global or local, skips unchanged global-palette
  reloads, and restores global palettes from `GlobalPaletteBuffer` only after
  a local color table has changed that screen. Local color table loads now use
  a direct `PORT_Y` plus `#43E0/#43E4` hardware loop and only take a slow path
  on rare GIF page crossings. The local loop now keeps color count, palette
  index, palette register base, and source pointer in registers instead of
  updating memory counters per color. Next candidate is using alternate
  registers in the rare page-crossing path or moving on to LZW/dirty-blit
  hot loops.
- Keep trimming duplicate non-cache render/decode code. The active playback
  path enters the cache window and calls `CacheDecodeCurrentFrameToCanvas`;
  old main-memory LZW/canvas/disposal/blit variants should be removed once no
  active call sites remain, leaving only shared helpers and error labels needed
  by cache code.
- Keep refining the GIF sub-block byte path in `CacheFrameStreamGetByte`: data
  bytes from an active sub-block read and advance inline instead of calling
  `CacheFrameStreamRawGetByte`; next candidate is reducing the remaining PAGE3
  map check when consecutive LZW byte fetches stay on the same GIF page.
- Use alternate register sets in hot loops where they can replace stack
  traffic. Candidate paths are LZW code reading, string expansion/output, GIF
  sub-block byte reading, accelerator copy/fill segments, and dirty-row blits;
  prefer `EXX`/`EX AF,AF'` to repeated `PUSH`/`POP` when the live register
  state is simple enough to reason about safely. Dirty-row wide copies and GIF
  stream page-cross byte preservation now use alternate `AF` instead of stack
  saves. `CacheFrameStreamRawGetByte` now treats `HL` as scratch, removing
  per-byte `PUSH`/`POP HL` traffic from the raw stream reader.
  `CacheLzwReadCode` uses `EXX` around stream-byte fetches instead of saving
  `HL/BC/DE` on the stack. Stream and canvas `PAGE3` mappers no longer use `B`
  as a temporary when checking the already-mapped page.
- Replace the current bit-by-bit `CacheLzwReadCode` with a verified LSB
  byte-buffer reader once diagnostics are in place. The target is to fetch
  whole bytes from the GIF stream, mask `LzwCodeSize` bits, and shift the
  buffer once per LZW code instead of looping once per decoded bit.
- Rework `CacheLzwOutputCodeString` to avoid `IX` in the hot stack pop/expand
  path. A normal `HL`/`DE` stack pointer should make stack byte reads/writes
  cheaper than `DEC IX` and `(IX + 0)` indexed addressing.
- Continue optimizing dirty-rect blits. The dirty-rect setup and row loop now
  live in cache alongside the row copy helper, so page mapping and source row
  stepping stay on the cache path. The wide-row accelerator path now keeps its
  second segment length in alternate `AF` instead of pushing it to the stack.
  Next candidates are reducing stack traffic in rare page-crossing byte-copy
  paths and using alternate registers in LZW code readers.
- Continue reducing call overhead in `CacheLzwOutputCodeString`. The stack
  reset/push/pop helpers, common LZW code comparisons, and dictionary
  prefix/suffix table address helpers are now inlined in the cache path. The
  cache LZW string stack pointer now stays in `IX`, avoiding `LzwStackPtr`
  memory reads/writes in the hot expand/pop loop. For opaque frames,
  cache-local pixel output calls are patched to a no-transparency writer at
  frame start, skipping the per-pixel transparency-flag branch. Cache-local
  transparent/opaque pixel writers now keep the current pixel in `C` instead of
  round-tripping it through `CanvasOutputByte`. `CacheCanvasAdvancePixel` now
  has a specialized `+1` pointer advance path, so per-pixel output no longer
  calls the generic `CacheCanvasAdvanceOutputPtrByDE` helper. Canvas page remap
  for decoded pixels is now done once per LZW output string and on rare
  page/row changes instead of inside every pixel writer call. Canvas completion
  checks in the cache decode loop are now inlined instead of calling a helper.
  LZW dictionary growth in the cache path now tracks `LzwNextCodeLimit`, so
  each dictionary add compares against a cached threshold instead of calling
  `CacheLzwPowerOfTwo`. Dictionary reset now derives that threshold directly
  from `LzwClearCode`, avoiding another table lookup on clear codes. Dictionary
  add now keeps the loaded `LzwNextCode` in `BC`, removing repeated memory
  reads when writing prefix/suffix entries. On code-size growth, the matched
  `LzwNextCodeLimit` already in `HL` is doubled directly instead of reloading
  the limit from memory. Cache bit reads now return the bit directly in `A`,
  avoiding the `LzwReadBitValue` memory round-trip used by the fallback path.
  Cache frame stream reads now avoid the `FrameStreamByte`
  memory round-trip as well, preserving bytes across pointer/page updates via
  registers/stack instead. The common raw stream read path keeps the byte in
  `B`; stack preservation is only used on the rare page-crossing path. Stream
  and canvas `PAGE3` output mappers inline page-table lookup and `OUT (PAGE3)`,
  avoiding the preserving helper on actual remaps. Stream next-page bounds now
  compare the new page index directly against `(PagesNeeded)` with a single
  carry check and jump straight to the stream page-map body without repeating
  the owner/page check. Pixel output page crossings now jump straight to the
  canvas page-map body without repeating the owner/page check. `CacheLzwReadCode`
  keeps `LzwCurrentByte` and `LzwBitsRemaining` in registers while assembling
  one code, so the common in-byte bit path no longer reloads and stores them for
  every bit. `CacheLzwReadBit` now saves `HL/BC/DE` only when a new byte must be
  fetched from the GIF sub-block stream, leaving the common in-byte bit path free
  of stack traffic. The stable bit reader has also been inlined into
  `CacheLzwReadCode`, removing one
  `CALL`/`RET` pair per decoded bit without changing the bit-by-bit algorithm.
  Active GIF sub-block data bytes read and advance inline in
  `CacheFrameStreamGetByte`, avoiding the raw-byte helper `CALL`/`RET` on the
  normal LZW byte path.
  Decoded bits now use the carry from `SRL (LzwCurrentByte)` directly instead
  of materializing a temporary `0/1` value in `C`. LZW string expansion now
  preserves the current code in `DE` around suffix lookup instead of using
  `PUSH HL`/`POP HL`.
- Avoid the post-flip sync blit when both video buffers can be kept coherent by
  a cheaper rectangle copy/fill strategy; this may remove one dirty-rect render
  pass per frame.
- Verify table-driven LZW powers and code masks on real-world samples; the
  cache path now uses lookup tables instead of recomputing powers or deriving
  masks at runtime.
