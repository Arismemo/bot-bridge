/**
 * Bot Bridge Client (Context-Aware 版本)
 *
 * OpenClaw bot 客户端，支持：
 * - WebSocket 实时通信
 * - Telegram 群聊消息监听
 * - 消息合并（Telegram + Bridge）
 * - 基于上下文的回复决策
 */
const WebSocket = require('ws');
const axios = require('axios');

class BotBridgeClient {
  constructor(config = {}) {
    this.apiUrl = config.apiUrl || process.env.BRIDGE_API_URL || 'http://localhost:3000';
    this.botId = config.botId || process.env.BOT_ID || 'unknown';
    this.ws = null;
    this.connected = false;
    this.messageQueue = [];
    this.onMessage = config.onMessage || (() => {});
    this.onConnectionChange = config.onConnectionChange || (() => {});
    this.onError = config.onError || ((err) => console.error(err));
    this.reconnectAttempts = 0;
    this.maxReconnectAttempts = 10;
    this.reconnectDelay = 1000;
    this.httpOnly = config.httpOnly || false;

    if (!this.httpOnly) {
      this.connect();
    }
  }

  connect() {
    const wsUrl = this.apiUrl.replace('http://', 'ws://').replace('https://', 'wss://');
    this.ws = new WebSocket(`${wsUrl}/?bot_id=${this.botId}`);

    this.ws.on('open', () => {
      console.log(`[BotBridge] Connected: ${this.botId}`);
      this.connected = true;
      this.reconnectAttempts = 0;
      this.onConnectionChange(true);
      this.flushMessageQueue();
    });

    this.ws.on('message', (data) => {
      try {
        const message = JSON.parse(data);
        this.handleMessage(message);
      } catch (err) {
        this.onError(`Failed to parse message: ${err.message}`);
      }
    });

    this.ws.on('close', () => {
      console.log(`[BotBridge] Disconnected: ${this.botId}`);
      this.connected = false;
      this.onConnectionChange(false);

      if (this.reconnectAttempts < this.maxReconnectAttempts) {
        this.reconnectAttempts++;
        const delay = this.reconnectDelay * Math.pow(2, this.reconnectAttempts - 1);
        console.log(`[BotBridge] Reconnecting in ${delay}ms... (attempt ${this.reconnectAttempts})`);
        setTimeout(() => this.connect(), delay);
      }
    });

    this.ws.on('error', (err) => {
      this.onError(`WebSocket error: ${err.message}`);
    });
  }

  handleMessage(message) {
    switch (message.type) {
      case 'connected':
        console.log(`[BotBridge] Server acknowledged connection`);
        break;

      case 'message':
        this.onMessage({
          source: 'bridge',
          sender: message.sender,
          content: message.content,
          timestamp: message.timestamp,
          metadata: message.metadata
        });
        this.sendAck(message);
        break;

      case 'unread_messages':
        console.log(`[BotBridge] Received ${message.count} unread message(s)`);
        message.messages.forEach(msg => {
          this.onMessage({
            source: 'bridge',
            sender: msg.sender,
            content: msg.content,
            timestamp: msg.created_at,
            metadata: msg.metadata
          });
          this.sendAck(msg);
        });
        break;

      case 'pong':
        break;

      default:
        console.log(`[BotBridge] Unknown message type: ${message.type}`);
    }
  }

  sendAck(message) {
    if (this.connected && message.id) {
      this.ws.send(JSON.stringify({
        type: 'ack',
        messageId: message.id
      }));
    }
  }

  async sendMessage(recipient, content, metadata = {}) {
    const message = {
      type: 'send',
      sender: this.botId,
      recipient,
      content,
      metadata: {
        ...metadata,
        timestamp: new Date().toISOString(),
        telegram_message_id: metadata.telegram_message_id
      }
    };

    if (this.connected) {
      this.ws.send(JSON.stringify(message));
      return { success: true, sent: true };
    } else {
      try {
        const response = await axios.post(`${this.apiUrl}/api/messages`, {
          sender: this.botId,
          recipient,
          content,
          metadata: message.metadata
        });
        return response.data;
      } catch (error) {
        this.onError(`HTTP Send message failed: ${error.message}`);
        return { success: false, error: error.message };
      }
    }
  }

  broadcast(content, metadata = {}) {
    const message = {
      type: 'broadcast',
      sender: this.botId,
      content,
      metadata: {
        ...metadata,
        timestamp: new Date().toISOString()
      }
    };

    if (this.connected) {
      this.ws.send(JSON.stringify(message));
      return Promise.resolve({ success: true });
    } else {
      return Promise.resolve({ success: false, error: 'Not connected' });
    }
  }

  flushMessageQueue() {
    if (this.messageQueue.length > 0) {
      console.log(`[BotBridge] Sending ${this.messageQueue.length} queued message(s)`);
      const queue = [...this.messageQueue];
      this.messageQueue = [];
      queue.forEach(message => {
        this.ws.send(JSON.stringify(message));
      });
    }
  }

  replyTo(originalMessage, content, metadata = {}) {
    return this.sendMessage(
      originalMessage.sender,
      content,
      {
        reply_to: originalMessage.id,
        ...metadata
      }
    );
  }

  async healthCheck() {
    try {
      const response = await axios.get(`${this.apiUrl}/health`, { timeout: 3000 });
      return response.status === 200;
    } catch (error) {
      return false;
    }
  }

  async getStatus() {
    try {
      const response = await axios.get(`${this.apiUrl}/api/status`);
      return response.data;
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  async getConnectedBots() {
    try {
      const response = await axios.get(`${this.apiUrl}/api/connections`);
      return response.data;
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  async getUnreadMessages() {
    try {
      const response = await axios.get(
        `${this.apiUrl}/api/messages`,
        {
          params: {
            recipient: this.botId,
            status: 'unread',
            limit: 50
          }
        }
      );

      return response.data;
    } catch (error) {
      this.onError(`Get messages failed: ${error.message}`);
      return { success: false, error: error.message, messages: [] };
    }
  }

  async markAsRead(messageId) {
    try {
      const response = await axios.post(`${this.apiUrl}/api/messages/${messageId}/read`);
      return response.data;
    } catch (error) {
      this.onError(`Mark as read failed: ${error.message}`);
      return { success: false, error: error.message };
    }
  }

  disconnect() {
    if (this.ws) {
      this.ws.close();
      this.connected = false;
    }
  }
}

// === Context-Aware Bot (合并 Telegram + Bridge 消息) ===

class ContextAwareBot {
  constructor(config) {
    this.bridge = new BotBridgeClient(config);

    // Telegram 配置
    this.telegramBotToken = config.telegramBotToken || process.env.TELEGRAM_BOT_TOKEN;
    this.telegramChatIds = this.parseChatIds(
      config.telegramChatIds || process.env.TELEGRAM_CHAT_IDS
    );

    // 消息存储
    this.messages = new Map(); // key: timestamp + sender, value: message object

    // 回调
    this.onNewMessage = config.onNewMessage || (() => {});
    this.onDecideReply = config.onDecideReply || ((context) => null);

    // 启动监听
    this.startListening();
  }

  /**
   * 解析群聊 ID（支持单个或多个）
   */
  parseChatIds(chatIds) {
    if (!chatIds) return [];
    if (typeof chatIds === 'string') {
      return chatIds.split(',').map(id => id.trim());
    }
    return chatIds;
  }

  /**
   * 启动消息监听
   */
  startListening() {
    // 监听 Bridge 消息
    this.bridge.onMessage = (message) => {
      this.addMessage({
        source: 'bridge',
        ...message
      });
    };

    // Telegram 消息需要通过外部传入（见 addTelegramMessage）
  }

  /**
   * 添加 Telegram 消息（从外部 webhook 或轮询调用）
   */
  addTelegramMessage(telegramMessage) {
    const message = {
      source: 'telegram',
      sender: telegramMessage.from?.username || telegramMessage.from?.first_name || 'user',
      userId: telegramMessage.from?.id,
      content: telegramMessage.text || telegramMessage.caption || '',
      timestamp: new Date(telegramMessage.date * 1000).toISOString(),
      messageId: telegramMessage.message_id,
      chatId: telegramMessage.chat.id,
      metadata: {
        reply_to_message_id: telegramMessage.reply_to_message?.message_id
      }
    };

    this.addMessage(message);
  }

  /**
   * 添加消息到存储并触发回调
   */
  addMessage(message) {
    // 生成唯一键
    const key = `${message.timestamp}_${message.source}_${message.sender}`;
    this.messages.set(key, message);

    console.log(`[Context] New message: [${message.source}] ${message.sender}: ${message.content}`);

    // 触发新消息回调
    this.onNewMessage(message);
  }

  /**
   * 获取按时间排序的完整聊天记录
   */
  getChatHistory(options = {}) {
    const {
      limit = 100,
      after = null,
      sources = ['telegram', 'bridge'],
      chatIds = null
    } = options;

    // 过滤消息
    let filtered = Array.from(this.messages.values());

    if (after) {
      filtered = filtered.filter(m => new Date(m.timestamp) > new Date(after));
    }

    if (sources && sources.length > 0) {
      filtered = filtered.filter(m => sources.includes(m.source));
    }

    if (chatIds && chatIds.length > 0) {
      filtered = filtered.filter(m => !m.chatId || chatIds.includes(m.chatId));
    }

    // 按时间排序
    filtered.sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));

    // 限制数量
    return filtered.slice(-limit);
  }

  /**
   * 获取最近的上下文（用于 OpenClaw 理解）
   */
  getContext(options = {}) {
    const { limit = 20, chatId = null } = options;
    const history = this.getChatHistory({ limit, chatIds: chatId ? [chatId] : null });

    // 格式化为易读格式
    return history.map(m => {
      const prefix = m.source === 'bridge' ? `[来自 ${m.sender}]` : '';
      return `${m.sender}: ${prefix} ${m.content}`;
    }).join('\n');
  }

  /**
   * 决定是否回复
   */
  decideReply(options = {}) {
    const { limit = 10, chatId = null } = options;
    const context = this.getChatHistory({ limit, chatIds: chatId ? [chatId] : null });

    // 调用用户自定义的决策函数
    return this.onDecideReply(context);
  }

  /**
   * 发送消息到 Telegram 群聊，并通知服务器
   */
  async sendMessageToGroup(chatId, content, options = {}) {
    const { alsoNotifyBridge = true, notifyRecipient = null } = options;

    // 发送到 Telegram
    let telegramResult = null;
    try {
      const url = `https://api.telegram.org/bot${this.telegramBotToken}/sendMessage`;
      const response = await axios.post(url, {
        chat_id: chatId,
        text: content
      });
      telegramResult = response.data;
    } catch (error) {
      console.error('[Telegram] Send error:', error.response?.data || error.message);
      throw error;
    }

    // 同时发送到服务器（通知其他机器人）
    if (alsoNotifyBridge && notifyRecipient) {
      await this.bridge.sendMessage(notifyRecipient, content, {
        telegram_message_id: telegramResult.result?.message_id,
        chat_id: chatId
      });
    }

    return telegramResult;
  }

  /**
   * 处理来自 Telegram 的消息
   */
  handleTelegramMessage(telegramMessage) {
    // 添加到上下文
    this.addTelegramMessage(telegramMessage);

    // 决定是否回复
    const decision = this.decideReply({ chatId: telegramMessage.chat.id });

    if (decision && decision.shouldReply) {
      this.sendMessageToGroup(
        telegramMessage.chat.id,
        decision.reply,
        {
          alsoNotifyBridge: true,
          notifyRecipient: decision.notifyRecipient || null
        }
      );
    }
  }

  get bridge() {
    return this.bridge;
  }

  disconnect() {
    this.bridge.disconnect();
  }
}

/**
 * 将消息发送到 Telegram 群聊
 */
async function sendToTelegram(botToken, chatId, text, replyToMessageId = null) {
  const url = `https://api.telegram.org/bot${botToken}/sendMessage`;

  try {
    const response = await axios.post(url, {
      chat_id: chatId,
      text: text,
      reply_to_message_id: replyToMessageId
    });

    return response.data;
  } catch (error) {
    console.error('[Telegram] Send error:', error.response?.data || error.message);
    throw error;
  }
}

module.exports = { BotBridgeClient, ContextAwareBot, sendToTelegram };
