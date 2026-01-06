from PIL import Image
import sys
from pathlib import Path

input_fname = Path(sys.argv[1])
output_fname = Path(sys.argv[2])

img = Image.open(input_fname)

numPalEntries = 256
qimg = img.resize((160,120)).quantize(numPalEntries)

out = open(output_fname, "w")

out.write(".data\n")
out.write(".linecont\n")
out.write(".export img_width, img_height, img_size, img_data, pal_last, pal_data\n")
out.write("img_width  = %d\n"%qimg.size[0])
out.write("img_height = %d\n"%qimg.size[1])
out.write("img_size   = %d\n"%(qimg.size[0]*qimg.size[1]))
out.write("img_data:")

imgdata = qimg.load()

col=0
for i in range(qimg.size[1]):
    for j in range(qimg.size[0]):
        if col%16 == 0:
            col = 0
            out.write("\n    .byte ")
        else:
            out.write(",")

        out.write("$%02x"%imgdata[j,i])
        col = col+1

out.write("\n")
out.write("pal_last = %d\n"%(numPalEntries-1))
out.write("pal_data:")
for rgb,idx in qimg.palette.colors.items():
    if idx % 16 == 0:
        out.write("\n   .word ")
    else:
        out.write(",")
    out.write("$%03x"%(((rgb[0]//16)<<8) + ((rgb[1]//16)<<4) + rgb[2]//16))

qimg.save(output_fname.parent / f"{input_fname.stem}_quant{input_fname.suffix}")
