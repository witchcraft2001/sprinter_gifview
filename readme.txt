GIFVIEW.EXE

Animated GIF viewer for Sprinter DSS.

Author:
  Dmitry Mikhalchenkov, Sprinter Team

Usage:
  GIFVIEW.EXE [options] <filename.gif> [options]

Options:
  -center  Draw the GIF without scaling, centered on a 320x256 screen.
  -i       Print GIF information and exit without graphics mode.
  -once    Play the animation once and exit.
  -fast    Ignore GIF frame delays for decoder/render profiling.

Current build status:
  Command line parsing, packaging, test image generation, DSS file open,
  size validation, page allocation, 16 KB page loading, GIF header parsing and
  GIF block metadata scanning are present. A frame index for up to 256 frames is
  prepared for the decoder. The global GIF palette is converted from RGB8 to
  Sprinter RGB6 format. Canvas and LZW workspace memory blocks are allocated for
  playback mode, cleared before use, and released on exit. Playback mode also
  initializes 320x256x256 video, loads the prepared palette, clears screen
  buffers, and restores the previous mode on exit. A frame image-data stream
  reader and LZW bit/code reader are prepared for the decoder. LZW workspace is
  mapped with prefix/suffix/stack areas for dictionary decoding. A canvas output
  writer maps the canvas memory block and writes decoded pixels across pages.
  The first frame is decoded into the canvas buffer and copied to video page A.
  Playback waits for a key before restoring the previous video mode. The -i
  option exits after metadata output. Animation playback is under development.
