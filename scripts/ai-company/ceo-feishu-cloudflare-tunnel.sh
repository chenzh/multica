#!/usr/bin/env bash
# Expose CEO Feishu approval callback (:9478) via Cloudflare Tunnel.
#
# Quick (no account): random trycloudflare.com URL — good for first Feishu setup.
# Named (stable URL): Cloudflare account + domain — see setup-named.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MULTICA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=lib/source-local-env.sh
source "$SCRIPT_DIR/lib/source-local-env.sh"

LABEL="com.multica.ceo-feishu-cloudflare"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG_FILE="${CEO_FEISHU_CF_TUNNEL_LOG:-$HOME/.multica/ceo-feishu-cloudflare.log}"
URL_FILE="${CEO_FEISHU_CF_TUNNEL_URL_FILE:-$HOME/.multica/ceo-feishu-cloudflare-url.txt}"
CONFIG_DIR="$MULTICA_ROOT/.ai-company/config"
NAMED_CONFIG="$CONFIG_DIR/cloudflared-ceo-feishu.yml"
PORT="${CEO_FEISHU_APPROVAL_PORT:-9478}"
CLOUDFLARED="${CLOUDFLARED_BIN:-$(command -v cloudflared || true)}"
RUN_TOKEN_FILE="${CEO_CLOUDFLARE_RUN_TOKEN_FILE:-$HOME/.multica/cloudflared-run-token}"
PROXY_ENV_BLOCK=""

proxy_env_for_plist() {
  PROXY_ENV_BLOCK=""
  local proxy_file="$MULTICA_ROOT/.ai-company/config/proxy.env"
  if [ -f "$proxy_file" ]; then
    # shellcheck disable=SC1090
    source "$proxy_file"
    if [ -n "${https_proxy:-}" ]; then
      local host_port="${https_proxy#*://}"
      local host="${host_port%%:*}"
      local port="${host_port##*:}"
      if curl -fsS --connect-timeout 2 "http://${host}:${port}/" >/dev/null 2>&1; then
        PROXY_ENV_BLOCK=$(
          cat <<PEOF
		<key>https_proxy</key>
		<string>${https_proxy}</string>
		<key>http_proxy</key>
		<string>${http_proxy:-$https_proxy}</string>
		<key>all_proxy</key>
		<string>${all_proxy:-}</string>
		<key>no_proxy</key>
		<string>127.0.0.1,localhost</string>
PEOF
        )
        echo "  使用代理: ${https_proxy}" >&2
      fi
    fi
  fi
}

usage() {
  cat <<EOF
Usage: ceo-feishu-cloudflare-tunnel.sh <command>

Commands:
  quick              Start quick tunnel; print public URL (trycloudflare.com)
  quick-install      LaunchAgent: quick tunnel (URL changes on restart)
  quick-url          Show last captured public URL
  token-install      LaunchAgent: tunnel run token (file or CLOUDFLARE_TUNNEL_TOKEN)
  fetch-run-token    Use CLOUDFLARE_API_TOKEN once → save scoped run token (recommended)
  login              cloudflared tunnel login (for stable hostname)
  setup-named        Print steps to create a named tunnel + config template
  named-install      LaunchAgent: named tunnel (\$NAMED_CONFIG)
  status             Tunnel + approval callback health
  logs               tail tunnel log
  uninstall          Remove LaunchAgent

Feishu open platform → 事件订阅:
  Request URL: https://<public-host>/feishu/event
  Events: card.action.trigger, im.message.receive_v1

Prereq: bash scripts/ai-company/ceo-feishu-approval-service.sh install
EOF
}

need_cloudflared() {
  if [ -z "$CLOUDFLARED" ] || [ ! -x "$CLOUDFLARED" ]; then
    echo "error: cloudflared not found — brew install cloudflared" >&2
    exit 1
  fi
}

need_approval_up() {
  if ! curl -fsS --max-time 2 "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
    echo "error: approval server not on :$PORT — bash $SCRIPT_DIR/ceo-feishu-approval-service.sh install" >&2
    exit 1
  fi
}

capture_quick_url() {
  need_cloudflared
  need_approval_up
  rm -f "$LOG_FILE"
  local -a cf_args=(tunnel --protocol http2 --url "http://127.0.0.1:$PORT")
  if [ -f "$MULTICA_ROOT/.ai-company/config/proxy.env" ]; then
    # shellcheck disable=SC1090
    source "$MULTICA_ROOT/.ai-company/config/proxy.env"
  fi
  "$CLOUDFLARED" "${cf_args[@]}" >>"$LOG_FILE" 2>&1 &
  local pid=$!
  echo "cloudflared pid: $pid (log: $LOG_FILE)"
  local url=""
  for _ in $(seq 1 45); do
    url="$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOG_FILE" 2>/dev/null | head -1 || true)"
    [ -n "$url" ] && break
    sleep 1
  done
  if [ -z "$url" ]; then
    echo "error: could not read trycloudflare URL from log within 45s" >&2
    kill "$pid" 2>/dev/null || true
    exit 1
  fi
  echo "$url" >"$URL_FILE"
  echo ""
  echo "公网 URL: $url"
  echo "飞书 Request URL: ${url}/feishu/event"
  echo "已写入: $URL_FILE"
  echo ""
  echo "按 Ctrl+C 停止 quick tunnel（pid $pid）"
  wait "$pid" || true
}

show_quick_url() {
  if [ -f "$URL_FILE" ]; then
    local url
    url="$(tr -d '[:space:]' <"$URL_FILE")"
    echo "公网 URL: $url"
    echo "飞书 Request URL: ${url}/feishu/event"
  else
    echo "尚无 URL — 先跑: bash $0 quick"
  fi
}

generate_quick_plist() {
  need_cloudflared
  proxy_env_for_plist
  cat >"$PLIST" <<PEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>$CLOUDFLARED</string>
		<string>tunnel</string>
		<string>--protocol</string>
		<string>http2</string>
		<string>--url</string>
		<string>http://127.0.0.1:$PORT</string>
	</array>
	<key>EnvironmentVariables</key>
	<dict>
		<key>PATH</key>
		<string>$HOME/.homebrew/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
$PROXY_ENV_BLOCK
	</dict>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>StandardOutPath</key>
	<string>$LOG_FILE</string>
	<key>StandardErrorPath</key>
	<string>$LOG_FILE</string>
	<key>ProcessType</key>
	<string>Background</string>
</dict>
</plist>
PEOF
}

cmd_quick_install() {
  echo "📦 安装 Cloudflare quick tunnel LaunchAgent..."
  generate_quick_plist
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$PLIST"
  echo "  ✅ LaunchAgent 已安装"
  echo "  📝 日志: tail -f $LOG_FILE"
  echo "  ⚠️  quick tunnel URL 每次重启会变 — 变后重跑: bash $0 quick-url"
  sleep 5
  grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOG_FILE" 2>/dev/null | head -1 | tee "$URL_FILE" || true
  show_quick_url
}

cmd_setup_named() {
  cat <<EOF

=== 稳定域名（Named Tunnel）===

1) 登录 Cloudflare（会打开浏览器）:
   $CLOUDFLARED tunnel login

2) 创建隧道:
   $CLOUDFLARED tunnel create ceo-feishu-approval

3) 在 Cloudflare DNS 添加 CNAME（Dashboard → Zero Trust → Tunnels）:
   feishu-ceo.<你的域名> → <tunnel-id>.cfargotunnel.com

4) 写入配置 $NAMED_CONFIG（替换 TUNNEL_ID 与 hostname）:

tunnel: <TUNNEL_ID>
credentials-file: $HOME/.cloudflared/<TUNNEL_ID>.json
ingress:
  - hostname: feishu-ceo.example.com
    service: http://127.0.0.1:$PORT
  - service: http_status:404

5) 安装常开:
   bash $0 named-install

6) 飞书 Request URL:
   https://feishu-ceo.<你的域名>/feishu/event

EOF
  if [ ! -f "$NAMED_CONFIG" ]; then
    mkdir -p "$CONFIG_DIR"
    cat >"$NAMED_CONFIG.example" <<EXEOF
# Copy to cloudflared-ceo-feishu.yml and fill TUNNEL_ID + hostname
tunnel: <TUNNEL_ID>
credentials-file: $HOME/.cloudflared/<TUNNEL_ID>.json
ingress:
  - hostname: feishu-ceo.example.com
    service: http://127.0.0.1:$PORT
  - service: http_status:404
EXEOF
    echo "模板已写: $NAMED_CONFIG.example"
  fi
}

generate_named_plist() {
  need_cloudflared
  [ -f "$NAMED_CONFIG" ] || {
    echo "error: missing $NAMED_CONFIG — bash $0 setup-named" >&2
    exit 1
  }
  cat >"$PLIST" <<PEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>$CLOUDFLARED</string>
		<string>tunnel</string>
		<string>--config</string>
		<string>$NAMED_CONFIG</string>
		<string>run</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>StandardOutPath</key>
	<string>$LOG_FILE</string>
	<key>StandardErrorPath</key>
	<string>$LOG_FILE</string>
	<key>ProcessType</key>
	<string>Background</string>
</dict>
</plist>
PEOF
}

cmd_named_install() {
  echo "📦 安装 Cloudflare named tunnel LaunchAgent..."
  generate_named_plist
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$PLIST"
  echo "  ✅ named tunnel LaunchAgent 已安装"
  echo "  飞书 URL: https://<你的hostname>/feishu/event"
}

generate_token_plist() {
  need_cloudflared
  local token="${CLOUDFLARE_TUNNEL_TOKEN:-${TUNNEL_TOKEN:-}}"
  local use_token_file=0
  local token_file_arg=""

  if [ -f "$RUN_TOKEN_FILE" ] && [ -s "$RUN_TOKEN_FILE" ]; then
    use_token_file=1
    token_file_arg="$RUN_TOKEN_FILE"
  elif [ -n "$token" ] && [[ "$token" != YOUR_* ]]; then
    use_token_file=0
  else
    echo "error: no tunnel run credential" >&2
    echo "  推荐: 在 local.env 设 CLOUDFLARE_API_TOKEN + CLOUDFLARE_TUNNEL_NAME，然后:" >&2
    echo "    bash $0 fetch-run-token" >&2
    echo "  或设 CLOUDFLARE_TUNNEL_TOKEN（仅 tunnel 的 run token，不是 Account API Token）" >&2
    exit 1
  fi

  proxy_env_for_plist
  if [ "$use_token_file" -eq 1 ]; then
    cat >"$PLIST" <<PEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>$CLOUDFLARED</string>
		<string>tunnel</string>
		<string>--protocol</string>
		<string>http2</string>
		<string>run</string>
		<string>--token-file</string>
		<string>$token_file_arg</string>
	</array>
	<key>EnvironmentVariables</key>
	<dict>
		<key>PATH</key>
		<string>$HOME/.homebrew/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
$PROXY_ENV_BLOCK
	</dict>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>StandardOutPath</key>
	<string>$LOG_FILE</string>
	<key>StandardErrorPath</key>
	<string>$LOG_FILE</string>
	<key>ProcessType</key>
	<string>Background</string>
</dict>
</plist>
PEOF
  else
    cat >"$PLIST" <<PEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>$CLOUDFLARED</string>
		<string>tunnel</string>
		<string>--protocol</string>
		<string>http2</string>
		<string>run</string>
		<string>--token</string>
		<string>$token</string>
	</array>
	<key>EnvironmentVariables</key>
	<dict>
		<key>PATH</key>
		<string>$HOME/.homebrew/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
$PROXY_ENV_BLOCK
	</dict>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>StandardOutPath</key>
	<string>$LOG_FILE</string>
	<key>StandardErrorPath</key>
	<string>$LOG_FILE</string>
	<key>ProcessType</key>
	<string>Background</string>
</dict>
</plist>
PEOF
  fi
}

cmd_token_install() {
  echo "📦 安装 Cloudflare tunnel LaunchAgent..."
  generate_token_plist
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$PLIST"
  echo "  ✅ token tunnel LaunchAgent 已安装"
  echo "  在 Zero Trust 把 public hostname 指到 http://127.0.0.1:$PORT"
  echo "  飞书 Request URL: https://<你的固定域名>/feishu/event"
}

cmd_fetch_run_token() {
  need_cloudflared
  local api="${CLOUDFLARE_API_TOKEN:-}"
  local name="${CLOUDFLARE_TUNNEL_NAME:-ceo-feishu-approval}"
  if [ -z "$api" ] || [[ "$api" == YOUR_* ]]; then
    echo "error: set CLOUDFLARE_API_TOKEN in .ai-company/config/local.env" >&2
    echo "  这是 Account API Token（高权限）— 仅用于一次性换取 tunnel run token" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$RUN_TOKEN_FILE")"
  echo ">> cloudflared tunnel token $name"
  if ! CLOUDFLARE_API_TOKEN="$api" "$CLOUDFLARED" tunnel token "$name" >"$RUN_TOKEN_FILE"; then
    echo "error: fetch failed — check API token permissions (Cloudflare Tunnel: Read) and tunnel name" >&2
    rm -f "$RUN_TOKEN_FILE"
    exit 1
  fi
  chmod 600 "$RUN_TOKEN_FILE"
  echo "  ✅ scoped run token → $RUN_TOKEN_FILE"
  echo "  ⚠️  不要把 Account API Token 写进 LaunchAgent；可注释掉 local.env 里的 CLOUDFLARE_API_TOKEN"
  echo "  下一步: bash $0 token-install"
}

cmd_uninstall() {
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  rm -f "$PLIST"
  echo "  ✅ tunnel LaunchAgent 已卸载"
}

cmd_status() {
  echo "📊 Cloudflare tunnel + 飞书回调"
  if launchctl print "gui/$(id -u)/$LABEL" &>/dev/null; then
    PID="$(launchctl print "gui/$(id -u)/$LABEL" 2>/dev/null | awk '/pid =/ {print $3; exit}')"
    echo "  🟢 tunnel LaunchAgent (pid ${PID:-?})"
  else
    pgrep -fl cloudflared >/dev/null && echo "  🟡 cloudflared 手动进程" || echo "  ⚪ tunnel 未运行"
  fi
  bash "$SCRIPT_DIR/ceo-feishu-approval-service.sh" status
  show_quick_url
}

cmd_logs() {
  tail -f "$LOG_FILE"
}

case "${1:-}" in
  quick) capture_quick_url ;;
  quick-install) cmd_quick_install ;;
  quick-url) show_quick_url ;;
  login) need_cloudflared; "$CLOUDFLARED" tunnel login ;;
  setup-named) cmd_setup_named ;;
  named-install) cmd_named_install ;;
  token-install) cmd_token_install ;;
  fetch-run-token) cmd_fetch_run_token ;;
  uninstall) cmd_uninstall ;;
  status) cmd_status ;;
  logs) cmd_logs ;;
  -h|--help|help|"") usage ;;
  *) echo "Unknown command: $1" >&2; usage >&2; exit 1 ;;
esac
