#!/bin/bash

find #SHARED#/livestream/hls/ -type f -name "*.ts" -cmin +5 -delete
find #SHARED#/livestream/hls/ -type f -name "*.m3u8" -cmin +5 -delete
