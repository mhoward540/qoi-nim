const QOI_HEADER_SIZE = 14;
const QOI_HEADER_MAGIC = 0x716f6966'u32;

const QOI_PIXELS_MAX: uint32 = 400000000;

const QOI_END_MARKER: seq[uint8] = @[0'u8, 0, 0, 0, 0, 0, 0, 1];
const QOI_END_MARKER_SIZE = len(QOI_END_MARKER);    

const QOI_OP_RUN   = 0xc0'u8;
const QOI_OP_INDEX = 0x00'u8;
const QOI_OP_DIFF  = 0x40'u8;
const QOI_OP_LUMA  = 0x80'u8;
const QOI_OP_RGB   = 0xfe'u8;
const QOI_OP_RGBA  = 0xff'u8;

const QOI_MASK_2 = 0xc0'u8;

type Color = tuple
  r: uint8
  g: uint8
  b: uint8
  a: uint8

type QOIDesc* = object of RootObj
  width*: uint32
  height*: uint32
  channels*: uint8
  colorspace*: uint8

type QOIImage* = object of QOIDesc
  data*: seq[uint8]


func u32tou8seq(num: uint32): seq[uint8] =
  result = newSeq[uint8](4)
  result[0] = ((num and 0xff000000'u64) shr 24).uint8
  result[1] = ((num and 0x00ff0000'u64) shr 16).uint8
  result[2] = ((num and 0x0000ff00'u64) shr 8).uint8
  result[3] = ((num and 0x000000ff'u64) shr 0).uint8

func u8seqtou32(nums: openArray[uint8]): uint32 =
  result = (
    (nums[0].uint32 shl 24) or (nums[1].uint32 shl 16) or
    (nums[2].uint32 shl 8) or (nums[3].uint32)
  )


func hashColor(c: Color): uint8 =
  result = ((c.r * 3) + (c.g * 5) + (c.b * 7) + (c.a * 11)) mod 64


func isValidDesc(desc: QOIDesc): bool =
  result = (
    desc.width > 0 and desc.height > 0 and
    (desc.channels == 3 or desc.channels == 4) and
    (desc.colorspace == 0 or desc.colorspace == 1) and # TODO make enum or use constants
    (desc.height < (QOI_PIXELS_MAX div desc.width))
  )


proc encode*(data: openArray[byte], desc: QOIDesc): QOIImage {.raises: [IOError].} =
  ## Converts a sequence of bytes `data` in RGB or RGBA format to QOIImage given proper dimensions in `desc`

  if not isValidDesc(desc) or len(data) < QOI_HEADER_SIZE + len(QOI_END_MARKER):
    raise newException(IOError, "The provided data cannot be encoded into a QOI image")

  result.width = desc.width
  result.height = desc.height
  result.channels = desc.channels

  let maxSize = desc.width * desc.height * (desc.channels + 1) +
      QOI_HEADER_SIZE + QOI_END_MARKER_SIZE;

  let lastPixel = len(data) - desc.channels.int

  var outBytes: seq[uint8] = (
    u32tou8seq(QOI_HEADER_MAGIC) & u32tou8seq(desc.width) &
    u32tou8seq(desc.height) & @[desc.channels, 0'u8] # TODO remove hardcoded colorspace
  )
  var index = len(outBytes)
  outBytes = outBytes & newSeq[uint8](maxSize.int - index)


  var run = 0'u8
  var prevPixel: Color = (r: 0'u8, g: 0'u8, b: 0'u8, a: 255'u8)
  var currPixel: Color

  var seenPixels: seq[Color] = newSeq[Color](64)

  for i in countup(0, lastPixel, desc.channels):
    currPixel = (
      r: data[i + 0],
      g: data[i + 1],
      b: data[i + 2],
      a: (if desc.channels == 4: data[i + 3] else: prevPixel.a)
    )

    if prevPixel == currPixel:
      inc run
      if run == 62 or i == lastPixel:
        outBytes[index] = QOI_OP_RUN or (run - 1)
        inc index
        run = 0
    else:
      if run > 0:
        outBytes[index] = QOI_OP_RUN or (run - 1)
        inc index
        run = 0

      let hash = hashColor(currPixel)

      if currPixel == seenPixels[hash]:
        outBytes[index] = QOI_OP_INDEX or hash
        inc index
      else:
        seenPixels[hash] = currPixel
        if currPixel.a == prevPixel.a:
          # Push pragmas instead of compiling without bounds checks
          let uvr = currPixel.r - prevPixel.r
          let uvg = currPixel.g - prevPixel.g
          let uvb = currPixel.b - prevPixel.b

          # TODO optimize conversions to i8 and i16
          let vr = (if uvr > 127: -128'i8 + (uvr - 128).int8 else: uvr.int8)
          let vg = (if uvg > 127: -128'i8 + (uvg - 128).int8 else: uvg.int8)
          let vb = (if uvb > 127: -128'i8 + (uvb - 128).int8 else: uvb.int8)

          let dr_dg = vr.int16 - vg.int16
          let db_dg = vb.int16 - vg.int16

          # TODO would absvalue or something be faster than mult by -1 ?
          let u_dr_dg = (if dr_dg < 0: (255'u8 - (-1 * dr_dg).uint8) + 1'u8 else: dr_dg.uint8)
          let u_db_dg = (if db_dg < 0: (255'u8 - (-1 * db_dg).uint8) + 1'u8 else: db_dg.uint8)

          if (
            (-2 <= vr and vr <= 1) and
            (-2 <= vg and vg <= 1) and
            (-2 <= vb and vb <= 1)
          ):
            outBytes[index] =
              QOI_OP_DIFF or ((uvr + 2) shl 4) or ((uvg + 2) shl 2) or ((uvb + 2) shl 0)

            inc index
          elif (
            (-32 <= vg and vg <= 31) and
            (-8 <= dr_dg and dr_dg <= 7) and
            (-8 <= db_dg and db_dg <= 7)
          ):
            outBytes[index + 0] = QOI_OP_LUMA or (uvg + 32)
            outBytes[index + 1] = ( (u_dr_dg + 8) shl 4) or (u_db_dg + 8)
            index += 2
          else:
            outBytes[index + 0] = QOI_OP_RGB
            outBytes[index + 1] = currPixel.r
            outBytes[index + 2] = currPixel.g
            outBytes[index + 3] = currPixel.b
            index += 4
        else:
          outBytes[index + 0] = QOI_OP_RGBA
          outBytes[index + 1] = currPixel.r
          outBytes[index + 2] = currPixel.g
          outBytes[index + 3] = currPixel.b
          outBytes[index + 4] = currPixel.a
          index += 5

    prevPixel = currPixel

  for b in QOI_END_MARKER:
    outBytes[index] = b
    inc index

  result.data = outBytes[0..index-1]


proc decode*(data: seq[uint8]): (seq[uint8], QOIDesc) {.raises: [IOError].} =
  if len(data) < QOI_HEADER_SIZE + len(QOI_END_MARKER):
    raise newException(IOError, "The provided data is not large enough to be a valid QOI image")

  let headerMagic = u8seqtou32(data[0..3])
  let desc = QOIDesc(
    width: u8seqtou32(data[4..7]),
    height: u8seqtou32(data[8..12]),
    channels: data[12],
    colorspace: data[13]
  )

  var index = QOI_HEADER_SIZE

  if headerMagic != QOI_HEADER_MAGIC or not isValidDesc(desc):
    raise newException(IOError, "The provided data is not a valid QOI image")

  var run: uint8 = 0;

  let numPixels = desc.width * desc.height * desc.channels;
  let colorDataBoundary = len(data) - len(QOI_END_MARKER)

  var currPixel: Color = (r: 0'u8, g: 0'u8, b: 0'u8, a: 255'u8)

  var seenPixels = newSeq[Color](64)

  var resultData = newSeq[uint8](numPixels)

  var b1: uint8

  for pixelOffset in countup[uint32](0, numPixels - desc.channels,
      desc.channels):
    if run > 0:
      dec run
    elif index < colorDataBoundary:
      b1 = data[index]
      inc index

      if b1 == QOI_OP_RGB:
        currPixel = (
          r: data[index + 0],
          g: data[index + 1],
          b: data[index + 2],
          a: currPixel.a
        )
        index += 3

      elif b1 == QOI_OP_RGBA:
        currPixel = (
          r: data[index + 0],
          g: data[index + 1],
          b: data[index + 2],
          a: data[index + 3],
        )
        index += 4

      elif (b1 and QOI_MASK_2) == QOI_OP_INDEX:
        currPixel = seenPixels[b1]

      elif (b1 and QOI_MASK_2) == QOI_OP_DIFF:
        let tempR = (b1 shr 4) and 0x03'u8
        let tempG = (b1 shr 2) and 0x03'u8
        let tempB = b1 and 0x03'u8

        # Simulate wraparound with arithmetic, instead of casting to unsigned int and intentionally underflowing
        # removing casts allows us to (eventually) target JS backend
        let newR = (if tempR.int8 - 2 < 0: 254'u8 + tempR else: tempR - 2)
        let newG = (if tempG.int8 - 2 < 0: 254'u8 + tempG else: tempG - 2)
        let newB = (if tempB.int8 - 2 < 0: 254'u8 + tempB else: tempB - 2)

        currPixel = (
          r: currPixel.r + newR,
          g: currPixel.g + newG,
          b: currPixel.b + newB,
          a: currPixel.a
        )

      elif (b1 and QOI_MASK_2) == QOI_OP_LUMA:
        let b2 = data[index]
        inc index

        let vg = (b1 and 0x3f'u8) - 32
        currPixel = (
          r: currPixel.r + (vg - 8 + ((b2 shr 4) and 0x0f'u8)),
          g: currPixel.g + vg,
          b: currPixel.b + (vg - 8 + (b2 and 0x0f'u8)),
          a: currPixel.a
        )

      elif (b1 and QOI_MASK_2) == QOI_OP_RUN:
        run = b1 and 0x3f'u8

      seenPixels[hashColor(currPixel)] = currPixel

    resultData[pixelOffset + 0] = currPixel.r
    resultData[pixelOffset + 1] = currPixel.g
    resultData[pixelOffset + 2] = currPixel.b
    if desc.channels == 4:
      resultData[pixelOffset + 3] = currPixel.a

  return (resultData, desc)


proc decode*(img: QOIImage): (seq[uint8], QOIDesc) {.raises: [IOError].} =
  return decode(img.data)
