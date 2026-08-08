#!/bin/bash

set -e

trap 'echo "Terminating timelapse..."; rm -rf "$BASE_PATH/eDP-1"; rm -rf "$BASE_PATH/HDMI-A-1"; rm -rf "$BASE_PATH/webcam"; exit 0' TERM HUP INT

MONITORS=$(xrandr --query | grep connected | awk '{print $1}')
START_TIME=$(date '+%Y-%m-%d')
BASE_PATH="$HOME/Videos/Timelapse/$START_TIME"

mkdir -p "$BASE_PATH"

for monitor in $MONITORS; do
  mkdir -p "$BASE_PATH/$monitor"
  if [ ! -f "$BASE_PATH/$monitor/.files.txt" ]; then
    echo "file 'temp-1.mp4'" >>"$BASE_PATH/$monitor/.files.txt"
    echo "file 'temp-2.mp4'" >>"$BASE_PATH/$monitor/.files.txt"
  fi
done

mkdir -p "$BASE_PATH/webcam"
if [ ! -f "$BASE_PATH/webcam/.files.txt" ]; then
  echo "file 'temp-1.mp4'" >>"$BASE_PATH/webcam/.files.txt"
  echo "file 'temp-2.mp4'" >>"$BASE_PATH/webcam/.files.txt"
fi

if [ ! -f "$BASE_PATH/.files.txt" ]; then
  echo "file 'temp-1.mp4'" >>"$BASE_PATH/.files.txt"
  echo "file 'temp-2.mp4'" >>"$BASE_PATH/.files.txt"
fi

while true; do
  timestamp=$(date +%s)

  for monitor in $MONITORS; do
    grim -o "$monitor" "$BASE_PATH/$monitor/$timestamp.png" 2>/dev/null

    if [ ! -f "$BASE_PATH/$monitor/$timestamp.png" ]; then
      ffmpeg -loglevel error -stats \
        -f lavfi -i color=black:size=1920x1080 \
        -frames:v 1 "$BASE_PATH/$monitor/$timestamp.png"
    fi
  done

  ffmpeg -loglevel error -stats \
    -f v4l2 -input_format mjpeg \
    -video_size 1280x720 -i /dev/video0 \
    -frames:v 1 -c:v copy \
    -f image2 -update 1 "$BASE_PATH/webcam/$timestamp.jpg"

  if [ ! -f "$BASE_PATH/webcam/$timestamp.jpg" ]; then
    ffmpeg -loglevel error -stats \
      -f lavfi -i color=black:size=1280x720 \
      -frames:v 1 "$BASE_PATH/webcam/$timestamp.jpg"
  fi

  frame_count=$(ls "$BASE_PATH"/webcam/*.jpg | wc -l)

  if ((frame_count % 60 == 0)); then
    for monitor in $MONITORS; do
      ffmpeg -loglevel error -stats \
        -y -framerate 60 -pattern_type glob \
        -i "$BASE_PATH/$monitor/*.png" -c:v libx264 -pix_fmt yuv420p "$BASE_PATH/$monitor/temp-2.mp4"

      rm "$BASE_PATH/$monitor"/*.png

      if [ ! -f "$BASE_PATH/$monitor.mp4" ]; then
        mv -f "$BASE_PATH/$monitor/temp-2.mp4" "$BASE_PATH/$monitor.mp4"
        continue
      fi

      mv -f "$BASE_PATH/$monitor.mp4" "$BASE_PATH/$monitor/temp-1.mp4"

      ffmpeg -loglevel error -stats \
        -f concat -safe 0 -i "$BASE_PATH/$monitor/.files.txt" \
        -c copy "$BASE_PATH/$monitor.mp4"
    done

    ffmpeg -loglevel error -stats \
      -y -framerate 60 -pattern_type glob -i "$BASE_PATH/webcam/*.jpg" \
      -c:v libx264 -pix_fmt yuv420p "$BASE_PATH/webcam/temp-2.mp4"

    rm "$BASE_PATH/webcam"/*.jpg

    if [ ! -f "$BASE_PATH/webcam.mp4" ]; then
      mv -f "$BASE_PATH/webcam/temp-2.mp4" "$BASE_PATH/webcam.mp4"
      continue
    fi

    mv -f "$BASE_PATH/webcam.mp4" "$BASE_PATH/webcam/temp-1.mp4"

    ffmpeg -loglevel error -stats \
      -f concat -safe 0 -i "$BASE_PATH/webcam/.files.txt" \
      -c copy "$BASE_PATH/webcam.mp4"

    if [ ! -f "$BASE_PATH/result.mp4" ]; then
      ffmpeg -loglevel error -stats -y \
        -i "$BASE_PATH/HDMI-A-1.mp4" \
        -i "$BASE_PATH/webcam.mp4" \
        -i "$BASE_PATH/eDP-1.mp4" -filter_complex "\
      [0:v]scale=1920:1080[bg]; \
      [1:v]scale=587:330[small1]; \
      [2:v]scale=587:330[small2]; \
      [bg][small1]overlay=0:main_h-overlay_h[tmp]; \
      [tmp][small2]overlay=main_w-overlay_w:main_h-overlay_h[outv]" \
        -map "[outv]" -map 0:a? \
        -c:v libx264 -crf 18 -preset veryfast \
        -c:a aac -shortest "$BASE_PATH/result.mp4"
      sleep 5
      continue
    fi

    ffmpeg -loglevel error -stats -y \
      -i "$BASE_PATH/HDMI-A-1/temp-2.mp4" \
      -i "$BASE_PATH/webcam/temp-2.mp4" \
      -i "$BASE_PATH/eDP-1/temp-2.mp4" -filter_complex "\
    [0:v]scale=1920:1080[bg]; \
    [1:v]scale=587:330[small1]; \
    [2:v]scale=587:330[small2]; \
    [bg][small1]overlay=0:main_h-overlay_h[tmp]; \
    [tmp][small2]overlay=main_w-overlay_w:main_h-overlay_h[outv]" \
      -map "[outv]" -map 0:a? -c:v libx264 -crf 18 -preset veryfast -c:a aac -shortest "$BASE_PATH/temp-2.mp4"

    mv -f "$BASE_PATH/result.mp4" "$BASE_PATH/temp-1.mp4"

    ffmpeg -loglevel error -stats \
      -f concat -safe 0 -i "$BASE_PATH/.files.txt" \
      -c copy "$BASE_PATH/result.mp4"

    for monitor in $MONITORS; do
      rm "$BASE_PATH/$monitor/temp-1.mp4"
      rm "$BASE_PATH/$monitor/temp-2.mp4"
    done
    rm "$BASE_PATH/webcam/temp-1.mp4"
    rm "$BASE_PATH/webcam/temp-2.mp4"
    rm "$BASE_PATH/temp-1.mp4"
    rm "$BASE_PATH/temp-2.mp4"
  fi

  sleep 5
done
