# 每晚 CEO 简报（21:00）

## 做什么

1. **派单**（可选）：`portfolio-dispatch --local`，消化 `agent-safe` 队列  
2. **日报**：汇总 BLOCKED / 交付 / 建议动作  
3. **推送**：飞书或 Slack webhook（只推摘要，不推 diff）

## 一次性配置

```bash
cp .ai-company/config/local.env.example .ai-company/config/local.env
# 编辑：FEISHU_WEBHOOK_URL 或 SLACK_WEBHOOK_URL

# 试跑（不派单）
bash scripts/ai-company/ceo-daily-brief.sh --no-notify

# 试跑（派单 + 日报）
bash scripts/ai-company/ceo-nightly.sh

# 安装 cron（每晚 21:00，本机时区）
bash scripts/ai-company/install-nightly-cron.sh --install
```

确保 Mac 未睡眠，或 cron 跑在常开机器上。

## CEO 只需回三种话

| 情况 | 你回 |
|------|------|
| BLOCKED 澄清 | 「选 A / 补充一句需求」 |
| 绿 PR 待 merge | 「merge #xx」或依赖 auto-merge |
| 无 BLOCKED | 不回复，继续睡 |

## 日志

- 日报 markdown：`~/.multica/ceo-briefs/brief-*.md`
- nightly 日志：`~/.multica/ceo-nightly.log`
