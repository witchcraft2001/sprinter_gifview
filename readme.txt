GIFVIEW.EXE

Animated GIF viewer for Sprinter DSS.

Usage:
  GIFVIEW.EXE <filename.gif> [-center] [-i] [-once] [-fast]

Options:
  -center  Draw the GIF without scaling, centered on a 320x256 screen.
  -i       Print GIF information and exit without graphics mode.
  -once    Play the animation once and exit.
  -fast    Ignore GIF frame delays for decoder/render profiling.

Current build status:
  Command line parsing, packaging, test image generation, DSS file open,
  size validation, page allocation and 16 KB page loading are present.
  GIF parser, LZW decoder and renderer are under development.
