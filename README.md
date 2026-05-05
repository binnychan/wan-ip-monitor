# WAN IP Monitor for OpenWrt

A lightweight shell script that monitors WAN IPv4 and IPv6 address changes on OpenWrt routers and sends notifications when changes occur.

## Features

- **Dual Protocol Support**: Monitors both IPv4 and IPv6 addresses
- **Combined Notifications**: Sends a single notification when either or both IPs change
- **History Logging**: Keeps a persistent log of all IP changes (last 10 entries by default)
- **Multiple Notification Methods**: 
  - Telegram (pre-configured)
  - Email (msmtp/mailutils)
  - Pushover
  - Webhooks (Slack/Discord)
  - System logger
- **Flexible Execution Modes**:
  - Hotplug mode (triggered on interface changes)
  - Cron mode (periodic checks)
  - Manual CLI usage
- **Low Resource Usage**: Simple shell script, minimal dependencies

## Installation

### 1. Copy the main script
```bash
cp wan-ip-monitor.sh /usr/bin/wan-ip-monitor.sh
chmod +x /usr/bin/wan-ip-monitor.sh
```

### 2. Set up hotplug trigger (optional but recommended)
```bash
cp 99-wan-ip-monitor /etc/hotplug.d/iface/99-wan-ip-monitor
chmod +x /etc/hotplug.d/iface/99-wan-ip-monitor
```

### 3. For periodic monitoring (optional)
Add to crontab:
```bash
*/5 * * * * /usr/bin/wan-ip-monitor.sh
```

## Configuration

Edit `/usr/bin/wan-ip-monitor.sh` and modify these variables:

### History Settings
```bash
HISTORY_LIMIT=10                           # Number of entries to keep
HISTORY_FILE="/etc/wan_ip_history.log"    # Log file location
```

### Temporary Files
```bash
LAST_IP4_FILE="/tmp/last_wan_ipv4"        # Stores last IPv4
LAST_IP6_FILE="/tmp/last_wan_ipv6"        # Stores last IPv6
```

### Telegram Notifications (enabled by default)
```bash
telegramBotID="YOUR_BOT_TOKEN"
telegramChatID="YOUR_CHAT_ID"
```

To get your Telegram credentials:
1. Create a bot via [@BotFather](https://t.me/botfather) to get the bot token
2. Send a message to your bot and visit `https://api.telegram.org/botYOUR_TOKEN/getUpdates` to find your chat ID

### Other Notification Methods

Uncomment and configure in the `send_notification()` function:

**Email:**
```bash
echo "$msg" | mail -s "OpenWrt WAN IP Change" you@example.com
```

**Pushover:**
```bash
curl -s \
  -F "token=YOUR_PUSHOVER_APP_TOKEN" \
  -F "user=YOUR_PUSHOVER_USER_KEY" \
  -F "message=$msg" \
  https://api.pushover.net/1/messages.json
```

**Webhook (Slack/Discord):**
```bash
curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"text\": \"$msg\"}" \
  https://your.webhook.url
```

## Usage

### Automatic Monitoring
Once installed with hotplug trigger, the script runs automatically when the WAN interface changes.

### Manual Execution
```bash
/usr/bin/wan-ip-monitor.sh
```

### View IP Change History
```bash
/usr/bin/wan-ip-monitor.sh history
```

Output:
```
=== WAN IP Change History (last 10 entries) ===
2024-01-15 10:30:45 | IPv4 changed from 192.168.1.1 to 203.0.113.45
2024-01-15 10:31:12 | IPv6 changed from 2001:db8::1 to 2001:db8::2
```

### Clear History
```bash
/usr/bin/wan-ip-monitor.sh clear-history
```

## Notification Examples

### IPv4 Only Change
```
WAN IP Change
IPv4: 192.168.1.1 → 203.0.113.45
```

### IPv6 Only Change
```
WAN IP Change
IPv6: 2001:db8::1 → 2001:db8::2
```

### Both IPv4 and IPv6 Change
```
WAN IP Change
IPv4: 192.168.1.1 → 203.0.113.45
IPv6: 2001:db8::1 → 2001:db8::2
```

## File Locations

| File | Purpose |
|------|---------|
| `/usr/bin/wan-ip-monitor.sh` | Main monitoring script |
| `/etc/hotplug.d/iface/99-wan-ip-monitor` | Hotplug trigger |
| `/etc/wan_ip_history.log` | IP change history (persistent) |
| `/tmp/last_wan_ipv4` | Last known IPv4 address |
| `/tmp/last_wan_ipv6` | Last known IPv6 address |

## How It Works

1. **Detection**: The script queries the WAN interface status using `ifstatus` and `jsonfilter`
2. **Comparison**: Current IPs are compared against stored values in `/tmp/`
3. **Notification**: If changes are detected, a single combined notification is sent
4. **Logging**: Changes are logged to `/etc/wan_ip_history.log` with timestamps
5. **Cleanup**: History log is automatically trimmed to the configured limit

## Requirements

- OpenWrt router
- `curl` (for Telegram/webhook notifications)
- `mail` or `msmtp` (for email notifications, optional)

## Troubleshooting

### Script not running on interface change
- Verify `99-wan-ip-monitor` is executable: `chmod +x /etc/hotplug.d/iface/99-wan-ip-monitor`
- Check that `/usr/bin/wan-ip-monitor.sh` is executable and has correct path
- Check system logs: `logread | grep wan-ip-monitor`

### Telegram notifications not working
- Verify bot token and chat ID are correct
- Test with `curl`:
  ```bash
  curl -s -X POST "https://api.telegram.org/botYOUR_TOKEN/sendMessage" \
    -d chat_id="YOUR_CHAT_ID" -d text="Test message"
  ```

### IPs not updating
- Check if WAN interface is named `wan` and `wan6`: `ifconfig`
- Verify permissions on temp files: `ls -la /tmp/last_wan_ip*`

## Author

Created by ChatGPT

## License

See LICENSE file in repository
