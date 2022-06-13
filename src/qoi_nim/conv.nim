import strutils
import transcode
import pixie/fileformats/png
import chroma/colortypes


# copied from itertools
iterator chunked[T](s: openArray[T], size: Positive): seq[T] =
  var i: int
  while i + size < len(s):
    yield s[i ..< i+size]
    i += size
  yield s[i .. ^1]


proc convert*(fname_in: string, fname_out: string) =

  if fname_in.endsWith(".png") and fname_out.endsWith(".qoi"):
    let s = readFile(fname_in)
    let png = decodePng(s)
    let desc = QOIDesc(width: png.width.uint32, height: png.height.uint32, channels: png.channels.uint8, colorspace: 0'u8) # TODO colorspace

    var imgBytes = newSeq[uint8](png.width * png.height * png.channels)

    var i = 0
    for b in png.data:
      imgBytes[i + 0] = b.r
      imgBytes[i + 1] = b.g
      imgBytes[i + 2] = b.b

      if png.channels == 4:
        imgBytes[i + 3] = b.a
        inc i
      
      i += 3
    
    let qoiImg = encode(imgBytes, desc)

    let f = open(fname_out, mode = fmWrite)
    discard writeBytes(f, qoiImg.data, 0, len(qoiImg.data))
    close(f)

  elif fname_in.endsWith(".qoi") and fname_out.endsWith(".png"):
    let qoiFile = open(fname_in)
    let size = getFileSize(qoiFile)
    

    var qoiBytes = newSeq[uint8](size)
    discard readBytes(qoiFile, qoiBytes, 0, size)
    close(qoiFile)

    let (qoiImg, desc) = decode(qoiBytes)
    var png = Png()

    png.width = desc.width.int
    png.height = desc.height.int
    png.channels = desc.channels.int

    png.data = newSeq[ColorRGBA](len(qoiImg) div desc.channels.int)
    
    var i = 0
    for t in chunked(qoiImg, desc.channels):
      var color = ColorRGBA(
        r: t[0],
        g: t[1],
        b: t[2]
      )

      if desc.channels == 4:
        color.a = t[3]
      
      png.data[i] = color
      inc i
        
    
    let pngStr = encodePng(png)
    let f = open(fname_out, mode = fmWrite)
    write(f, pngStr)
    close(f)

  else:
    raise newException(ValueError, "Attempted invalid conversion. Please ensure you are converting between QOI and PNG formats")