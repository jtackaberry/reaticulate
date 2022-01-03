#!/bin/bash
./download.sh
outfile="../../img/icons.png"
shopt -s nullglob
row=0
for density in 1x 1.5x 2x; do
    for sz in med lg huge; do
        files="$(echo $sz-*@$density.png)"
        if [ -n "$files" ]; then
            convert +append $sz-*@$density.png row$row.png
            echo "Row $row: $sz $density"
            row=$(($row+1))
        fi
    done
done

convert -background none -append row*.png "$outfile"
rm -f row*.png
echo "Wrote $outfile"
pngcrush -ow "$outfile"
