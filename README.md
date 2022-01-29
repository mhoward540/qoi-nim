# qoi-nim
Nim port of the encoder/decoder for the [Quite OK Image format](https://github.com/phoboslab/qoi)

This repo can be used as a standalone command-line application as well as a library for use in Nim code

The standalone application can convert to and from QOI and PNG formats

You should have Nim and `nimble` installed to use this code

## Library Usage

`git clone` this repo, and navigate to the root directory. Then run `nimble install`, which will install the library for use with your system's Nim installation

The main functionality of the library can be imported with:
```
import qoi_nim/transcode
```

## Command-line Application Usage

You can simply `nimble run` the code from there
```
Usage (from nimble): nimble run -- <infile> <outfile>
Examples:
  nimble run -- input.qoi output.png
  nimble run -- input.png output.qoi
```

## Running tests

`nimble test`


## Notes

Test images in this repo were pulled from [qoiformat.org](https://qoiformat.org/)

The transcoder library is written in pure Nim and so should be more portable. The command-line application relies on [Pixie](https://github.com/treeform/pixie) which is not pure Nim


## TODOs (no particular order)

- Do better testing. Right now the repo is quite large due to all the image files included for testing purposes. Maybe we could use fewer images, or pull the images from the web before running the tests (could be flaky though)
- Use more idiomatic Nim. I think there are probably some nicer ways of doing what I did in Nim
- Get this working with the JS backend. JS versions already exist (see the [qoi repo page](https://github.com/phoboslab/qoi)), I just think it would be cool to get this working for the Nim repo as well
- Do some benchmarking to understand this code's performance
- Handling colorspaces properly in the command-line application
