#!/bin/sh

set -e

TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
TELEGRAM_MESSAGE_THREAD_ID="${TELEGRAM_MESSAGE_THREAD_ID:-}"  # Optional: thread ID for supergroups
IP_SERVICE="${IP_SERVICE:-cloudflare}"  # Options: cloudflare or ipgeolocation
IPGEOLOCATION_API_KEY="${IPGEOLOCATION_API_KEY:-}"

if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
    echo "Error: TELEGRAM_BOT_TOKEN environment variable is not set" >&2
    exit 1
fi

if [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo "Error: TELEGRAM_CHAT_ID environment variable is not set" >&2
    exit 1
fi

if [ "$IP_SERVICE" != "cloudflare" ] && [ "$IP_SERVICE" != "ipgeolocation" ]; then
    echo "Error: IP_SERVICE must be either 'cloudflare' or 'ipgeolocation'" >&2
    exit 1
fi

if [ "$IP_SERVICE" = "ipgeolocation" ] && [ -z "$IPGEOLOCATION_API_KEY" ]; then
    echo "Error: IPGEOLOCATION_API_KEY is required when IP_SERVICE=ipgeolocation" >&2
    exit 1
fi

get_public_ip_cloudflare() {
    curl -s "https://cloudflare.com/cdn-cgi/trace" | grep -E "^ip=" | cut -d'=' -f2
}

get_ip_info_ipgeolocation() {
    local api_key="$1"
    curl -s "https://api.ipgeolocation.io/ipgeo?apiKey=${api_key}"
}

get_geolocation_info() {
    local ip="$1"
    local api_key="$2"
    
    if [ -z "$api_key" ]; then
        echo "Warning: IPGEOLOCATION_API_KEY not set, skipping geolocation lookup" >&2
        return 1
    fi
    
    curl -s "https://api.ipgeolocation.io/ipgeo?apiKey=${api_key}&ip=${ip}"
}

send_telegram_message() {
    local message="$1"
    local bot_token="$2"
    local chat_id="$3"
    local thread_id="$4"
    
    local url="https://api.telegram.org/bot${bot_token}/sendMessage"
    
    # Build curl command with required parameters
    if [ -n "$thread_id" ]; then
        curl -s -X POST "$url" \
            -d "chat_id=${chat_id}" \
            -d "text=${message}" \
            -d "parse_mode=HTML" \
            -d "message_thread_id=${thread_id}" > /dev/null
    else
        curl -s -X POST "$url" \
            -d "chat_id=${chat_id}" \
            -d "text=${message}" \
            -d "parse_mode=HTML" > /dev/null
    fi
}

main() {
    CITY="Unknown"
    COUNTRY="Unknown"
    
    if [ "$IP_SERVICE" = "cloudflare" ]; then
        echo "Fetching public IP address from Cloudflare..."
        PUBLIC_IP=$(get_public_ip_cloudflare)
        
        if [ -z "$PUBLIC_IP" ]; then
            echo "Error: Failed to retrieve public IP address" >&2
            exit 1
        fi
        
        echo "Public IP: $PUBLIC_IP"
        
        if [ -n "$IPGEOLOCATION_API_KEY" ]; then
            echo "Fetching geolocation information from ipgeolocation.io..."
            GEO_JSON=$(get_geolocation_info "$PUBLIC_IP" "$IPGEOLOCATION_API_KEY")
            
            if [ -n "$GEO_JSON" ]; then
                # Parse JSON using jq
                CITY=$(echo "$GEO_JSON" | jq -r '.city // "Unknown"' 2>/dev/null || echo "Unknown")
                COUNTRY=$(echo "$GEO_JSON" | jq -r '.country_name // "Unknown"' 2>/dev/null || echo "Unknown")
                
                # Handle null values from jq
                if [ "$CITY" = "null" ]; then
                    CITY="Unknown"
                fi
                if [ "$COUNTRY" = "null" ]; then
                    COUNTRY="Unknown"
                fi
            fi
        fi
    elif [ "$IP_SERVICE" = "ipgeolocation" ]; then
        echo "Fetching IP and geolocation information from ipgeolocation.io..."
        GEO_JSON=$(get_ip_info_ipgeolocation "$IPGEOLOCATION_API_KEY")
        
        if [ -z "$GEO_JSON" ]; then
            echo "Error: Failed to retrieve IP information" >&2
            exit 1
        fi
        
        PUBLIC_IP=$(echo "$GEO_JSON" | jq -r '.ip // "Unknown"' 2>/dev/null || echo "Unknown")
        CITY=$(echo "$GEO_JSON" | jq -r '.city // "Unknown"' 2>/dev/null || echo "Unknown")
        COUNTRY=$(echo "$GEO_JSON" | jq -r '.country_name // "Unknown"' 2>/dev/null || echo "Unknown")
        
        if [ "$PUBLIC_IP" = "null" ] || [ -z "$PUBLIC_IP" ]; then
            PUBLIC_IP="Unknown"
        fi
        if [ "$CITY" = "null" ]; then
            CITY="Unknown"
        fi
        if [ "$COUNTRY" = "null" ]; then
            COUNTRY="Unknown"
        fi
        
        echo "Public IP: $PUBLIC_IP"
    fi
    
    MESSAGE="🌐 <b>Box is using the following IP:</b>

📍 <b>IP Address:</b> <code>${PUBLIC_IP}</code>
🏙️ <b>City:</b> ${CITY}
🌍 <b>Country:</b> ${COUNTRY}"
    
    echo "Sending message to Telegram..."
    if send_telegram_message "$MESSAGE" "$TELEGRAM_BOT_TOKEN" "$TELEGRAM_CHAT_ID" "$TELEGRAM_MESSAGE_THREAD_ID"; then
        echo "Message sent successfully!"
    else
        echo "Error: Failed to send Telegram message" >&2
        exit 1
    fi
}

main
