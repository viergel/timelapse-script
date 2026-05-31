#!/bin/bash

trap 'echo "Terminating timelapse..."; exit 0' TERM HUP INT

MONITORS=$(xrandr --query | grep connected | awk '{print $1}' | head -n 1)
START_TIME=$(date '+%Y-%m-%d')
BASE_PATH="$HOME/Videos/Timelapse/$START_TIME"

frame_count=0

mkdir -p "$BASE_PATH"

for monitor in $MONITORS; do
  mkdir -p "$BASE_PATH/$monitor"
  if [ ! -f "$BASE_PATH/$monitor/files.txt" ]; then
    echo "file 'temp-1.mp4'" >>"$BASE_PATH/$monitor/files.txt"
    echo "file 'temp-2.mp4'" >>"$BASE_PATH/$monitor/files.txt"
  fi
done

mkdir -p "$BASE_PATH/webcam"
if [ ! -f "$BASE_PATH/webcam/files.txt" ]; then
  echo "file 'temp-1.mp4'" >>"$BASE_PATH/webcam/files.txt"
  echo "file 'temp-2.mp4'" >>"$BASE_PATH/webcam/files.txt"
fi

if [ ! -f "$BASE_PATH/files.txt" ]; then
  echo "file 'temp-1.mp4'" >>"$BASE_PATH/files.txt"
  echo "file 'temp-2.mp4'" >>"$BASE_PATH/files.txt"
fi

while true; do
  last=$(pgrep -f basename "$0")
  last=$(printf '%s\n' "$last" | tail -n1)
  if [ -n "$last" ] && [ "$$" -ne "$last" ]; then
    exit 0
  fi

  ((frame_count++))

  timestamp=$(date +%s)

  for monitor in $MONITORS; do
    scrot "$BASE_PATH/$monitor/$timestamp.png"
  done

  ffmpeg -f v4l2 -input_format mjpeg -video_size 1280x720 -i /dev/video0 -frames:v 1 -c:v copy -f image2 -update 1 "$BASE_PATH/webcam/$timestamp.jpg"

  if [ ! -f "$BASE_PATH/webcam/$timestamp.jpg" ]; then
    ffmpeg -f lavfi -i color=black:size=1280x720 -frames:v 1 "$BASE_PATH/webcam/$timestamp.jpg"
  fi

  if ((frame_count % 60 == 0)); then
    for monitor in $MONITORS; do
      ffmpeg -y -framerate 60 -pattern_type glob -i "$BASE_PATH/$monitor/*.png" -c:v libx264 -pix_fmt yuv420p "$BASE_PATH/$monitor/temp-2.mp4"

      rm "$BASE_PATH/$monitor"/*.png

      if [ ! -f "$BASE_PATH/$monitor.mp4" ]; then
        mv -f "$BASE_PATH/$monitor/temp-2.mp4" "$BASE_PATH/$monitor.mp4"
        continue
      fi

      mv -f "$BASE_PATH/$monitor.mp4" "$BASE_PATH/$monitor/temp-1.mp4"

      ffmpeg -f concat -safe 0 -i "$BASE_PATH/$monitor/files.txt" -c copy "$BASE_PATH/$monitor.mp4"
    done

    ffmpeg -y -framerate 60 -pattern_type glob -i "$BASE_PATH/webcam/*.jpg" -c:v libx264 -pix_fmt yuv420p "$BASE_PATH/webcam/temp-2.mp4"

    rm "$BASE_PATH/webcam"/*.jpg

    if [ ! -f "$BASE_PATH/webcam.mp4" ]; then
      mv -f "$BASE_PATH/webcam/temp-2.mp4" "$BASE_PATH/webcam.mp4"
      continue
    fi

    mv -f "$BASE_PATH/webcam.mp4" "$BASE_PATH/webcam/temp-1.mp4"

    ffmpeg -f concat -safe 0 -i "$BASE_PATH/webcam/files.txt" -c copy "$BASE_PATH/webcam.mp4"

    if [ ! -f "$BASE_PATH/result.mp4" ]; then
      ffmpeg -y -i "$BASE_PATH/eDP-1.mp4" -i "$BASE_PATH/webcam.mp4" -filter_complex "\
      [0:v]scale=1920:1080[bg]; \
      [1:v]scale=587:330[small1]; \
      [bg][small1]overlay=0:main_h-overlay_h[outv]" \
        -map "[outv]" -map 0:a? -c:v libx264 -crf 18 -preset veryfast -c:a aac -shortest "$BASE_PATH/result.mp4"

      sleep 3
      continue
    fi

    ffmpeg -y -i "$BASE_PATH/eDP-1/temp-2.mp4" -i "$BASE_PATH/webcam/temp-2.mp4" -filter_complex "\
    [0:v]scale=1920:1080[bg]; \
    [1:v]scale=587:330[small1]; \
    [bg][small1]overlay=0:main_h-overlay_h[outv]" \
      -map "[outv]" -map 0:a? -c:v libx264 -crf 18 -preset veryfast -c:a aac -shortest "$BASE_PATH/temp-2.mp4"

    mv -f "$BASE_PATH/result.mp4" "$BASE_PATH/temp-1.mp4"

    ffmpeg -f concat -safe 0 -i "$BASE_PATH/files.txt" -c copy "$BASE_PATH/result.mp4"

    for monitor in $MONITORS; do
      rm "$BASE_PATH/$monitor/temp-1.mp4"
      rm "$BASE_PATH/$monitor/temp-2.mp4"
    done
    rm "$BASE_PATH/webcam/temp-1.mp4"
    rm "$BASE_PATH/webcam/temp-2.mp4"
    rm "$BASE_PATH/temp-1.mp4"
    rm "$BASE_PATH/temp-2.mp4"
  fi

  sleep 3
done
