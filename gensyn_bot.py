# 🧠 Same imports and DB setup as before
import os
import sqlite3
import requests
import re
from datetime import datetime, timezone
from dotenv import load_dotenv
from telegram import Update
from telegram.ext import (
    ApplicationBuilder, CommandHandler, ContextTypes, CallbackContext
)

load_dotenv()
TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
API_URL = "https://dashboard-math.gensyn.ai/api/v1/peer"
DB_FILE = "gensyn_bot.db"
ADMIN_ID = 5173961121

def get_db_connection():
    return sqlite3.connect(DB_FILE)

def init_db():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS user_peers (
            user_id INTEGER,
            peer_id TEXT,
            score INTEGER,
            reward INTEGER,
            PRIMARY KEY (user_id, peer_id)
        )
    """)
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS user_registry (
            user_id INTEGER PRIMARY KEY,
            joined_at TEXT
        )
    """)
    conn.commit()
    conn.close()

def fetch_peer_data(peer_id):
    try:
        res = requests.get(API_URL, params={"id": peer_id}, timeout=10)
        res.raise_for_status()
        return res.json()
    except Exception as e:
        print(f"API Error {peer_id}: {e}")
        return None

def register_user(user_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("INSERT OR IGNORE INTO user_registry (user_id, joined_at) VALUES (?, ?)",
                   (user_id, datetime.now(timezone.utc).date().isoformat()))
    conn.commit()
    conn.close()

def escape_markdown_v2(text):
    escape_chars = r"_*[]()~`>#+-=|{}.!\\"  # must be raw for proper escaping
    return re.sub(r'([%s])' % re.escape(escape_chars), r'\\\1', str(text))

# --- Commands ---
async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    register_user(user_id)
    message = (
        "🤖 *Gensyn Rewards Bot* Created By [Kind Crypto](https://t.me/kind_cr)\n\n"
        "📩 For help, DM [@imysryasir](https://t.me/imysryasir)\n\n"
        "📘 *Commands:*\n"
        "• `/peer <id1,id2,...>` — Add peer IDs\n"
        "• `/status` — View your peers and scores\n"
        "• `/remove <id1,id2,...>` — Remove peers\n"
    )
    await update.message.reply_text(message, parse_mode='Markdown')

async def whoami(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text(f"Your Telegram ID is: `{update.effective_user.id}`", parse_mode='Markdown')

async def users_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.effective_user.id != ADMIN_ID:
        await update.message.reply_text("❌ Not authorized.")
        return

    today = datetime.now(timezone.utc).date().isoformat()
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT COUNT(DISTINCT user_id) FROM (
            SELECT user_id FROM user_peers
            UNION
            SELECT user_id FROM user_registry
        )
    """)
    total_users = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM user_registry WHERE joined_at = ?", (today,))
    today_users = cursor.fetchone()[0]
    conn.close()

    await update.message.reply_text(
        f"👥 Total Users: {total_users}\n📆 Joined Today: {today_users}"
    )

async def peer_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    register_user(user_id)

    if not context.args:
        await update.message.reply_text("Usage: /peer <peer_id1,peer_id2,...>")
        return

    peer_ids = [x.strip() for x in " ".join(context.args).split(',') if x.strip()]
    added = []
    conn = get_db_connection()
    cursor = conn.cursor()

    for peer_id in peer_ids:
        cursor.execute("SELECT 1 FROM user_peers WHERE user_id = ? AND peer_id = ?", (user_id, peer_id))
        if cursor.fetchone():
            continue
        data = fetch_peer_data(peer_id)
        if data:
            cursor.execute(
                "INSERT OR REPLACE INTO user_peers (user_id, peer_id, score, reward) VALUES (?, ?, ?, ?)",
                (user_id, peer_id, data.get('score', 0), data.get('reward', 0))
            )
            added.append(peer_id)
    conn.commit()
    conn.close()

    if added:
        await update.message.reply_text(f"✅ Added: {', '.join(added)}")
    else:
        await update.message.reply_text("⚠️ No new peer IDs were added.")

async def status_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    register_user(user_id)
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT peer_id, score, reward FROM user_peers WHERE user_id = ?", (user_id,))
    rows = cursor.fetchall()
    conn.close()

    if not rows:
        await update.message.reply_text("No peers being tracked.")
        return
    msg = "📊 *Your Tracked Peers:*\n"
    for peer_id, old_score, old_reward in rows:
        data = fetch_peer_data(peer_id)
        if data:
            msg += (
                f"\n🔹 `{peer_id}`\n"
                f"• Name: {escape_markdown_v2(data.get('peerName', 'N/A'))}\n"
                f"• Score: {data.get('score', 'N/A')} 🏆\n"
                f"• Reward: {data.get('reward', 'N/A')}\n"
                f"• Online: {escape_markdown_v2(str(data.get('online', 'N/A')))}\n"
            )
        else:
            msg += (
                f"\n🔹 `{peer_id}`\n"
                f"• Score: {old_score} 🏆\n"
                f"• Reward: {old_reward}\n"
                f"• (Offline or Error)\n"
            )
    msg +=  "\n\n[*Kind Crypto*](https://t.me/kind_cr)"
    await update.message.reply_text(msg, parse_mode="MarkdownV2", disable_web_page_preview=False)

async def remove_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    if not context.args:
        await update.message.reply_text("Usage: /remove <peer_id1,peer_id2,...>")
        return

    peer_ids = [x.strip() for x in " ".join(context.args).split(',') if x.strip()]
    removed = []

    conn = get_db_connection()
    cursor = conn.cursor()
    for peer_id in peer_ids:
        cursor.execute("DELETE FROM user_peers WHERE user_id = ? AND peer_id = ?", (user_id, peer_id))
        if cursor.rowcount > 0:
            removed.append(peer_id)
    conn.commit()
    conn.close()

    if removed:
        await update.message.reply_text(f"🗑 Removed: {', '.join(removed)}")
    else:
        await update.message.reply_text("⚠️ No matching peers found.")

async def broadcast_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.effective_user.id != ADMIN_ID:
        await update.message.reply_text("❌ Not authorized.")
        return

    if not context.args:
        await update.message.reply_text("Usage: /broadcast <message>")
        return

    message = escape_markdown_v2(" ".join(context.args))

    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT DISTINCT user_id FROM user_peers UNION SELECT user_id FROM user_registry")
    user_ids = [row[0] for row in cursor.fetchall()]
    conn.close()

    success = 0
    for user_id in user_ids:
        try:
            await context.bot.send_message(
                chat_id=user_id,
                text=message,
                parse_mode='MarkdownV2',
                disable_web_page_preview=False
            )
            success += 1
        except Exception as e:
            print(f"Failed to send to {user_id}: {e}")

    await update.message.reply_text(f"📤 Message sent to {success} users.")

# ✅ FIXED MONITOR FUNCTION
async def monitor_scores(context: CallbackContext):
    app = context.application
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT DISTINCT user_id FROM user_peers")
    user_ids = [row[0] for row in cursor.fetchall()]

    for user_id in user_ids:
        cursor.execute("SELECT peer_id, score, reward FROM user_peers WHERE user_id = ?", (user_id,))
        rows = cursor.fetchall()

        updates = []
        for peer_id, old_score, old_reward in rows:
            data = fetch_peer_data(peer_id)
            if not data:
                continue

            new_score = data.get('score', 0)
            new_reward = data.get('reward', 0)
            changed = False

            peer_msg = f"\n🔹 `{peer_id}`"
            if new_reward != old_reward:
                diff = new_reward - old_reward
                diff_str = escape_markdown_v2(f"({f'+{diff}' if diff > 0 else diff})")
                peer_msg += f"\n• Reward: {escape_markdown_v2(new_reward)} {diff_str}"
                changed = True
            if new_score != old_score:
                diff = new_score - old_score
                diff_str = escape_markdown_v2(f"({f'+{diff}' if diff > 0 else diff})")
                peer_msg += f"\n• Score: {escape_markdown_v2(new_score)} {diff_str} 🏆"
                changed = True

            if changed:
                updates.append(peer_msg)
                cursor.execute(
                    "UPDATE user_peers SET score = ?, reward = ? WHERE user_id = ? AND peer_id = ?",
                    (new_score, new_reward, user_id, peer_id)
                )

        if updates:
            msg = "*📈 Peer Updates:*\n" + "\n".join(updates)
            msg += "\n\n[*Kind Crypto*](https://t.me/kind_cr)"
            try:
                await app.bot.send_message(
                    chat_id=user_id,
                    text=msg,
                    parse_mode="MarkdownV2",
                    disable_web_page_preview=True
                )
            except Exception as e:
                print(f"Send fail: {e}")

    conn.commit()
    conn.close()

# --- Main ---
def main():
    init_db()
    app = ApplicationBuilder().token(TOKEN).build()

    app.add_handler(CommandHandler("start", start_command))
    app.add_handler(CommandHandler("whoami", whoami))
    app.add_handler(CommandHandler("users", users_command))
    app.add_handler(CommandHandler("peer", peer_command))
    app.add_handler(CommandHandler("status", status_command))
    app.add_handler(CommandHandler("remove", remove_command))
    app.add_handler(CommandHandler("broadcast", broadcast_command))

    app.job_queue.run_repeating(monitor_scores, interval=3600, first=10)
    print("✅ Bot running...")
    app.run_polling()

if __name__ == "__main__":
    main()
