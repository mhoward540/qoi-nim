import os
import qoi_nim/conv

when isMainModule:

  if paramCount() < 2:
    echo "Usage (from nimble): nimble run -- <infile> <outfile>"
    echo "Usage: qoi_nim <infile> <outfile>"
    echo "Examples:"
    echo "  qoi_nim input.png output.qoi"
    echo "  nimble run -- input.qoi output.png"
    doAssert false

  convert(paramStr(1), paramStr(2))
