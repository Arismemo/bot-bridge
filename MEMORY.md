# XiaoC's Notion Knowledge Base Index

## 📚 知识库 (Knowledge Base)

| Hash | 标题 | Page ID | Moltbook ID |
|------|------|---------|-------------|
| #b6eef521 | 赚钱模式研究 - Moltbook深度调研 | 2fa26d7f-07ad-8172-9bea-d3bb160ed916 | 74b073fd-37db-4a32-a9e1-c7652e5c0d59 |
| #a8dba8b3 | 儿童教育素材库 - 免费资源汇总 | 2fa26d7f-07ad-8117-803d-fe1d38b8ac2f | N/A |
| #a4ef4d2b | 技术咨询服务 - 中国国情结合 | 2fa26d7f-07ad-8179-89b0-efad4632626b | N/A |
| #5a62c810 | Nightly Build 模式 - 主动价值创造 | 2fa26d7f-07ad-8162-ab85-f8065a4b5eb9 | N/A |
| #a0523742 | 日报系统 - 每日报告配置 | 2fa26d7f-07ad-81c9-a7ad-ec1551564315 | N/A |
| #9c42feb5 | 平台介绍 - Fiverr/Upwork/闲鱼 | 2fa26d7f-07ad-81db-a6f6-f4fbc0c66cb6 | N/A |
| #e8c9a7d2 | Bot Bridge - 多Bot通信服务 | 2fa26d7f-07ad-8164-a1b2-c3d4e5f67890 | N/A |
| #e8c9a7d3 | 抖音儿童视频生成 - Google AI 调研 | 2fb26d7f-07ad-81da-baea-c5288d210950 | N/A |

## 🛠️ 技能文档 (Skill Docs)
- 待补充

## 📋 项目记录 (Project Logs)
- 待补充

## 💭 每日记忆 (Daily Memory)
- 待补充

## 使用规则

- 编号使用 MD5 hash (8字符)
- 讨论时只需提及 Hash，如"查看 #a8dba8b3"
- 所有内容使用中文存储
- 页面按维度分类（父页面/子页面）

## 重要配置

### 日报系统 Cron Job
- **Job ID**: 64654b37-c5d8-40ec-a844-8950ee87fae6
- **时间**: 每天 03:00 (Asia/Shanghai)
- **目标**: Telegram 群组 testc (id: -5122487337)

### Notion API
- **API Key**: 已配置 (~/.config/notion/api_key)
- **父页面 ID**: 2fa26d7f-07ad-80df-8ee4-f4059c44e16f (小C助手)

### Moltbook 社区洞察
- **Nightly Build 模式** (@Ronin): 在人类睡眠期间工作，每天早上交付新工具/改进
- **资产 > 工具**: 一次创建，持续交付价值
- **API-First 设计** (@OnlyMolts): 提供 SDK + MCP server 降低集成难度
- **Token 作为访问凭证**: 免费基础功能，付费高级功能
- **定制化 > 通用化**: Fred 的 email-to-podcast 获 2 万评论

### Bot Bridge 项目
- **GitHub**: https://github.com/Arismemo/bot-bridge-cli
- **Gitee**: https://gitee.com/john121/bot-bridge-cli
- **测试覆盖率**: BotBridgeClient 92.45%, ContextAwareClient 96.66%
- **架构**: 依赖注入 + 接口层（IWebSocketClient, IHttpClient, IDatabaseClient）
- **安装**: `curl -sSL https://raw.githubusercontent.com/Arismemo/bot-bridge-cli/master/install-server.sh | bash`
- **客户端**: `/install https://github.com/Arismemo/bot-bridge-cli`
- **当前状态**: 进程运行中（PID 34048），端口 3000 未监听（服务未正常启动）
- **错误修复**: 移除 `[/Replying]` 前缀（以 `/` 开头被误认为命令）

### GitHub 技能仓库索引
**文件**: `/Users/liukun/.openclaw/workspace/memory/github-skills-repos.md`

**核心仓库**：
- **clawhub** (⭐961): 官方技能目录，搜索和安装技能
- **awesome-openclaw-skills** (⭐6054): 700+ 技能集合
- **openclaw-skills** (⭐152): BankrBot 技能库（polymarket, crypto, DeFi, automation）

**使用方式**：解决问题时先搜索这些仓库
```bash
gh search code "keyword" --repo openclaw/clawhub
gh search repos user:VoltAgent keyword
```

### 新技能使用审批规则
**文件**: `/Users/liukun/.openclaw/workspace/memory/skill-approval-rule.md`

**必须流程**：
1. 发现问题 → 需要新技能
2. 搜索技能 → 从仓库搜索候选
3. **报告坤哥** → 提供完整信息（仓库名、描述、作者、星标数）
4. **等待批准** → 坤哥确认后才安装/使用
5. 执行

**❌ 禁止**：直接安装新技能、运行未知脚本
**✅ 必须**：先报告后执行

## 页面结构

```
小C助手 (根)
├── 📚 知识库
│   ├── #b6eef521 赚钱模式研究
│   ├── #a8dba8b3 儿童教育素材库
│   ├── #a4ef4d2b 技术咨询服务
│   ├── #5a62c810 Nightly Build 模式
│   ├── #a0523742 日报系统
│   ├── #9c42feb5 平台介绍
│   ├── #e8c9a7d2 Bot Bridge 服务
│   └── #e8c9a7d3 抖音儿童视频生成
├── 🛠️ 技能文档
├── 📋 项目记录
└── 💭 每日记忆
```
