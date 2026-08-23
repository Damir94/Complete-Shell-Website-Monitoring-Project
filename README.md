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
```bash
2026-08-22 10:15:32 | https://example.com | UP | HTTP=200
```

<img width="858" height="106" alt="Screenshot 2026-08-23 at 9 15 45 AM" src="https://github.com/user-attachments/assets/a9d56545-1a10-46b8-a278-7236c55b8665" />

- Congratulations — you now have the basic monitoring system working.
