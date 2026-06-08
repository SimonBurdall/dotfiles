#!/usr/bin/env bash
# Single activity glyph with cpu/ram/gpu in the tooltip.

ICON="󰓅"

# CPU usage
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2 + $4)}')

# RAM usage
RAM=$(free -m | awk '/^Mem:/ {printf "%.1fG / %.1fG", $3/1024, $2/1024}')

# GPU usage (NVIDIA)
GPU=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)
if [ -n "$GPU" ]; then
    GPU_LINE="GPU: ${GPU}%"
else
    GPU_LINE="GPU: n/a"
fi

TOOLTIP="CPU: ${CPU}%\nRAM: ${RAM}\n${GPU_LINE}"

printf '{"text":"%s","tooltip":"%s"}\n' "$ICON" "$TOOLTIP"
