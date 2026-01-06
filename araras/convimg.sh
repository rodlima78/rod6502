#!/bin/bash

# Ensure the script receives an input file
if [ $# -ne 1 ]; then
    echo "Usage: $0 <input_file>"
    exit 1
fi

input_file="$1"

# Check if the input file exists
if [ ! -f "$input_file" ]; then
    echo "Error: File not found: $input_file"
    exit 1
fi

# Constants: Width and Height of the quantized image
WIDTH=160
HEIGHT=120

# Extract the basename without extension
base_name="${input_file%.*}"
output_file="${base_name}.s"
quantized_image="${base_name}_quant.png"
temp_quantized="temp_quantized.txt"
temp_palette="temp_palette.txt"

# Trap to ensure temporary files are deleted on exit
trap "rm -f \"$temp_quantized\" \"$temp_palette\"" EXIT

# Step 1: Resize and quantize the image using ImageMagick
convert "$input_file" -resize "${WIDTH}x${HEIGHT}!" -colors 256 -depth 8 -type palette \
    "$quantized_image"

# Step 2: Calculate total pixels (from constants)
total_pixels=$((WIDTH * HEIGHT))

# Step 3: Extract pixel indices as text (instead of raw binary)
convert "$quantized_image" -depth 8 -colors 256 txt:- | \
    grep -oP '(\d+,\d+,\d+):\s*(\d+)' | \
    cut -d ' ' -f2 | \
    tr '\n' '\0' > "$temp_quantized"

# Step 4: Extract the palette (unique colors in quantized image)
convert "$quantized_image" -unique-colors txt:- | grep -E "srgb\(" > "$temp_palette"
palette_size=$(wc -l < "$temp_palette")

# Step 5: Write the header to the output assembly file
cat <<EOF >"$output_file"
.data
.linecont
.export img_width, img_height, img_size, img_data, pal_last, pal_data
img_width  = $WIDTH
img_height = $HEIGHT
img_size   = $total_pixels
img_data:
EOF

# Step 6: Write pixel data in `.byte` format, multiple pixels per line
# Use tr to ensure pixels are space-separated, and then xargs -0 to handle special characters safely
cat "$temp_quantized" | xargs -0 -n 1 | paste -d, -s | sed 's/^/    .byte /' >> "$output_file"

# Step 7: Write the palette to the output file
echo -e "\npal_last = $((palette_size - 1))\npal_data:" >>"$output_file"

# Convert the RGB palette entries to 16-bit words in little-endian
awk -F'[(),]' '
    /srgb/ {
        r = int($2 / 8); g = int($3 / 8); b = int($4 / 8);
        color16 = int(b * 1024 + g * 32 + r); # Simulate (b << 10) | (g << 5) | r
        printf "    .word $%03x\n", color16
    }
' "$temp_palette" >>"$output_file"

echo "Quantized image saved as: $quantized_image"
echo "Assembly file generated: $output_file"

