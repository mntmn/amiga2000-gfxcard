#!/bin/bash
ffmpeg -vcodec png -i $1 -vcodec rawvideo -f rawvideo -pix_fmt rgb565be $2
