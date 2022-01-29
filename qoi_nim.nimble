# Package

version       = "0.1.0"
author        = "Matt Howard"
description   = "Pure Nim encoder/decoder for Quite OK Image format"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["qoi_nim"]


# Dependencies

requires "nim >= 1.6.2"

# just for conv.nim
requires "pixie >= 3.1.2"
requires "chroma >= 0.2.5"