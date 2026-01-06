import requests
import time
import sys


BOT_TOKEN = "InsertYourBotTokenFromBotFatherHere"
BASE_URL = f"https://api.telegram.org/bot{BOT_TOKEN}"

# Store bot info for mention detection
bot_username = None
bot_id = None


# --- Check connection ---
def check_connection():
    global bot_username, bot_id
    try:
        r = requests.get(f"{BASE_URL}/getMe", timeout=5)
        r.raise_for_status()
        data = r.json()

        if not data.get("ok"):
            print("❌ Telegram API responded but bot is NOT OK")
            return False

        bot = data["result"]
        bot_username = bot.get("username")
        bot_id = bot["id"]
        print(f"Connected as @{bot_username} (id={bot_id})")
        return True

    except requests.exceptions.RequestException as e:
        print("Failed to connect to Telegram API")
        print(e)
        return False


def is_bot_mentioned_or_command(msg, debug=False):
    """Check if message mentions the bot or contains a command."""
    if not msg:
        return False
    
    text = msg.get("text") or msg.get("caption", "")
    
    # Check if message is a reply to the bot's message
    reply_to = msg.get("reply_to_message")
    if reply_to:
        reply_from = reply_to.get("from")
        if reply_from and reply_from.get("id") == bot_id:
            if debug:
                print(f"  [DEBUG] Message is a reply to bot")
            return True
    
    # Check if message is a command (starts with /)
    if text and text.startswith("/"):
        if debug:
            print(f"  [DEBUG] Message is a command: {text[:20]}")
        return True
    
    # Check entities for mentions or bot commands
    entities = msg.get("entities", []) or msg.get("caption_entities", [])
    if entities:
        for entity in entities:
            entity_type = entity.get("type")
            
            if entity_type == "mention":
                # Extract the mentioned username from text
                start = entity.get("offset", 0)
                length = entity.get("length", 0)
                if text and start + length <= len(text):
                    mentioned = text[start:start + length]
                    if debug:
                        print(f"  [DEBUG] Found mention entity: '{mentioned}'")
                    # Check if it matches bot username (case insensitive)
                    if mentioned and bot_username:
                        if mentioned.lower() == f"@{bot_username}".lower():
                            if debug:
                                print(f"  [DEBUG] Mention matches bot username!")
                            return True
                # Also check if entity has user field pointing to bot
                entity_user = entity.get("user")
                if entity_user and entity_user.get("id") == bot_id:
                    if debug:
                        print(f"  [DEBUG] Entity user ID matches bot ID!")
                    return True
                    
            elif entity_type == "bot_command":
                if debug:
                    print(f"  [DEBUG] Found bot_command entity")
                return True
                
            elif entity_type == "text_mention":
                # Text mention with user object
                entity_user = entity.get("user")
                if entity_user and entity_user.get("id") == bot_id:
                    if debug:
                        print(f"  [DEBUG] Text mention matches bot ID!")
                    return True
    
    # Check if bot is mentioned in text (fallback - case insensitive)
    if text and bot_username:
        if f"@{bot_username}".lower() in text.lower():
            if debug:
                print(f"  [DEBUG] Bot username found in text (fallback)")
            return True
    
    return False


if not check_connection():
    sys.exit(1)


offset = 0
seen_locations = {}  # Key: (chat_id, topic_id or None)
DEBUG = "--debug" in sys.argv  # Enable debug mode with --debug flag

print("Listening for mentions and commands (Ctrl+C to stop)...\n")
print("The bot will only show chats/topics where it's mentioned or receives commands")
if DEBUG:
    print("DEBUG MODE: Showing all incoming messages\n")
else:
    print("Tip: Run with --debug flag to see all incoming messages\n")

try:
    while True:
        r = requests.get(
            f"{BASE_URL}/getUpdates",
            params={
                "offset": offset,
                "timeout": 30   # long polling
            },
            timeout=35
        ).json()

        for update in r.get("result", []):
            offset = update["update_id"] + 1

            msg = update.get("message") or update.get("channel_post") or update.get("edited_message")
            if not msg:
                continue

            chat = msg["chat"]
            chat_id = chat["id"]
            name = chat.get("title") or chat.get("username") or chat.get("first_name") or "Unknown"
            chat_type = chat["type"]
            text = msg.get("text") or msg.get("caption", "")
            topic_id = msg.get("message_thread_id")
            
            # Debug: show all messages
            if DEBUG:
                print(f"[DEBUG] Received message in {chat_type} '{name}' (ID: {chat_id})")
                if topic_id:
                    print(f"  Topic ID: {topic_id}")
                if text:
                    print(f"  Text: {text[:50]}")
                entities = msg.get("entities", []) or msg.get("caption_entities", [])
                if entities:
                    print(f"  Entities: {entities}")

            # Only process messages that mention the bot or are commands
            if not is_bot_mentioned_or_command(msg, debug=DEBUG):
                if DEBUG:
                    print(f"  [DEBUG] Message does NOT mention bot or is a command - skipping\n")
                continue

            if DEBUG:
                print(f"  [DEBUG] ✓ Message mentions bot or is a command!\n")

            # Create unique key for chat + topic combination
            location_key = (chat_id, topic_id)
            
            # Determine what triggered this (command or mention)
            trigger_type = "command" if text and text.startswith("/") else "mention"
            reply_to = msg.get("reply_to_message")
            if reply_to:
                if reply_to.get("from", {}).get("id") == bot_id:
                    trigger_type = "reply"
            
            # Only print when we see a NEW location (chat or chat+topic)
            if location_key not in seen_locations:
                seen_locations[location_key] = {
                    "name": name,
                    "type": chat_type,
                    "topic_id": topic_id,
                    "trigger_type": trigger_type
                }
                
                if topic_id:
                    print(f"👀 New forum topic: Chat ID: {chat_id} | Topic ID: {topic_id} | {chat_type} | {name} | Trigger: {trigger_type}")
                else:
                    print(f"👀 New chat: {chat_id} | {chat_type} | {name} | Trigger: {trigger_type}")

        time.sleep(0.1)

except KeyboardInterrupt:
    print("\nStopped by user (Ctrl+C)")

finally:
    print("\nLocations where bot was mentioned or received commands:\n")
    if not seen_locations:
        print("No mentions or commands captured.")
    else:
        for (chat_id, topic_id), info in seen_locations.items():
            if topic_id:
                print(f"Chat ID: {chat_id} | Topic ID: {topic_id} | {info['type']} | {info['name']} | Trigger: {info['trigger_type']}")
            else:
                print(f"Chat ID: {chat_id} | {info['type']} | {info['name']} | Trigger: {info['trigger_type']}")
