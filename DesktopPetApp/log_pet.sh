#!/bin/bash

# 监控日志并写入文件
LOG_FILE=~/Desktop/desktoppet.log

echo "开始监听 DesktopPet 日志，写入到 $LOG_FILE"
echo "按 Ctrl+C 停止监听"

# 清空日志文件
> "$LOG_FILE"

# 监听日志
while true; do
    log show --predicate 'processImagePath CONTAINS "DesktopPet"' --last 30s --style compact 2>&1 | grep -E "素材|load|walk|hover|play|鼠标|菜单" >> "$LOG_FILE"
    sleep 1
done