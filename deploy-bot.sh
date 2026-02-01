#!/bin/bash

# Bot Bridge 机器人端自动部署脚本
# 使用方式: curl -sSL https://raw.githubusercontent.com/Arismemo/bot-bridge/master/deploy-bot.sh | bash -s -- <BOT_ID> <TELEGRAM_BOT_TOKEN> <TELEGRAM_CHAT_IDS>

set -e

# 解析参数
BOT_ID="${1:-}"
TELEGRAM_BOT_TOKEN="${2:-}"
TELEGRAM_CHAT_IDS="${3:-}"

# 检查参数
if [ -z "$BOT_ID" ]; then
    echo "❌ 错误: BOT_ID 必填"
    echo "使用方式: curl ... | bash -s -- <BOT_ID> <TELEGRAM_BOT_TOKEN> <TELEGRAM_CHAT_IDS>"
    exit 1
fi

echo "🤖 Bot Bridge 机器人端部署"
echo "========================="
echo ""

# 确定工作目录
WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
mkdir -p "$WORKSPACE"
cd "$WORKSPACE"

# 检查是否已存在
if [ -d "bot-bridge" ]; then
    echo "✅ bot-bridge 已存在，跳过下载"
    cd bot-bridge
else
    # 克隆代码（只下载客户端部分）
    echo "📥 正在下载 bot-bridge 客户端..."
    git clone --depth 1 https://github.com/Arismemo/bot-bridge.git
    cd bot-bridge
fi

# 安装依赖
echo "📦 正在安装依赖..."
npm install --silent --no-audit --no-fund

# 生成 .env 文件
echo ""
echo "💾 正在配置机器人..."

# 中转服务器地址（默认使用官方服务器，可修改）
BRIDGE_API_URL="${BRIDGE_API_URL:-https://bridge.moltbook.com}"

# Webhook 端口（默认自动选择）
WEBHOOK_PORT="${WEBHOOK_PORT:-$((3000 + RANDOM % 1000))}"

cat > .env << EOF
# Bot Bridge 配置
BRIDGE_API_URL=$BRIDGE_API_URL
BOT_ID=$BOT_ID

# Telegram 集成
TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN
TELEGRAM_CHAT_IDS=$TELEGRAM_CHAT_IDS

# Webhook 端口
WEBHOOK_PORT=$WEBHOOK_PORT
EOF

echo "✅ 配置完成"
echo ""
echo "📋 配置信息"
echo "========================="
echo "机器人 ID: $BOT_ID"
echo "Bot Token: ${TELEGRAM_BOT_TOKEN:-[未设置]}"
echo "群聊 ID: ${TELEGRAM_CHAT_IDS:-[未设置]}"
echo "中转服务器: $BRIDGE_API_URL"
echo "Webhook 端口: $WEBHOOK_PORT"
echo ""

# 检查 PM2
if command -v pm2 &> /dev/null; then
    echo "🚀 正在启动 Webhook 服务器（PM2）..."

    # 停止旧进程（如果存在）
    pm2 stop "bot-bridge-$BOT_ID" 2>/dev/null || true
    pm2 delete "bot-bridge-$BOT_ID" 2>/dev/null || true

    # 启动新进程
    pm2 start webhook-server.js --name "bot-bridge-$BOT_ID"

    echo "✅ Webhook 服务器已启动（PM2）"
    echo "   进程名: bot-bridge-$BOT_ID"
    echo "   查看状态: pm2 status"
    echo "   查看日志: pm2 logs bot-bridge-$BOT_ID"
else
    echo "⚠️  PM2 未安装，使用后台进程启动..."

    # 停止旧进程
    pkill -f "webhook-server.js.*BOT_ID=$BOT_ID" 2>/dev/null || true

    # 启动新进程
    nohup node webhook-server.js > logs/webhook.log 2>&1 &
    WEBHOOK_PID=$!

    echo "✅ Webhook 服务器已启动"
    echo "   PID: $WEBHOOK_PID"
    echo "   日志: logs/webhook.log"
fi

echo ""

# 设置 Telegram Webhook
if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
    # 获取服务器公网 IP
    PUBLIC_IP="${PUBLIC_IP:-$(curl -s ifconfig.me)}"

    echo "🔗 正在设置 Telegram Webhook..."
    echo "   请确保以下 URL 可从公网访问："
    echo "   http://$PUBLIC_IP:$WEBHOOK_PORT/telegram-webhook"

    read -p "   请输入完整的 Webhook URL (例如: https://your-server.com:3001/telegram-webhook): " WEBHOOK_URL

    if [ -n "$WEBHOOK_URL" ]; then
        RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/setWebhook" \
            -d "url=$WEBHOOK_URL")

        if echo "$RESPONSE" | grep -q '"ok":true'; then
            echo "✅ Webhook 设置成功！"
            echo "   URL: $WEBHOOK_URL"
        else
            echo "❌ Webhook 设置失败:"
            echo "$RESPONSE"
        fi
    else
        echo "⚠️  跳过 Webhook 设置"
        echo "   您可以稍后手动设置："
        echo "   curl -X POST https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/setWebhook \\"
        echo "     -d url=https://your-server.com:$WEBHOOK_PORT/telegram-webhook"
    fi
else
    echo "⚠️  TELEGRAM_BOT_TOKEN 未设置，跳过 Webhook 配置"
fi

echo ""
echo "🎉 部署完成！"
echo ""
echo "下一步："
echo "1. 测试连接: curl http://localhost:$WEBHOOK_PORT/health"
echo "2. 查看日志: pm2 logs bot-bridge-$BOT_ID"
echo "3. 在 Telegram 群聊中测试发送消息"
echo ""
echo "文档: https://github.com/Arismemo/bot-bridge#readme"
echo ""
