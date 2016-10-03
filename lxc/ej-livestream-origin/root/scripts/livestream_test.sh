#!/bin/bash

CHANNEL="test"
if [ -n "$1" ]
then
	CHANNEL="$1"
fi

PATTERN="0"
if [ -n "$2" ]
then
	PATTERN="$2"
fi

gst-launch-1.0 -e \
videotestsrc pattern=$PATTERN ! queue ! \
'video/x-raw,width=320,height=180,framerate=25/1' ! videoconvert ! \
x264enc bitrate=384 key-int-max=45 speed-preset=superfast threads=1 ! \
'video/x-h264,profile=constrained-baseline,control-rate=variable' ! \
queue ! flvmux name=mux \
audiotestsrc volume=0.1 ! queue ! \
audioresample ! 'audio/x-raw,rate=48000,channels=2' ! audioconvert ! \
voaacenc bitrate=32000 ! \
queue ! mux. \
mux. ! rtmpsink location="rtmp://127.0.0.1/livestream/$CHANNEL live=1"
