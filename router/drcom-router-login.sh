#!/bin/sh
# Dr.COM / EPortal campus auto-login for stock-router shells (BusyBox ash compatible).
# Designed for routers with curl + crond, e.g. SSH-unlocked Xiaomi stock firmware.
#
# Usage:
#   1. Copy this file to /data/campus-login/login.sh
#   2. Copy router-config.example to /data/campus-login/config and fill credentials
#   3. Add cron: */1 * * * * /data/campus-login/login.sh >/dev/null 2>&1
#
# Security:
#   - Password is read from config but never written to the log.
#   - curl options are passed via a temp config file to avoid exposing password in argv.

set -u

BASE_DIR="${BASE_DIR:-/data/campus-login}"
CONF="$BASE_DIR/config"
LOG="$BASE_DIR/campus-login.log"
PORTAL="/tmp/campus-login-portal.html"
RESP="/tmp/campus-login-response.js"
HEADERS="/tmp/campus-login-response.headers"
CURLCONF="/tmp/campus-login-curl.conf"
CHECK_TMP="/tmp/campus-online-check.html"
CHECK_ERR="/tmp/campus-online-check.err"

mkdir -p "$BASE_DIR"
[ -f "$CONF" ] || { echo "[$(date '+%F %T')] ERROR missing config: $CONF" >> "$LOG"; exit 1; }
. "$CONF"

# HAR-observed Dr.COM 4.x JSONP format: user_account=,0,<username><isp_suffix>
ACCOUNT_PREFIX="${ACCOUNT_PREFIX:-,0,}"
USER_ACCOUNT="${ACCOUNT_PREFIX}${USERNAME}${ISP}"

log() { echo "[$(date '+%F %T')] $*" >> "$LOG"; }

trim_log() {
  if [ -f "$LOG" ]; then
    size=$(wc -c < "$LOG" 2>/dev/null || echo 0)
    if [ "$size" -gt "${MAX_LOG_BYTES:-60000}" ]; then
      tail -c "${KEEP_LOG_BYTES:-40000}" "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"
    fi
  fi
}

extract_sq() {
  key="$1"
  file="$2"
  sed -n "s/.*${key}='\([^']*\)'.*/\1/p" "$file" 2>/dev/null | head -1 | sed 's/[[:space:]]*$//'
}

online_check() {
  rm -f "$CHECK_TMP" "$CHECK_ERR"
  CODE=$(curl -m "${CHECK_TIMEOUT:-5}" -sS -w "%{http_code}" -o "$CHECK_TMP" "$CHECK_URL" 2>"$CHECK_ERR" || echo "curl_fail")
  BYTES=$(wc -c < "$CHECK_TMP" 2>/dev/null || echo 0)
  if grep -qi "${CHECK_KEYWORD:-baidu}" "$CHECK_TMP" 2>/dev/null; then
    log "online_check: OK code=$CODE bytes=$BYTES url=$CHECK_URL"
    return 0
  fi
  ERR=$(head -1 "$CHECK_ERR" 2>/dev/null)
  log "online_check: FAIL code=$CODE bytes=$BYTES url=$CHECK_URL err=${ERR:-none}"
  return 1
}

log_file_head() {
  label="$1"
  file="$2"
  lines="$3"
  log "$label:"
  if [ -s "$file" ]; then
    sed 's/\r$//' "$file" 2>/dev/null | head -"$lines" | while IFS= read -r line; do
      [ -n "$line" ] && log "  $line"
    done
  else
    log "  <empty/missing>"
  fi
}

trim_log
log "---- campus-login start drcom-jsonp ----"

if online_check; then
  log "already online, skip login"
  exit 0
fi

log "offline, trying campus login via Dr.COM JSONP GET"
log "config: username_len=${#USERNAME}, isp=$ISP, account_format=prefix_username_isp, endpoint=$LOGIN_BASE"

rm -f "$PORTAL" "$RESP" "$HEADERS" "$CURLCONF"
PORTAL_CODE=$(curl -m "${PORTAL_TIMEOUT:-8}" -sS -w "%{http_code}" -o "$PORTAL" "$PORTAL_PAGE" 2>/tmp/campus-portal.err || echo "curl_fail")
PORTAL_BYTES=$(wc -c < "$PORTAL" 2>/dev/null || echo 0)
log "portal_fetch: code=$PORTAL_CODE bytes=$PORTAL_BYTES page=$PORTAL_PAGE"

WLAN_IP=$(extract_sq "v46ip" "$PORTAL")
[ -n "$WLAN_IP" ] || WLAN_IP=$(extract_sq "ss5" "$PORTAL")
[ -n "$WLAN_IP" ] || WLAN_IP="${WLAN_USER_IP:-}"
WLAN_MAC=$(extract_sq "ss4" "$PORTAL")
[ -n "$WLAN_MAC" ] || WLAN_MAC="${WLAN_USER_MAC:-000000000000}"
VLAN_ID=$(sed -n 's/.*vlanid="\([^"]*\)".*/\1/p' "$PORTAL" 2>/dev/null | head -1 | sed 's/[[:space:]]*$//')
[ -n "$VLAN_ID" ] || VLAN_ID="${VLAN_ID:-0}"
SS6=$(extract_sq "ss6" "$PORTAL")

log "portal_params: wlan_user_ip=${WLAN_IP:-empty}, wlan_user_mac=${WLAN_MAC:-empty}, vlanid=${VLAN_ID:-empty}, ss6=${SS6:-empty}"

grep -n "authlogin\|v4serip\|v46ip\|vlanid\|ss[1-6]=\|carrier" "$PORTAL" 2>/dev/null | head -12 | while IFS= read -r line; do
  log "portal_hint: $line"
done

umask 077
{
  echo "url = \"$LOGIN_BASE\""
  echo "get"
  echo "max-time = \"${LOGIN_TIMEOUT:-10}\""
  echo "silent"
  echo "show-error"
  echo "dump-header = \"$HEADERS\""
  echo "output = \"$RESP\""
  echo "data-urlencode = \"callback=${JSONP_CALLBACK:-dr1003}\""
  echo "data-urlencode = \"login_method=${LOGIN_METHOD:-1}\""
  echo "data-urlencode = \"user_account=$USER_ACCOUNT\""
  echo "data-urlencode = \"user_password=$PASSWORD\""
  echo "data-urlencode = \"wlan_user_ip=$WLAN_IP\""
  echo "data-urlencode = \"wlan_user_ipv6=${WLAN_USER_IPV6:-}\""
  echo "data-urlencode = \"wlan_user_mac=$WLAN_MAC\""
  echo "data-urlencode = \"wlan_ac_ip=${WLAN_AC_IP:-}\""
  echo "data-urlencode = \"wlan_ac_name=${WLAN_AC_NAME:-}\""
  echo "data-urlencode = \"jsVersion=${JS_VERSION:-4.1.3}\""
  echo "data-urlencode = \"terminal_type=${TERMINAL_TYPE:-1}\""
  echo "data-urlencode = \"lang=${LANG_PRIMARY:-zh-cn}\""
  echo "data-urlencode = \"v=$(date +%S%M)\""
  echo "data-urlencode = \"lang=${LANG_SECONDARY:-zh}\""
} > "$CURLCONF"

LOGIN_CODE=$(curl -K "$CURLCONF" -w "%{http_code}" 2>/tmp/campus-login-curl.err || echo "curl_fail")
rm -f "$CURLCONF"
RESP_BYTES=$(wc -c < "$RESP" 2>/dev/null || echo 0)
log "login_submit: http_code=$LOGIN_CODE response_bytes=$RESP_BYTES method=GET_JSONP password_logged=no"
ERR=$(head -1 /tmp/campus-login-curl.err 2>/dev/null)
[ -n "$ERR" ] && log "curl_error: $ERR"

log_file_head "response_headers" "$HEADERS" 12
log_file_head "response_body_head" "$RESP" 8

sleep "${POST_LOGIN_WAIT:-3}"
if online_check; then
  log "login_result: SUCCESS"
  log "---- campus-login end ----"
  exit 0
fi

if grep -qi "result[^0-9-]*1\|success\|认证成功\|登录成功" "$RESP" 2>/dev/null; then
  log "login_result: RESPONSE_LOOKS_SUCCESSFUL but online_check_failed"
  log "---- campus-login end ----"
  exit 2
fi

log "login_result: FAILED still offline"
log "---- campus-login end ----"
exit 3
