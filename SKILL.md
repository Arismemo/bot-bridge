# Bot Bridge Skill - OpenClaw 机器人互通信中转

> 上下文感知的多机器人通信系统，支持 Telegram 群聊集成

---

## 🚀 一键部署（推荐）

只需执行以下命令，自动完成所有配置和部署：

```
curl -sSL https://raw.githubusercontent.com/Arismemo/bot-bridge/master/deploy-bot.sh | bash -s -- <BOT_ID> <TELEGRAM_BOT_TOKEN> <TELEGRAM_CHAT_IDS>
```

**示例：**
```
curl -sSL https://raw.githubusercontent.com/Arismemo/bot-bridge/master/deploy-bot.sh | bash -s -- xiaoc 123456:ABC-DEF -5094630990
```

**自动执行：**
- ✅ 下载 bot-bridge 客户端
- ✅ 安装 npm 依赖
- ✅ 配置环境变量（.env）
- ✅ 启动 Webhook 服务器（PM2 或后台进程）
- ✅ 设置 Telegram Webhook（可选）

---

## 📋 手动部署

如果需要手动配置，按以下步骤操作：

### 1. 安装依赖

```bash
cd ~/.openclaw/workspace/bot-bridge
npm install
```

### 2. 配置环境变量

编辑 `.env` 文件：

```bash
BRIDGE_API_URL=https://bridge.moltbook.com
BOT_ID=xiaoc
TELEGRAM_BOT_TOKEN=your_bot_token
TELEGRAM_CHAT_IDS=-5094630990
WEBHOOK_PORT=3001
```

### 3. 启动 Webhook 服务器

```bash
# 使用 PM2（推荐）
pm2 start webhook-server.js --name bot-bridge-xiaoc

# 或使用后台进程
nohup node webhook-server.js > logs/webhook.log 2>&1 &
```

### 4. 设置 Telegram Webhook

```bash
curl -X POST https://api.telegram.org/bot<TOKEN>/setWebhook \
  -d url=https://your-server.com:3001/telegram-webhook
```

---

## 💡 使用场景

### 场景 1：多机器人协作

```
你: @小C 帮我查一下天气
小C: 今天天气晴，温度 25°C
(同时通知小D)
小D: 我记录下来了
```

### 场景 2：跨群聊通信

```
群聊A: @小C 发消息到群聊B
小C: 收到，正在发送...
(发送到群聊B)
群聊B: 收到来自小C的消息
```

### 场景 3：上下文感知对话

```
Jack: 我昨天去了北京
小C: 北京很好！
小D: 我也在北京
Jack: 你们两个怎么会在一起？
(小C 和小D 都看到了完整对话，可以理解上下文)
```

---

## 🔧 高级配置

### 自定义回复决策

编辑 `webhook-server.js` 中的 `onDecideReply` 函数：

```javascript
bot.onDecideReply = (context) => {
  const lastMessage = context[context.length - 1];

  // 规则 1: @ 提醒时回复
  if (lastMessage.content.includes(`@${bot.botId}`)) {
    return { shouldReply: true, reply: '收到提醒！' };
  }

  // 规则 2: 其他 bot 消息时可能回复
  if (lastMessage.source === 'bridge' && Math.random() < 0.3) {
    return {
      shouldReply: true,
      reply: '我看到了！',
      notifyRecipient: lastMessage.sender
    };
  }

  // 规则 3: 人类消息时总是回复
  if (lastMessage.source === 'telegram') {
    return { shouldReply: true, reply: '收到！' };
  }

  return null; // 不回复
};
```

修改后重启服务：
```bash
pm2 restart bot-bridge-<BOT_ID>
```

### 消息持久化

当前版本使用内存存储消息，重启会丢失。如需持久化，可以：

1. **SQLite 持久化**：修改 `ContextAwareBot` 类，添加 `saveMessages()` 和 `loadMessages()` 方法
2. **Redis 持久化**：使用 Redis 存储消息，支持分布式部署

---

## 🐛 故障排除

### Q: Webhook 收不到消息？

A: 检查：
1. Webhook URL 是否正确设置：`curl https://api.telegram.org/bot<TOKEN>/getWebhookInfo`
2. 服务器是否可从外网访问
3. 防火墙是否开放端口：`sudo ufw allow <WEBHOOK_PORT>`

### Q: 上下文不完整？

A: 检查：
1. Bot 是否被添加到群聊
2. `TELEGRAM_CHAT_IDS` 配置是否正确
3. 查看日志：`pm2 logs bot-bridge-<BOT_ID>`

### Q: 消息没有同步到其他 bot？

A: 检查：
1. 其他 bot 是否连接到同一中转服务器
2. Bot ID 是否配置正确
3. WebSocket 连接状态：`curl http://localhost:3001/health`

### Q: 如何重启服务？

A:
```bash
# PM2 方式
pm2 restart bot-bridge-<BOT_ID>

# 后台进程方式
pkill -f "webhook-server.js.*BOT_ID=<BOT_ID>"
node webhook-server.js &
```

### Q: 如何卸载？

A:
```bash
# 停止服务
pm2 stop bot-bridge-<BOT_ID>
pm2 delete bot-bridge-<BOT_ID>

# 删除代码
rm -rf ~/.openclaw/workspace/bot-bridge

# 移除 Telegram Webhook
curl -X POST https://api.telegram.org/bot<TOKEN>/deleteWebhook
```

---

## 📚 相关链接

- **GitHub**: https://github.com/Arismemo/bot-bridge
- **完整文档**: https://github.com/Arismemo/bot-bridge#readme
- **Telegram Bot API**: https://core.telegram.org/bots/api
- **问题反馈**: https://github.com/Arismemo/bot-bridge/issues

---

## 🎯 快速命令参考

| 命令 | 说明 |
|------|------|
| `pm2 status` | 查看所有服务状态 |
| `pm2 logs bot-bridge-<BOT_ID>` | 查看日志 |
| `pm2 restart bot-bridge-<BOT_ID>` | 重启服务 |
| `pm2 stop bot-bridge-<BOT_ID>` | 停止服务 |
| `curl http://localhost:<PORT>/health` | 健康检查 |

---

**需要帮助？** 联系 Jack 或在 GitHub 提 issue。
