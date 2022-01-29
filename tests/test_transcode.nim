import unittest, os
import qoi_nim/transcode


test "full encode and decode functionality":
  ## Decode known-good QOI test files to bytes and compare to known-good bin files,
  ## then encode the known-good bin files to QOI and compare to the known-good QOI files

  let testData: seq[tuple[fname: string, desc: QOIDesc]] = @[
    ("dice", QOIDesc(width: 800, height: 600, channels: 4, colorspace: 1)),
    ("kodim10", QOIDesc(width: 512, height: 768, channels: 3, colorspace: 1)),
    ("kodim23", QOIDesc(width: 768, height: 512, channels: 3, colorspace: 1)),
    ("qoi_logo", QOIDesc(width: 448, height: 220, channels: 4, colorspace: 1)),
    ("testcard", QOIDesc(width: 256, height: 256, channels: 4, colorspace: 1)), 
    ("testcard_rgba", QOIDesc(width: 256, height: 256, channels: 4, colorspace: 1)),
    ("wikipedia_008", QOIDesc(width: 1152, height: 858, channels: 3, colorspace: 1))
  ]

  for (fname, desc) in testData:
    let qoiFile = open(joinPath("qoi_test_images", (fname & ".qoi")))
    let binFile = open(joinPath("qoi_test_images", (fname & ".bin")))

    let qoiSize = getFileSize(qoiFile)
    let binSize = getFileSize(binFile)
    var qoiBytes = newSeq[uint8](qoiSize)
    var binBytes = newSeq[uint8](binSize)

    discard readBytes(qoiFile, qoiBytes, 0, qoiSize)
    close(qoiFile)

    discard readBytes(binFile, binBytes, 0, binSize)
    close(binFile)

    let newQoi = encode(binBytes, desc)
    let (newBinBytes, newDesc) = decode(qoiBytes)

    check newQoi.data == qoiBytes
    check newBinBytes == binBytes
    # TODO check QOIDesc descriptions. Right now it's not possible since this binary format does not respect the colorspace


