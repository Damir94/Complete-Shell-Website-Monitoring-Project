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
