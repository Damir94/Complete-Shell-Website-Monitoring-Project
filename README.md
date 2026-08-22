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
