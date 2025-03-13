#!/bin/bash
# 设置目标文件夹路径为当前工作目录中的 "adguard_rules" 文件夹
TARGET_DIR="$(pwd)/adguard_rules"  # 使用当前目录加上文件夹名
LOG_FILE="$(pwd)/download_failures.log"  # 下载失败记录日志文件

# 设置代理服务器地址 (如果需要代理)
PROXY="http://192.168.1.250:1088"  # 在这里替换为你的代理服务器地址

# 创建目标文件夹，如果不存在的话
mkdir -p "$TARGET_DIR"

# 清空日志文件
> "$LOG_FILE"

# 检查 urls.txt 文件是否存在，如果不存在则创建并添加默认内容
if [ ! -f "$(pwd)/urls.txt" ]; then  # 确保使用绝对路径
    echo "urls.txt 文件不存在，正在创建并添加默认规则 URL..."
    cat <<EOL > "$(pwd)/urls.txt"  # 使用绝对路径创建文件
#每行一个链接就是一个规则
https://raw.githubusercontent.com/privacy-protection-tools/anti-AD/master/anti-ad-easylist.txt
https://raw.githubusercontent.com/banbendalao/ADgk/master/ADgk.txt
EOL
    echo "urls.txt 文件已创建并添加默认规则 URL。"
fi

echo "开始批量下载规则文件..."

LINE_NUMBER=0
while IFS= read -r FILE_URL || [ -n "$FILE_URL" ]; do  # 防止文件最后一行为空时出错
    # 跳过注释行和空行
    if [[ "$FILE_URL" =~ ^# ]] || [ -z "$FILE_URL" ]; then
        continue
    fi

    LINE_NUMBER=$((LINE_NUMBER + 1))  # 行号递增

    # 获取文件名（不带路径）
    FILE_NAME=$(basename "$FILE_URL")
    RULE_FILE="$TARGET_DIR/$FILE_NAME"

    # 初始化重试次数
    RETRY_COUNT=0
    MAX_RETRIES=3  # 设置最大重试次数为3
    SUCCESS=false

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        # 下载规则文件，增加超时时间为90秒
        if [ -z "$PROXY" ]; then
            echo "下载规则文件: $FILE_NAME (尝试 $((RETRY_COUNT + 1)))..."
            curl --max-time 90 -o "$RULE_FILE" "$FILE_URL"
        else
            echo "使用代理服务器下载规则文件: $FILE_NAME (尝试 $((RETRY_COUNT + 1)))..."
            curl --max-time 90 -x "$PROXY" -o "$RULE_FILE" "$FILE_URL"
        fi

        # 检查下载是否成功
        if [ $? -eq 0 ]; then
            SUCCESS=true
            echo "规则文件下载完成: $FILE_NAME"
            break
        else
            RETRY_COUNT=$((RETRY_COUNT + 1))
            echo "下载失败: $FILE_NAME (重试 $RETRY_COUNT/$MAX_RETRIES)"
        fi
    done

    # 如果下载失败，记录到日志文件
    if [ "$SUCCESS" = false ]; then
        echo "第$LINE_NUMBER行: $FILE_URL 下载失败" >> "$LOG_FILE"
    fi
done < "$(pwd)/urls.txt"  # 使用绝对路径

# 获取本地 IP 地址
LOCAL_IP=$(hostname -I | awk '{print $1}')

# 检查是否有已有的 HTTP 服务器在运行，若有则先停止它
echo "检查是否已有 HTTP 服务器在运行..."
SERVER_PID=$(ps aux | grep "python3 -m http.server" | grep -v grep | awk '{print $2}')
if [ -n "$SERVER_PID" ]; then
    echo "发现已有 HTTP 服务器在运行，PID: $SERVER_PID，正在停止..."
    kill -9 "$SERVER_PID"
    echo "HTTP 服务器已停止。"
fi

# 启动 HTTP 服务器，监听所有网络接口（0.0.0.0）
echo "启动 HTTP 服务器..."
cd "$TARGET_DIR"
nohup python3 -m http.server 8080 --bind 0.0.0.0 > /dev/null 2>&1 &

# 输出本地访问 URL
echo "HTTP 服务器已启动，您可以通过 http://$LOCAL_IP:8080/ 访问下载的规则文件。"

# 输出每个规则文件的更新 URL，并保存到 rule.txt 文件
echo "以下是 AdGuard Home 更新规则的 URL 列表：" > "$(pwd)/rule.txt"  # 清空 rule.txt 并写入标题
for RULE_FILE in "$TARGET_DIR"/*; do
    # 只列出文件
    if [ -f "$RULE_FILE" ]; then
        FILE_NAME=$(basename "$RULE_FILE")
        RULE_URL="http://$LOCAL_IP:8080/$FILE_NAME"
        # 只在文件不是 rule.txt 时，才输出规则的 URL
        if [[ "$FILE_NAME" != "rule.txt" ]]; then
            echo "$RULE_URL"  # 在终端输出
        fi
        echo "$RULE_URL" >> "$(pwd)/rule.txt"  # 写入到 rule.txt 文件
    fi
done

# 完成
echo "脚本执行完成！"
