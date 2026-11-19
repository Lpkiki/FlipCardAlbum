#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 recording.mp4 docs/media/demo.gif" >&2
  exit 2
fi

input=$1
output=$2
mkdir -p "$(dirname "$output")"
ffmpeg -hide_banner -loglevel warning -y -i "$input" \
  -filter_complex '[0:v]fps=20,scale=480:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a' \
  -loop 0 "$output"
