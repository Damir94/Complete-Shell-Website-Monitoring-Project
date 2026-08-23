# Complete-Shell-Website-Monitoring-Project

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


