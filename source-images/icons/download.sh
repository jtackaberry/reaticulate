#!/bin/bash
densities=(1x 1.5x 2x)
declare -A resolutions
resolutions[med]="18 28 36"
resolutions[lg]="24 36 48"
resolutions[huge]="96 144 192"

cat icon-list | while read name color uuid sizes; do
    for size in $sizes; do
        n=0; for res in ${resolutions[$size]}; do
            fname="$size-$name@${densities[$n]}.png"
            if [ ! -e "$fname" ]; then
                url="https://materialdesignicons.com/api/download/$uuid/$color/1/FFFFFF/0/$res"
                echo $fname
                wget -q "$url" -O "$fname"
            fi
            n=$(($n+1))
        done
    done
done
