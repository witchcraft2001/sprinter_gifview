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
  playback mode, cleared before use, and released on exit. The -i option exits
  after metadata output. LZW decoder and renderer are under development.
