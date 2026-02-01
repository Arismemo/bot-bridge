#!/bin/bash

# Bot Bridge 机器人端自动部署脚本
# 使用方式: curl -sSL https://raw.githubusercontent.com/Arismemo/bot-bridge/master/deploy-bot.sh | bash

set -e

echo "🤖 Bot Bridge 机器人端部署向导"
echo "================================"
echo ""

# 检查是否已安装 git 和 node
if ! command -v git &> /dev/null; then
    echo "❌ 错误: 请先安装 git"
    exit 1
fi

if ! command -v node &> /dev/null; then
    echo "❌ 错误: 请先安装 Node.js (建议 v18+)"
    exit 1
fi

# 交互式配置
echo "⚙️  步骤 1: 基本配置"
echo "-----------------------"

# BOT_ID
read -p "机器人 ID (必填): " BOT_ID
while [ -z "$BOT_ID" ]; do
    echo "❌ 机器人 ID 不能为空"
    read -p "机器人 ID (必填): " BOT_ID
done

# TELEGRAM_BOT_TOKEN
echo ""
read -p "Telegram Bot Token (可选，回车跳过): " TELEGRAM_BOT_TOKEN

# TELEGRAM_CHAT_IDS
echo ""
echo "提示: 可以设置多个群聊，用逗号分隔，如: -5094630990,-1000000000"
read -p "Telegram 群聊 ID (可选，回车跳过): " TELEGRAM_CHAT_IDS

echo ""
echo "⚙️  步骤 2: 中转服务器配置"
echo "---------------------------"

# BRIDGE_API_URL
echo "请输入中转服务器地址:"
echo "  - 如果在本机，使用: http://localhost:3000"
echo "  - 如果在其他服务器，使用: http://服务器IP:3000"
read -p "中转服务器地址 [默认: http://localhost:3000]: " BRIDGE_API_URL
BRIDGE_API_URL=${BRIDGE_API_URL:-http://localhost:3000}

# WEBHOOK_PORT
echo ""
read -p "Webhook 服务端口 [默认: 3001]: " WEBHOOK_PORT
WEBHOOK_PORT=${WEBHOOK_PORT:-3001}

# 确定工作目录
WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
mkdir -p "$WORKSPACE"
cd "$WORKSPACE"

# 检查是否已存在
if [ -d "bot-bridge" ]; then
    echo ""
    echo "⚠️  检测到 bot-bridge 目录已存在"
    read -p "是否重新克隆代码? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf bot-bridge
    else
        echo "✅ 使用现有代码"
        cd bot-bridge
        git pull
    fi
fi

if [ ! -d "bot-bridge" ]; then
    echo ""
    echo "📥 步骤 3: 下载代码"
    echo "--------------------"
    echo "正在克隆 bot-bridge 仓库..."
    git clone --depth 1 https://github.com/Arismemo/bot-bridge.git
    cd bot-bridge
fi

# 安装依赖
echo ""
echo "📦 步骤 4: 安装依赖"
echo "--------------------"
echo "正在安装 npm 依赖..."
npm install --silent --no-audit --no-fund
echo "✅ 依赖安装完成"

# 生成 .env 文件
echo ""
echo "💾 步骤 5: 生成配置文件"
echo "------------------------"

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

echo "✅ .env 文件已生成"

# 显示配置摘要
echo ""
echo "📋 配置摘要"
echo "========================="
echo "安装目录: $(pwd)"
echo "机器人 ID: $BOT_ID"
echo "Bot Token: ${TELEGRAM_BOT_TOKEN:-[未设置]}"
echo "群聊 ID: ${TELEGRAM_CHAT_IDS:-[未设置]}"
echo "中转服务器: $BRIDGE_API_URL"
echo "Webhook 端口: $WEBHOOK_PORT"
echo ""

# 询问是否立即启动服务
echo "⚙️  步骤 6: 启动服务"
echo "--------------------"

read -p "是否立即启动 Webhook 服务器? (Y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    # 检查 PM2
    if command -v pm2 &> /dev/null; then
        echo "🚀 正在启动 Webhook 服务器（PM2）..."

        # 停止旧进程
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

        # 创建日志目录
        mkdir -p logs

        # 启动新进程
        nohup node webhook-server.js > logs/webhook.log 2>&1 &
        WEBHOOK_PID=$!

        echo "✅ Webhook 服务器已启动"
        echo "   PID: $WEBHOOK_PID"
        echo "   日志: logs/webhook.log"
        echo "   停止: pkill -f 'webhook-server.js.*BOT_ID=$BOT_ID'"
    fi

    echo ""
    sleep 2
    echo "正在检查服务状态..."
    if curl -s "http://localhost:$WEBHOOK_PORT/health" > /dev/null; then
        echo "✅ 服务运行正常！"
    else
        echo "⚠️  服务可能未正常启动，请检查日志"
    fi
fi

# 设置 Telegram Webhook
if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
    echo ""
    echo "⚙️  步骤 7: 设置 Telegram Webhook"
    echo "----------------------------------"

    # 显示公网 IP（如果有）
    if command -v curl &> /dev/null; then
        PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "未知")
        echo "当前公网 IP: $PUBLIC_IP"
    fi

    echo ""
    echo "请输入完整的 Webhook URL，格式: https://域名:端口/telegram-webhook"
    echo "示例:"
    echo "  - 本地测试: http://localhost:$WEBHOOK_PORT/telegram-webhook"
    echo "  - 公网服务器: https://example.com:$WEBHOOK_PORT/telegram-webhook"
    echo "  - 使用 ngrok: https://your-ngrok-url/telegram-webhook"
    echo ""
    read -p "Webhook URL (回车跳过): " WEBHOOK_URL

    if [ -n "$WEBHOOK_URL" ]; then
        echo ""
        echo "🔗 正在设置 Telegram Webhook..."
        RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/setWebhook" \
            -d "url=$WEBHOOK_URL")

        if echo "$RESPONSE" | grep -q '"ok":true'; then
            echo "✅ Webhook 设置成功！"
            echo "   URL: $WEBHOOK_URL"
        else
            echo "❌ Webhook 设置失败:"
            echo "$RESPONSE"
            echo ""
            echo "可能的原因:"
            echo "1. URL 无法从公网访问（Telegram 需要公网 HTTPS）"
            echo "2. 端口未开放"
            echo "3. 证书问题（如果使用 HTTPS）"
            echo ""
            echo "建议使用 ngrok 进行测试:"
            echo "1. 安装 ngrok: https://ngrok.com/download"
            echo "2. 运行: ngrok http $WEBHOOK_PORT"
            echo "3. 使用 ngrok 提供的 URL 设置 Webhook"
        fi
    else
        echo "⚠️  跳过 Webhook 设置"
        echo ""
        echo "您可以稍后手动设置:"
        echo "  curl -X POST https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/setWebhook \\"
        echo "    -d url=https://your-server.com:$WEBHOOK_PORT/telegram-webhook"
    fi
else
    echo ""
    echo "⚠️  TELEGRAM_BOT_TOKEN 未设置，跳过 Webhook 配置"
fi

# 完成
echo ""
echo "🎉 部署完成！"
echo "================================"
echo ""
echo "下一步："
echo "1. 查看服务状态: pm2 status"
echo "2. 查看日志: pm2 logs bot-bridge-$BOT_ID"
echo "3. 测试服务: curl http://localhost:$WEBHOOK_PORT/health"
echo "4. 重启服务: pm2 restart bot-bridge-$BOT_ID"
echo "5. 停止服务: pm2 stop bot-bridge-$BOT_ID"
echo ""
echo "📚 文档: https://github.com/Arismemo/bot-bridge#readme"
echo "🐛 问题反馈: https://github.com/Arismemo/bot-bridge/issues"
echo ""
