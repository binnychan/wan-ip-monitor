#!/bin/sh
# Location /usr/bin/wan-ip-monitor.sh
# WAN IP Monitor for OpenWrt (IPv4 + IPv6) with history logging & CLI option
# Works in both hotplug and cron modes
# Author: ChatGPT

# --- User Configurable Variables ---
HISTORY_LIMIT=10  # Number of historical entries to keep
HISTORY_FILE="/etc/wan_ip_history.log"  # Persistent log file

LAST_IP4_FILE="/tmp/last_wan_ipv4"
LAST_IP6_FILE="/tmp/last_wan_ipv6"

telegramBotID="YOUR_BOT_TOKEN"
telegramChatID="YOUR_CHAT_ID"

# --- Functions ---

# Get current WAN IPv4
get_wan_ipv4() {
    ifstatus wan 2>/dev/null | jsonfilter -e '@["ipv4-address"][0].address'
}

# Get current WAN IPv6 (global scope)
get_wan_ipv6() {
    ifstatus wan6 2>/dev/null | jsonfilter -e '@["ipv6-address"][0].address'
}

# Append to history log and trim to HISTORY_LIMIT
log_history() {
    local proto="$1"
    local old_ip="$2"
    local new_ip="$3"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    echo "$timestamp | $proto changed from $old_ip to $new_ip" >> "$HISTORY_FILE"

    # Trim file to last N lines
    if [ "$(wc -l < "$HISTORY_FILE")" -gt "$HISTORY_LIMIT" ]; then
        tail -n "$HISTORY_LIMIT" "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
    fi
}

# Send notifications (supports combined IPv4/IPv6 changes)
send_notification() {
    local msg="$1"
    logger -t wan-ip-monitor "$msg"

    # Email example (requires msmtp/mailutils configured)
    # echo "$msg" | mail -s "OpenWrt WAN IP Change" you@example.com

    # Pushover example (requires curl)
    # curl -s \
    #   -F "token=YOUR_PUSHOVER_APP_TOKEN" \
    #   -F "user=YOUR_PUSHOVER_USER_KEY" \
    #   -F "message=$msg" \
    #   https://api.pushover.net/1/messages.json

    # Webhook example (Slack/Discord)
    # curl -s -X POST -H "Content-Type: application/json" \
    #   -d "{\"text\": \"$msg\"}" \
    #   https://your.webhook.url

    # Telegram example
    curl -s -X POST "https://api.telegram.org/bot$telegramBotID/sendMessage" \
            -d chat_id="$telegramChatID" -d text="$msg" > /dev/null
}

# Show history
show_history() {
    if [ -f "$HISTORY_FILE" ]; then
        echo "=== WAN IP Change History (last $HISTORY_LIMIT entries) ==="
        cat "$HISTORY_FILE"
    else
        echo "No history found."
    fi
}

# --- Main Execution ---
# CLI options
case "$1" in
    history)
        show_history
        exit 0
        ;;
    clear-history)
        > "$HISTORY_FILE"
        echo "History cleared."
        exit 0
        ;;
esac

# If run by hotplug, only act on WAN interface events
if [ -n "$INTERFACE" ]; then
    [ "$INTERFACE" = "wan" ] || exit 0
fi

# Get current IPs
CURRENT_IP4=$(get_wan_ipv4)
CURRENT_IP6=$(get_wan_ipv6)

# Check for changes and build notification message
CHANGED=0
NOTIFICATION_MSG=""

# Check IPv4
if [ -f "$LAST_IP4_FILE" ]; then
    LAST_IP4=$(cat "$LAST_IP4_FILE")
else
    LAST_IP4=""
fi

if [ -n "$CURRENT_IP4" ] && [ "$CURRENT_IP4" != "$LAST_IP4" ]; then
    CHANGED=1
    NOTIFICATION_MSG="IPv4: $LAST_IP4 → $CURRENT_IP4"
    echo "$CURRENT_IP4" > "$LAST_IP4_FILE"
    log_history "IPv4" "$LAST_IP4" "$CURRENT_IP4"
fi

# Check IPv6
if [ -f "$LAST_IP6_FILE" ]; then
    LAST_IP6=$(cat "$LAST_IP6_FILE")
else
    LAST_IP6=""
fi

if [ -n "$CURRENT_IP6" ] && [ "$CURRENT_IP6" != "$LAST_IP6" ]; then
    if [ $CHANGED -eq 1 ]; then
        NOTIFICATION_MSG="$NOTIFICATION_MSG"$'\n'"IPv6: $LAST_IP6 → $CURRENT_IP6"
    else
        NOTIFICATION_MSG="IPv6: $LAST_IP6 → $CURRENT_IP6"
    fi
    CHANGED=1
    echo "$CURRENT_IP6" > "$LAST_IP6_FILE"
    log_history "IPv6" "$LAST_IP6" "$CURRENT_IP6"
fi

# Send single notification if any change detected
if [ $CHANGED -eq 1 ]; then
    send_notification $'WAN IP Change\n'"$NOTIFICATION_MSG"
fi
