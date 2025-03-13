#!/bin/bash

# 更新系统时间并设置为中国标准时间
echo "同步时间到中国标准时间..."

# 设置时区为中国标准时间 (Asia/Shanghai)
timedatectl set-timezone Asia/Shanghai

# 使用 NTP（Network Time Protocol）同步系统时间
timedatectl set-ntp true

# 打印当前时间和时区
echo "当前时间和时区设置为："
timedatectl

# 提示完成
echo "时间同步和时区设置已完成。"

# 目标时间，格式为 HH:MM
TARGET_TIME="02:00"  # 使用冒号分隔
SCRIPT_PATH="/root/ad/auto.sh"

# 无限循环，重复执行任务
while true; do
    # 获取当前时间的小时和分钟
    current_time=$(date +"%H:%M")
    
    # 检查当前时间是否已经到了目标时间
    if [ "$current_time" == "$TARGET_TIME" ]; then
        echo "到达目标时间 $TARGET_TIME，开始执行脚本 $SCRIPT_PATH ..."
        bash "$SCRIPT_PATH"
        echo "脚本执行完成，等待下一次目标时间..."
        
        # 等待 60 秒，避免重复执行脚本（防止目标时间和当前时间有轻微误差）
        sleep 60
    else
        echo "当前时间: $current_time, 等待目标时间 $TARGET_TIME ..."
    fi
    
    # 每 1 秒检查一次时间
    sleep 1
done
