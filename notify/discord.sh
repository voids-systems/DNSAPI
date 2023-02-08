#!/usr/bin/env sh

#Support Discord webhooks

#DISCORD_WEBHOOK_URL=""
#DISCORD_CHANNEL=""
#DISCORD_USERNAME=""

discord_send() {
  _subject="$1"
  _content="$2"
  _statusCode="$3" #0: success, 1: error 2($RENEW_SKIP): skipped
  _debug "_statusCode" "$_statusCode"

  DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-$(_readaccountconf_mutable DISCORD_WEBHOOK_URL)}"
  if [ -z "$DISCORD_WEBHOOK_URL" ]; then
    DISCORD_WEBHOOK_URL=""
    _err "You didn't specify a Discord webhook url DISCORD_WEBHOOK_URL yet."
    return 1
  fi
  _saveaccountconf_mutable DISCORD_WEBHOOK_URL "$DISCORD_WEBHOOK_URL"

  DISCORD_CHANNEL="${DISCORD_CHANNEL:-$(_readaccountconf_mutable DISCORD_CHANNEL)}"
  if [ -n "$DISCORD_CHANNEL" ]; then
    _saveaccountconf_mutable DISCORD_CHANNEL "$DISCORD_CHANNEL"
  fi

  DISCORD_USERNAME="${DISCORD_USERNAME:-$(_readaccountconf_mutable DISCORD_USERNAME)}"
  if [ -n "$DISCORD_USERNAME" ]; then
    _saveaccountconf_mutable DISCORD_USERNAME "$DISCORD_USERNAME"
  fi

  export _H1="Content-Type: application/json"

  _content="$(printf "*%s*\n%s" "$_subject" "$_content" | _json_encode)"
  _data="{\"text\": \"$_content\", "
  if [ -n "$DISCORD_CHANNEL" ]; then
    _data="$_data\"channel\": \"$DISCORD_CHANNEL\", "
  fi
  if [ -n "$DISCORD_USERNAME" ]; then
    _data="$_data\"username\": \"$DISCORD_USERNAME\", "
  fi
  _data="$_data\"mrkdwn\": \"true\"}"

  if _post "$_data" "$DISCORD_WEBHOOK_URL"; then
    # shellcheck disable=SC2154
    if [ "$response" = "ok" ]; then
      _info "discord send success."
      return 0
    fi
  fi
  _err "discord send error."
  _err "$response"
  return 1
}
