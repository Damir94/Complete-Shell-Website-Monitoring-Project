# Complete-Shell-Website-Monitoring-Project

Built a lightweight Bash-based website monitoring and observability system that automatically checks multiple HTTP/HTTPS endpoints using cURL and Cron. Implemented HTTP status validation, SSL verification, DNS/connectivity error detection, response-time monitoring, persistent logging, alert throttling, and recovery notifications. Designed the system with configurable thresholds and modular components to demonstrate core DevOps monitoring and automation principles.

## Architecture

```text
                ┌───────────────┐
                │     Cron      │
                │ Every 10 min  │
                └───────┬───────┘
                        │
                        ▼
                ┌───────────────┐
                │   monitor.sh  │
                └───────┬───────┘
                        │
                ┌───────▼───────┐
                │     cURL      │
                │ HTTP / HTTPS  │
                └───────┬───────┘
                        │
          ┌─────────────┼─────────────┐
          ▼             ▼             ▼
      HTTP Code     Curl Exit      Response Time
          │             │             │
          └─────────────┼─────────────┘
                        ▼
                ┌───────────────┐
                │ Status Logic  │
                └───────┬───────┘
                        │
            ┌───────────┼───────────┐
            ▼           ▼           ▼
           UP          DOWN        SLOW
            │           │           │
            └───────────┼───────────┘
                        ▼
                ┌───────────────┐
                │     Logs      │
                └───────────────┘
                        │
                        ▼
                ┌───────────────┐
                │    Alerts     │
                │     Email     │
                └───────────────┘

```
🗂️ Project Structure

```bash
📦 website-monitor
│
├── 🐚 monitor.sh
│   └── Main monitoring engine
│
├── ⚙️ config/
│   ├── monitor.conf
│   └── monitor.conf.example
│
├── 🌐 includes/
│   └── sites
│       └── Websites to monitor
│
├── 📊 logs/
│   ├── monitor.log
│   └── slow/
│
├── 🧠 tmp/
│   └── status/
│       └── Website state tracking
│
├── 🚫 .gitignore
│
└── 📖 README.md
```
### Step 1 - Create the project
- Run
``` bash
mkdir -p ~/website-monitor/{includes,logs/slow,tmp,config}
cd ~/website-monitor
```
- Check the structure:
```bash
sudo apt update
sudo apt install tree -y
tree
```

- You should have:
```bash
website-monitor/
├── config/
├── includes/
├── logs/
│   └── slow/
└── tmp/
```

### Step 2 — Create the website list

- Create:
```bash
vi includes/sites
```

- For your first test, use websites that you control or public sites you are allowed to monitor. For example:
```bash
https://example.com
https://www.google.com
```

### Step 3 — Install the required tools

- We'll use curl, mailutils, and bc
```bash
sudo apt update
sudo apt install curl mailutils bc -y
```

### Step 4 — Build the basic monitor

- Create:
```bash
vi monitor.sh
```

- Put this in it:
```bash
#!/bin/bash

# Get the directory where the script is located
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Website to test
URL="https://example.com"

# Check HTTP status code
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 10 \
    --max-time 30 \
    "$URL")

if [ "$HTTP_CODE" = "200" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $URL | UP | HTTP=$HTTP_CODE"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $URL | DOWN | HTTP=$HTTP_CODE"
fi
```

- Make it executable:
```bash
chmod +x monitor.sh
```

- Run it:
```bash
./monitor.sh
```

- You should see something similar to:

<img width="858" height="106" alt="Screenshot 2026-08-23 at 9 15 45 AM" src="https://github.com/user-attachments/assets/a9d56545-1a10-46b8-a278-7236c55b8665" />

- Congratulations — you now have the basic monitoring system working.

### Step 5 — Make it monitor multiple websites
- Now we'll replace the single hard-coded URL with the includes/sites file.
- Edit:
```bash
vi monitor.sh
```
- Replace the contents with:
```bash
#!/bin/bash

# Get the directory where the script is located
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Website list
SITES_FILE="$DIR/sites"

# Log file
LOG_FILE="$DIR/logs/monitor.log"

# Make sure the log directory exists
mkdir -p "$DIR/logs"

# Check whether the sites file exists
if [ ! -f "$SITES_FILE" ]; then
    echo "ERROR: Sites file not found: $SITES_FILE"
    exit 1
fi

# Check a website
check_website() {

    local URL="$1"

    # Skip empty lines
    [ -z "$URL" ] && return

    # Perform HTTP request
    RESPONSE=$(curl \
        --connect-timeout 10 \
        --max-time 30 \
        --retry 2 \
        --retry-delay 2 \
        -s \
        -o /dev/null \
        -w "%{http_code},%{exitcode},%{ssl_verify_result},%{time_total}" \
        "$URL")

    # Split response into variables
    IFS=',' read -r HTTP_CODE EXIT_CODE SSL_RESULT RESPONSE_TIME <<< "$RESPONSE"

    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    # Determine status
    if [ "$EXIT_CODE" = "0" ] && [[ "$HTTP_CODE" =~ ^2[0-9][0-9]$ ]]; then

        STATUS="UP"

    elif [ "$EXIT_CODE" = "0" ]; then

        STATUS="HTTP_ERROR"

    else

        STATUS="DOWN"

    fi

    # Create log entry
    LOG_ENTRY="$TIMESTAMP | $URL | $STATUS | HTTP=$HTTP_CODE | CURL_EXIT=$EXIT_CODE | SSL=$SSL_RESULT | RESPONSE_TIME=${RESPONSE_TIME}s"

    echo "$LOG_ENTRY"

    # Write to log
    echo "$LOG_ENTRY" >> "$LOG_FILE"
}

# Read and check every website
while IFS= read -r URL; do

    # Ignore empty lines
    [ -z "$URL" ] && continue

    # Ignore comments
    [[ "$URL" =~ ^# ]] && continue

    check_website "$URL"

done < "$SITES_FILE"
```

- Run:
```bash
./monitor.sh
```
- You should get something like:

<img width="1116" height="89" alt="Screenshot 2026-08-23 at 9 22 56 AM" src="https://github.com/user-attachments/assets/c14c3eb2-d170-464b-ac7b-c8fd223e595b" />

### Step 6 — Check your log
- Run
```bash
cat logs/monitor.log
```
- You now have persistent monitoring history.

### Step 7 — Test a failure
- This is important because you want to demonstrate that your monitoring system actually detects failures.
- Temporarily change:
```bash
vi includes/sites
```
- to
```bash
https://example.com
https://this-domain-does-not-exist-123456.com
```
- Run:
```bash
./monitor.sh
```

<img width="1209" height="74" alt="Screenshot 2026-08-23 at 9 27 47 AM" src="https://github.com/user-attachments/assets/f395ff56-767f-4a27-aaac-89d507e3713f" />

- Curl exit code 6 means it couldn't resolve the host. That's much more useful than simply saying:
```bash
Website is down.
```

### Step 8 — Add proper error messages
- Now we'll make the monitoring system easier to understand.
- Inside check_website(), after:
```bash
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
```
- add
```bash
ERROR_MESSAGE=""

if [ "$EXIT_CODE" = "6" ]; then

    ERROR_MESSAGE="Could not resolve host"

elif [ "$EXIT_CODE" = "7" ]; then

    ERROR_MESSAGE="Failed to connect to host"

elif [ "$EXIT_CODE" = "28" ]; then

    ERROR_MESSAGE="Connection timed out"

elif [ "$EXIT_CODE" = "35" ]; then

    ERROR_MESSAGE="SSL/TLS connection error"

elif [ "$EXIT_CODE" = "60" ]; then

    ERROR_MESSAGE="SSL certificate verification failed"

elif [ "$EXIT_CODE" != "0" ]; then

    ERROR_MESSAGE="Curl error"

fi
```
- Then our log can tell us why the website failed.

<img width="1221" height="73" alt="Screenshot 2026-08-23 at 9 41 00 AM" src="https://github.com/user-attachments/assets/50054307-c489-4ab8-a8c9-f2b6d2020ac7" />

- This is much closer to real-world troubleshooting.

### Step 9 — Create the configuration file
- This version will take you from basic monitoring to a more realistic DevOps monitoring system.
- We'll move settings out of monitor.sh so you don't have to edit the script every time.
- Create:
```
vi config/monitor.conf
```
- Add:
```bash
# Email notification settings
EMAIL_TO="your-email@example.com"
EMAIL_FROM="no-reply@yourdomain.com"

# Monitoring settings
SLOW_THRESHOLD=4
SLOW_CHECKS=5

# Alert throttling
ALERT_INTERVAL=3600

# Timezone
TIMEZONE="America/New_York"
```
- Replace:
```bash
your-email@example.com
```
- with your actual email. For now, you can leave the other settings as they are.

### Step 10 — Build the final monitoring script
- Now let's replace monitor.sh with the more complete version.
```bash
vi monitor.sh
```
- Use:
```bash
#!/bin/bash

# ============================================================
# Website Monitoring System
# ============================================================

set -u

# ------------------------------------------------------------
# Determine script directory
# ------------------------------------------------------------

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

CONFIG_FILE="$DIR/config/monitor.conf"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

# ------------------------------------------------------------
# Files and directories
# ------------------------------------------------------------

SITES_FILE="$DIR/includes/sites"
LOG_DIR="$DIR/logs"
LOG_FILE="$LOG_DIR/monitor.log"
SLOW_DIR="$LOG_DIR/slow"
TMP_DIR="$DIR/tmp"

LAST_EMAIL="$TMP_DIR/last_email_notification"
LAST_TEXT="$TMP_DIR/last_text_notification"

mkdir -p "$LOG_DIR"
mkdir -p "$SLOW_DIR"
mkdir -p "$TMP_DIR"

# ------------------------------------------------------------
# Validate sites file
# ------------------------------------------------------------

if [ ! -f "$SITES_FILE" ]; then
    echo "ERROR: Sites file not found: $SITES_FILE"
    exit 1
fi

# ------------------------------------------------------------
# Get timestamp
# ------------------------------------------------------------

get_timestamp() {
    TZ="$TIMEZONE" date '+%Y-%m-%d %H:%M:%S'
}

# ------------------------------------------------------------
# Send email alert
# ------------------------------------------------------------

send_email_alert() {

    local MESSAGE="$1"

    local CURRENT_TIME
    CURRENT_TIME=$(date +%s)

    # First notification
    if [ ! -f "$LAST_EMAIL" ]; then

        echo "Sending email notification."

        mail \
            -s "Website Monitoring Alert" \
            -a "From: $EMAIL_FROM" \
            "$EMAIL_TO" <<< "$MESSAGE"

        touch "$LAST_EMAIL"

        return
    fi

    # Check when previous alert was sent
    local LAST_TIME
    LAST_TIME=$(stat -c %Y "$LAST_EMAIL")

    local DIFFERENCE
    DIFFERENCE=$((CURRENT_TIME - LAST_TIME))

    # Send only after ALERT_INTERVAL
    if [ "$DIFFERENCE" -ge "$ALERT_INTERVAL" ]; then

        echo "Sending email notification."

        mail \
            -s "Website Monitoring Alert" \
            -a "From: $EMAIL_FROM" \
            "$EMAIL_TO" <<< "$MESSAGE"

        touch "$LAST_EMAIL"

    else

        echo "Email alert throttled."

    fi
}

# ------------------------------------------------------------
# Send recovery notification
# ------------------------------------------------------------

send_recovery_alert() {

    local URL="$1"

    local MESSAGE

    MESSAGE="RECOVERY: $URL is back online.

Time: $(get_timestamp)"

    mail \
        -s "Website Recovery Alert" \
        -a "From: $EMAIL_FROM" \
        "$EMAIL_TO" <<< "$MESSAGE"
}

# ------------------------------------------------------------
# Check individual website
# ------------------------------------------------------------

check_website() {

    local URL="$1"

    echo "Checking: $URL"

    # --------------------------------------------------------
    # Perform HTTP request
    # --------------------------------------------------------

    local RESPONSE

    RESPONSE=$(curl \
        --connect-timeout 20 \
        --max-time 30 \
        --retry 3 \
        --retry-delay 5 \
        -s \
        -o /dev/null \
        -w "%{http_code},%{exitcode},%{ssl_verify_result},%{time_total}" \
        "$URL")

    # --------------------------------------------------------
    # Split curl output
    # --------------------------------------------------------

    IFS=',' read -r HTTP_CODE EXIT_CODE SSL_RESULT RESPONSE_TIME <<< "$RESPONSE"

    local TIMESTAMP
    TIMESTAMP=$(get_timestamp)

    # --------------------------------------------------------
    # Determine website status
    # --------------------------------------------------------

    local STATUS
    local ERROR_MESSAGE=""

    if [ "$EXIT_CODE" = "6" ]; then

        STATUS="DOWN"
        ERROR_MESSAGE="Could not resolve host"

    elif [ "$EXIT_CODE" = "7" ]; then

        STATUS="DOWN"
        ERROR_MESSAGE="Failed to connect to host"

    elif [ "$EXIT_CODE" = "28" ]; then

        STATUS="DOWN"
        ERROR_MESSAGE="Connection timed out"

    elif [ "$EXIT_CODE" = "35" ]; then

        STATUS="DOWN"
        ERROR_MESSAGE="SSL/TLS connection error"

    elif [ "$EXIT_CODE" = "60" ]; then

        STATUS="DOWN"
        ERROR_MESSAGE="SSL certificate verification failed"

    elif [ "$EXIT_CODE" != "0" ]; then

        STATUS="DOWN"
        ERROR_MESSAGE="Curl error"

    elif [[ "$HTTP_CODE" =~ ^2[0-9][0-9]$ ]]; then

        STATUS="UP"

    elif [[ "$HTTP_CODE" =~ ^3[0-9][0-9]$ ]]; then

        STATUS="REDIRECT"

    elif [[ "$HTTP_CODE" =~ ^4[0-9][0-9]$ ]]; then

        STATUS="HTTP_ERROR"
        ERROR_MESSAGE="Client error"

    elif [[ "$HTTP_CODE" =~ ^5[0-9][0-9]$ ]]; then

        STATUS="DOWN"
        ERROR_MESSAGE="Server error"

    else

        STATUS="UNKNOWN"
        ERROR_MESSAGE="Unknown response"

    fi

    # --------------------------------------------------------
    # Check response time
    # --------------------------------------------------------

    local SLOW_FILE

    # Convert URL into a safe filename
    SLOW_FILE="$SLOW_DIR/$(echo "$URL" | sed 's|https\?://||; s|[^a-zA-Z0-9._-]|_|g')"

    if [ "$STATUS" = "UP" ]; then

        if (( $(echo "$RESPONSE_TIME > $SLOW_THRESHOLD" | bc -l) )); then

            echo "$TIMESTAMP | $URL | SLOW | RESPONSE_TIME=${RESPONSE_TIME}s" \
                >> "$SLOW_FILE"

            local SLOW_COUNT

            SLOW_COUNT=$(wc -l < "$SLOW_FILE")

            echo "Website is slow: ${RESPONSE_TIME}s"

            # Alert after consecutive slow checks
            if [ "$SLOW_COUNT" -ge "$SLOW_CHECKS" ]; then

                echo "$TIMESTAMP | $URL | SLOW_ALERT | RESPONSE_TIME=${RESPONSE_TIME}s" \
                    >> "$LOG_FILE"

                local SLOW_MESSAGE

                SLOW_MESSAGE="Website performance alert.

Website: $URL
Status: HTTP $HTTP_CODE
Response time: ${RESPONSE_TIME}s
Threshold: ${SLOW_THRESHOLD}s
Consecutive slow checks: $SLOW_COUNT
Time: $TIMESTAMP"

                send_email_alert "$SLOW_MESSAGE"

                # Reset slow counter
                rm -f "$SLOW_FILE"

            fi

        else

            # Website is healthy again
            rm -f "$SLOW_FILE"

        fi

    else

        # Remove slow counter when site isn't simply slow
        rm -f "$SLOW_FILE"

    fi

    # --------------------------------------------------------
    # Write monitoring log
    # --------------------------------------------------------

    local LOG_ENTRY

    if [ -n "$ERROR_MESSAGE" ]; then

        LOG_ENTRY="$TIMESTAMP | $URL | $STATUS | HTTP=$HTTP_CODE | CURL_EXIT=$EXIT_CODE | SSL=$SSL_RESULT | RESPONSE_TIME=${RESPONSE_TIME}s | ERROR=$ERROR_MESSAGE"

    else

        LOG_ENTRY="$TIMESTAMP | $URL | $STATUS | HTTP=$HTTP_CODE | CURL_EXIT=$EXIT_CODE | SSL=$SSL_RESULT | RESPONSE_TIME=${RESPONSE_TIME}s"

    fi

    echo "$LOG_ENTRY" >> "$LOG_FILE"

    echo "$LOG_ENTRY"

    # --------------------------------------------------------
    # Handle website failure
    # --------------------------------------------------------

    if [ "$STATUS" = "DOWN" ] || [ "$STATUS" = "HTTP_ERROR" ]; then

        local ALERT_MESSAGE

        ALERT_MESSAGE="Website Monitoring Alert

Website: $URL
Status: $STATUS
HTTP code: $HTTP_CODE
Curl exit code: $EXIT_CODE
SSL result: $SSL_RESULT
Response time: ${RESPONSE_TIME}s
Error: $ERROR_MESSAGE
Time: $TIMESTAMP"

        send_email_alert "$ALERT_MESSAGE"

    fi
}

# ------------------------------------------------------------
# Main monitoring loop
# ------------------------------------------------------------

echo "============================================================"
echo "Website Monitoring Started"
echo "Time: $(get_timestamp)"
echo "============================================================"

while IFS= read -r URL; do

    # Ignore empty lines
    [ -z "$URL" ] && continue

    # Ignore comments
    [[ "$URL" =~ ^# ]] && continue

    check_website "$URL"

done < "$SITES_FILE"

echo "============================================================"
echo "Monitoring Complete"
echo "============================================================"
```
- Save it and make sure it's executable:
```bash
chmod +x monitor.sh
```
- If everything is correct, there should be no output. Then run:
```bash
./monitor.sh
```

<img width="1041" height="208" alt="Screenshot 2026-08-25 at 9 43 18 AM" src="https://github.com/user-attachments/assets/896b1a9d-9b69-4733-841a-5cfc0245b38a" />

### Step 11 — Test slow website monitoring
- Our configuration currently says:
```bash
SLOW_THRESHOLD=4
SLOW_CHECKS=5
```
- That means: A website must take longer than 4 seconds for 5 consecutive checks before we send a slow-site alert.
- You can temporarily make testing easier:
```bash
vi config/monitor.conf
```
- Change:
```bash
SLOW_THRESHOLD=4
SLOW_CHECKS=2
```

<img width="1023" height="276" alt="Screenshot 2026-08-25 at 9 49 27 AM" src="https://github.com/user-attachments/assets/c67911dd-43f5-44ba-a221-01a21225ed1b" />

- Now a site must be slow twice. After testing, change it back to:
```bash
SLOW_THRESHOLD=4
SLOW_CHECKS=5
```

### Step 12 — Test HTTP failures
- Change your includes/sites temporarily:
```bash
https://example.com
https://httpstat.us/500
```
- Run:
```bash
./monitor.sh
```
- You should see something similar to:

<img width="1201" height="167" alt="Screenshot 2026-08-25 at 9 53 21 AM" src="https://github.com/user-attachments/assets/132cfa12-605c-45f1-b845-463b10022741" />

- This demonstrates that the script understands the difference between:
```bash
HTTP 200 → healthy
HTTP 500 → server failure
```

### Step 13 — Add cron automation
- Open cron:
```bash
crontab -e
```
- Add:
```bash
*/10 * * * * /home/ubuntu/website-monitor/monitor.sh >> /home/ubuntu/website-monitor/logs/cron.log 2>&1
```
- Thus means:
```bash
*/10 → every 10 minutes
*    → every hour
*    → every day
*    → every month
*    → every weekday
```
- Check the cron job:
```bash
crontab -l
```
- You should see:
```bash
*/10 * * * * /home/ubuntu/website-monitor/monitor.sh >> /home/ubuntu/website-monitor/logs/cron.log 2>&1
```

<img width="1037" height="116" alt="Screenshot 2026-08-25 at 10 04 07 AM" src="https://github.com/user-attachments/assets/250fd8d3-f5ac-4f0b-98ce-88ee24fbda16" />

### Step 14 — Test cron without waiting 10 minutes
- Temporarily change to:
```bash
* * * * *
```
- That runs it every minute.
- Wait a minute and check:
```bash
tail -20 logs/monitor.log
```

<img width="1223" height="147" alt="Screenshot 2026-08-25 at 10 06 47 AM" src="https://github.com/user-attachments/assets/305a62ab-d9bc-4ce5-9db4-267b107f36bd" />


- After confirming it works, change the cron job back to:
```bash
*/10 * * * *
```

### Step 15 — Add a .gitignore
- Create
```bash
vi .gitignore
```
- Add:
```bash
logs/
tmp/
*.log
config/monitor.conf
```
- This is important because you don't want temporary state, logs, or private configuration pushed to GitHub.

### Step 16 — Configure your email
- Edit
```bash
vi config/monitor.con
```
- For example
```bash
EMAIL_TO="yourname@gmail.com"
EMAIL_FROM="no-reply@yourdomain.com"

SLOW_THRESHOLD=4
SLOW_CHECKS=5
ALERT_INTERVAL=3600

TIMEZONE="America/New_York"
```
- Do not commit your real email configuration if you don't want it public.
