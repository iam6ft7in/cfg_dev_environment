#!/usr/bin/env python3
"""
send_email.py — Send email via SMTP.

All configuration is loaded from config.json in the same directory.
Copy config.example.json to config.json and fill in your values.

Usage:
    python send_email.py --body TEXT [--to ADDR] [--subject SUBJ] [--html]

Defaults for --to and --subject come from config.json.
"""

import argparse
import json
import os
import smtplib
import subprocess
import sys
from email.message import EmailMessage
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from pathlib import Path


# ---------------------------------------------------------------------------
# Config loading
# ---------------------------------------------------------------------------

SCRIPT_DIR = Path(__file__).parent


def load_config():
    config_path = SCRIPT_DIR / "config.json"
    if not config_path.exists():
        example = SCRIPT_DIR / "config.example.json"
        print(
            f"ERROR: config.json not found in {SCRIPT_DIR}.\n"
            f"Copy {example} to config.json and fill in your values.",
            file=sys.stderr,
        )
        sys.exit(1)
    with open(config_path, encoding="utf-8") as f:
        # Strip keys starting with "_" — used for inline documentation
        raw = json.load(f)
    return strip_doc_keys(raw)


def strip_doc_keys(obj):
    """Recursively remove keys starting with '_' (used as comments in JSON)."""
    if isinstance(obj, dict):
        return {k: strip_doc_keys(v) for k, v in obj.items() if not k.startswith("_")}
    if isinstance(obj, list):
        return [strip_doc_keys(i) for i in obj if not (isinstance(i, str) and i.startswith("_"))]
    return obj


# ---------------------------------------------------------------------------
# Credential retrieval
# ---------------------------------------------------------------------------

def get_credentials(cfg):
    method = cfg["credentials"]["method"]
    if method == "bitwarden":
        return creds_bitwarden(cfg["credentials"]["bitwarden"])
    if method == "env":
        return creds_env(cfg["credentials"]["env"])
    if method == "file":
        return creds_file(cfg["credentials"]["file"])
    print(f"ERROR: Unknown credentials method '{method}'.", file=sys.stderr)
    sys.exit(1)


def creds_bitwarden(bw_cfg):
    exe = bw_cfg["exe"]
    item_name = bw_cfg["item_name"]
    session_vars = bw_cfg.get("session_env_vars", ["BW_SESSION"])

    session = _bw_session(exe, session_vars)
    if not session:
        print(
            "ERROR: Bitwarden vault is locked. Could not obtain a session key.\n"
            "Ensure one of the following:\n"
            "  - Run bw-unlock in your shell to write a session file\n"
            "  - Set BW_SESSION in the environment\n"
            "  - Set BW_PASSWORD + BW_CLIENTID + BW_CLIENTSECRET for fully unattended operation",
            file=sys.stderr,
        )
        sys.exit(1)

    try:
        result = subprocess.run(
            [exe, "get", "item", item_name, "--session", session],
            capture_output=True, text=True, timeout=15,
        )
        if result.returncode != 0:
            print(f"ERROR: Bitwarden lookup failed: {result.stderr.strip()}", file=sys.stderr)
            sys.exit(1)
        item = json.loads(result.stdout)
        return item["login"]["username"], item["login"]["password"]
    except Exception as e:
        print(f"ERROR: Could not retrieve Bitwarden item '{item_name}': {e}", file=sys.stderr)
        sys.exit(1)


SESSION_FILE = Path.home() / ".config" / "bitwarden" / "session"


def _bw_session(exe, session_vars):
    """Obtain a Bitwarden session key via multiple fallback methods."""

    # 1. Check pre-set session env vars (fastest — no subprocess needed)
    for var in session_vars:
        val = os.environ.get(var, "").strip()
        if val:
            return val

    # 2. Check session file (~/.config/bitwarden/session) written by bw-unlock helper
    if SESSION_FILE.exists():
        val = SESSION_FILE.read_text(encoding="utf-8").strip()
        if val:
            return val

    # 3. Unlock using BW_PASSWORD env var (works when already logged in via CLI)
    bw_password = os.environ.get("BW_PASSWORD", "").strip()
    if bw_password:
        session = _try_unlock(exe)
        if session:
            return session

        # Not logged in — attempt API key login first, then unlock
        client_id = os.environ.get("BW_CLIENTID", "").strip()
        client_secret = os.environ.get("BW_CLIENTSECRET", "").strip()
        if client_id and client_secret:
            login = subprocess.run(
                [exe, "login", "--apikey"],
                capture_output=True, text=True, timeout=15,
                env=os.environ.copy(),
            )
            if login.returncode == 0:
                session = _try_unlock(exe)
                if session:
                    return session

    # 4. Fall back to interactive-style unlock via desktop app integration
    return _try_unlock(exe, interactive=True)


def _try_unlock(exe, interactive=False):
    """Run bw unlock and return the session key, or None on failure."""
    cmd = [exe, "unlock", "--raw"]
    if not interactive:
        cmd += ["--passwordenv", "BW_PASSWORD"]
    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=15,
            env=os.environ.copy(),
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    except Exception:
        pass
    return None


def creds_env(env_cfg):
    username_var = env_cfg["username_var"]
    password_var = env_cfg["password_var"]
    username = os.environ.get(username_var, "").strip()
    password = os.environ.get(password_var, "").strip()
    if not username or not password:
        print(
            f"ERROR: Env credential method requires {username_var} and {password_var} to be set.",
            file=sys.stderr,
        )
        sys.exit(1)
    return username, password


def creds_file(file_cfg):
    path = Path(file_cfg["path"]).expanduser()
    if not path.exists():
        print(f"ERROR: Credentials file not found: {path}", file=sys.stderr)
        sys.exit(1)
    line = path.read_text(encoding="utf-8").strip()
    if ":" not in line:
        print(
            f"ERROR: Credentials file must contain a single line in username:password format.",
            file=sys.stderr,
        )
        sys.exit(1)
    username, password = line.split(":", 1)
    return username.strip(), password.strip()


# ---------------------------------------------------------------------------
# Message building and sending
# ---------------------------------------------------------------------------

def build_message(sender, to, subject, body, use_html):
    if use_html:
        msg = MIMEMultipart("alternative")
        msg["Subject"] = subject
        msg["From"] = sender
        msg["To"] = to
        msg.attach(MIMEText(body, "plain"))
        msg.attach(MIMEText(body, "html"))
        return msg
    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = sender
    msg["To"] = to
    msg.set_content(body)
    return msg


def send(smtp_cfg, sender, password, to, subject, body, use_html):
    host = smtp_cfg["host"]
    port = smtp_cfg["port"]
    security = smtp_cfg.get("security", "starttls")
    timeout = smtp_cfg.get("timeout", 30)

    msg = build_message(sender, to, subject, body, use_html)

    if security == "ssl":
        with smtplib.SMTP_SSL(host, port, timeout=timeout) as server:
            server.login(sender, password)
            server.send_message(msg)
    else:  # starttls
        with smtplib.SMTP(host, port, timeout=timeout) as server:
            server.ehlo()
            server.starttls()
            server.ehlo()
            server.login(sender, password)
            server.send_message(msg)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    cfg = load_config()
    defaults = cfg.get("defaults", {})

    parser = argparse.ArgumentParser(description="Send email via SMTP")
    parser.add_argument("--to", default=None, help="Recipient address (default from config)")
    parser.add_argument("--subject", default=None, help="Subject line (default from config)")
    parser.add_argument("--body", required=True, help="Message body")
    parser.add_argument("--html", action="store_true", help="Send as HTML")
    args = parser.parse_args()

    to = args.to or defaults.get("email_to", "")
    subject = args.subject or defaults.get("subject", "Claude Notification")
    sender = defaults.get("from_address", "")

    if not to:
        print("ERROR: No recipient. Set defaults.email_to in config.json or pass --to.", file=sys.stderr)
        sys.exit(1)
    if not sender:
        print("ERROR: No sender. Set defaults.from_address in config.json.", file=sys.stderr)
        sys.exit(1)

    username, password = get_credentials(cfg)

    print(f"Sending email to {to} ...", file=sys.stderr)
    try:
        send(cfg["smtp"], username, password, to, subject, args.body, args.html)
        print("Sent.", file=sys.stderr)
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
