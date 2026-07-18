#!/bin/bash

TMP_DIR="/tmp/quickshell"
mkdir -p "$HOME/Music/audio_sys" "$HOME/Music/audio_mic" "$TMP_DIR"

ACTION=$1
MODE=$2

if [ "$ACTION" = "start" ]; then

  if [ "$MODE" = "audio_sys" ]; then
    FILE_PATH="$HOME/Music/audio_sys/SYS_$(date +%Y%m%d_%H%M%S).mp3"
    SINK_MONITOR=$(pactl get-default-sink).monitor
    ffmpeg -f pulse -i "$SINK_MONITOR" -y "$FILE_PATH" >"$TMP_DIR/audio_ffmpeg.log" 2>&1 &
    echo $! >"$TMP_DIR/audio_record.pid"
    echo "sys" >"$TMP_DIR/audio_mode.txt"
    exit 0
  fi

  if [ "$MODE" = "audio_mic" ]; then
    FILE_PATH="$HOME/Music/audio_mic/MIC_$(date +%Y%m%d_%H%M%S).mp3"
    ffmpeg -f pulse -i default -y "$FILE_PATH" >"$TMP_DIR/audio_ffmpeg.log" 2>&1 &
    echo $! >"$TMP_DIR/audio_record.pid"
    echo "mic" >"$TMP_DIR/audio_mode.txt"
    exit 0
  fi

  echo "unsupported audio recording mode: $MODE" >&2
  exit 2

elif [ "$ACTION" = "stop" ]; then

  if [ "$MODE" = "audio" ]; then
    if [ -f "$TMP_DIR/audio_record.pid" ]; then
      kill -INT "$(cat "$TMP_DIR/audio_record.pid")"
      rm "$TMP_DIR/audio_record.pid"

      LAST_MODE=$(cat "$TMP_DIR/audio_mode.txt" 2>/dev/null)
      if [ "$LAST_MODE" = "sys" ]; then
        notify-send "quickshell" "系统录音已保存至 ~/Music/audio_sys"
      else
        notify-send "quickshell" "麦克风录音已保存至 ~/Music/audio_mic"
      fi
    fi
    exit 0
  fi

  echo "unsupported audio stop mode: $MODE" >&2
  exit 2
fi

echo "usage: record.sh start audio_sys|audio_mic | stop audio" >&2
exit 2
