#!/usr/bin/env python3
"""
send_email.py, Send email via SMTP.

All configuration is loaded from config.json (or config.{profile}.json
when --profile is given) in the same directory. Copy config.example.json
to config.json and fill in your values.

Usage:
    python send_email.py [--body TEXT | --body-file PATH] \
        [--to ADDR] [--cc ADDR[,...]] [--bcc ADDR[,...]] \
        [--subject SUBJ] [--from ADDR] [--reply-to ADDR] \
        [--html] [--body-html TEXT-or-FILE] \
        [--attach PATH ...] [--bcc-self] \
        [--in-reply-to ID] [--references ID[,ID...]] \
        [--header NAME=VALUE ...] \
        [--profile NAME] [--dry-run]

Defaults for --to and --subject come from config. --cc, --bcc, --reply-to
and --from are optional. Multiple addresses use comma-separated lists.
"""

import argparse
import json
import mimetypes
import os
import smtplib
import subprocess
import sys
from email.message import EmailMessage
from pathlib import Path


SCRIPT_DIR = Path(__file__).parent


# ---------------------------------------------------------------------------
# Config loading
# ---------------------------------------------------------------------------

def load_config(profile=None):
    if profile:
        config_path = SCRIPT_DIR / f"config.{profile}.json"
    else:
        config_path = SCRIPT_DIR / "config.json"
    if not config_path.exists():
        example = SCRIPT_DIR / "config.example.json"
        print(
            f"ERROR: {config_path.name} not found in {SCRIPT_DIR}.\n"
            f"Copy {example} to {config_path.name} and fill in your values.",
            file=sys.stderr,
        )
        sys.exit(1)
    with open(config_path, encoding="utf-8") as f:
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

    for var in session_vars:
        val = os.environ.get(var, "").strip()
        if val:
            return val

    if SESSION_FILE.exists():
        val = SESSION_FILE.read_text(encoding="utf-8").strip()
        if val:
            return val

    bw_password = os.environ.get("BW_PASSWORD", "").strip()
    if bw_password:
        session = _try_unlock(exe)
        if session:
            return session

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

    return _try_unlock(exe, interactive=True)


def _try_unlock(exe, interactive=False):
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
            "ERROR: Credentials file must contain a single line in username:password format.",
            file=sys.stderr,
        )
        sys.exit(1)
    username, password = line.split(":", 1)
    return username.strip(), password.strip()


# ---------------------------------------------------------------------------
# Helpers for argument parsing
# ---------------------------------------------------------------------------

def split_addrs(value):
    """Split a comma-separated address list into a clean list of addresses."""
    if not value:
        return []
    return [a.strip() for a in value.split(",") if a.strip()]


def parse_header_args(values):
    """Parse repeated --header NAME=VALUE flags into (name, value) tuples."""
    headers = []
    for raw in values or []:
        if "=" not in raw:
            print(
                f"ERROR: --header must be in NAME=VALUE form, got: {raw!r}",
                file=sys.stderr,
            )
            sys.exit(1)
        name, value = raw.split("=", 1)
        name = name.strip()
        if not name:
            print(f"ERROR: --header name is empty in: {raw!r}", file=sys.stderr)
            sys.exit(1)
        headers.append((name, value))
    return headers


def read_body_or_file(body_text, body_file):
    """Resolve --body / --body-file into the actual body string."""
    if body_text is not None and body_file is not None:
        print("ERROR: --body and --body-file are mutually exclusive.", file=sys.stderr)
        sys.exit(1)
    if body_file is not None:
        path = Path(body_file).expanduser()
        if not path.exists():
            print(f"ERROR: --body-file not found: {path}", file=sys.stderr)
            sys.exit(1)
        return path.read_text(encoding="utf-8")
    if body_text is None:
        print("ERROR: One of --body or --body-file is required.", file=sys.stderr)
        sys.exit(1)
    return body_text


def read_html_or_file(value):
    """Resolve --body-html: literal text if it does not look like a path,
    otherwise read the file. A value is treated as a path when it points to
    an existing file on disk."""
    if value is None:
        return None
    candidate = Path(value).expanduser()
    if candidate.exists() and candidate.is_file():
        return candidate.read_text(encoding="utf-8")
    return value


# ---------------------------------------------------------------------------
# Message building and sending
# ---------------------------------------------------------------------------

def build_message(*, sender, from_override, to_list, cc_list, reply_to,
                  subject, body_text, body_html, attachments,
                  in_reply_to, references, extra_headers):
    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"]    = from_override or sender
    msg["To"]      = ", ".join(to_list)
    if cc_list:
        msg["Cc"] = ", ".join(cc_list)
    if reply_to:
        msg["Reply-To"] = reply_to
    if in_reply_to:
        msg["In-Reply-To"] = in_reply_to
    if references:
        # References is a space-separated list per RFC 5322; the CLI takes
        # them comma-separated for ergonomics.
        msg["References"] = " ".join(split_addrs(references))
    for name, value in extra_headers:
        msg[name] = value

    # Note: Bcc is intentionally not added to the message headers. The
    # envelope recipients passed to send_message() handle delivery; adding
    # a Bcc header would expose blind recipients to other recipients.

    if body_html and body_text:
        msg.set_content(body_text)
        msg.add_alternative(body_html, subtype="html")
    elif body_html:
        msg.set_content(body_html, subtype="html")
    else:
        msg.set_content(body_text)

    for attach_path in attachments:
        path = Path(attach_path).expanduser()
        if not path.exists():
            print(f"ERROR: --attach file not found: {path}", file=sys.stderr)
            sys.exit(1)
        ctype, encoding = mimetypes.guess_type(str(path))
        if ctype is None or encoding is not None:
            ctype = "application/octet-stream"
        maintype, subtype = ctype.split("/", 1)
        with open(path, "rb") as f:
            msg.add_attachment(
                f.read(), maintype=maintype, subtype=subtype,
                filename=path.name,
            )

    return msg


def send(smtp_cfg, sender, password, msg, envelope_recipients, *, dry_run=False):
    if dry_run:
        print("=== DRY RUN, message NOT sent ===",                            file=sys.stderr)
        print(f"  Envelope sender    : {sender}",                              file=sys.stderr)
        print(f"  Envelope recipients: {', '.join(envelope_recipients)}",      file=sys.stderr)
        print("--- begin message ---",                                          file=sys.stderr)
        sys.stderr.write(msg.as_string())
        print("\n--- end message ---",                                          file=sys.stderr)
        return

    host = smtp_cfg["host"]
    port = smtp_cfg["port"]
    security = smtp_cfg.get("security", "starttls")
    timeout = smtp_cfg.get("timeout", 30)

    if security == "ssl":
        with smtplib.SMTP_SSL(host, port, timeout=timeout) as server:
            server.login(sender, password)
            server.send_message(msg, from_addr=sender, to_addrs=envelope_recipients)
    else:
        with smtplib.SMTP(host, port, timeout=timeout) as server:
            server.ehlo()
            server.starttls()
            server.ehlo()
            server.login(sender, password)
            server.send_message(msg, from_addr=sender, to_addrs=envelope_recipients)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Send email via SMTP")
    body_group = parser.add_mutually_exclusive_group(required=False)
    body_group.add_argument("--body",      default=None, help="Message body (plain text)")
    body_group.add_argument("--body-file", default=None, help="Read body from a file")
    parser.add_argument("--body-html",   default=None, help="HTML body or path to HTML file (sent alongside --body for multipart/alternative)")
    parser.add_argument("--html",        action="store_true", help="Treat --body as HTML (back-compat shortcut for --body-html)")
    parser.add_argument("--to",          default=None, help="Recipient address (default from config)")
    parser.add_argument("--cc",          default=None, help="Comma-separated CC recipients")
    parser.add_argument("--bcc",         default=None, help="Comma-separated BCC recipients (not added as a header)")
    parser.add_argument("--bcc-self",    action="store_true", help="BCC the configured sender for an archival copy")
    parser.add_argument("--from",        dest="from_addr", default=None, help="Override the From header and envelope sender")
    parser.add_argument("--reply-to",    default=None, help="Reply-To header")
    parser.add_argument("--subject",     default=None, help="Subject line (default from config)")
    parser.add_argument("--attach",      action="append", default=[], help="File to attach; repeat for multiple")
    parser.add_argument("--in-reply-to", default=None, help="In-Reply-To header (a Message-ID)")
    parser.add_argument("--references",  default=None, help="References header (comma-separated Message-IDs; emitted space-separated)")
    parser.add_argument("--header",      action="append", default=[], help="Extra header NAME=VALUE; repeat for multiple")
    parser.add_argument("--profile",     default=None, help="Use config.{profile}.json instead of config.json")
    parser.add_argument("--dry-run",     action="store_true", help="Print the message that would be sent and exit")
    args = parser.parse_args()

    cfg = load_config(args.profile)
    defaults = cfg.get("defaults", {})

    body_text = read_body_or_file(args.body, args.body_file)
    body_html = read_html_or_file(args.body_html)
    if args.html and body_html is None:
        # Back-compat: --html alone means treat --body as HTML.
        body_html = body_text
        body_text = None

    to_list = split_addrs(args.to or defaults.get("email_to", ""))
    if not to_list:
        print("ERROR: No recipient. Set defaults.email_to in config or pass --to.", file=sys.stderr)
        sys.exit(1)

    cc_list  = split_addrs(args.cc)
    bcc_list = split_addrs(args.bcc)

    sender = defaults.get("from_address", "")
    if not sender:
        print("ERROR: No sender. Set defaults.from_address in config.", file=sys.stderr)
        sys.exit(1)

    if args.bcc_self and sender not in bcc_list:
        bcc_list.append(sender)

    subject = args.subject or defaults.get("subject", "Claude Notification")
    headers = parse_header_args(args.header)

    msg = build_message(
        sender=sender,
        from_override=args.from_addr,
        to_list=to_list,
        cc_list=cc_list,
        reply_to=args.reply_to,
        subject=subject,
        body_text=body_text,
        body_html=body_html,
        attachments=args.attach,
        in_reply_to=args.in_reply_to,
        references=args.references,
        extra_headers=headers,
    )

    envelope_recipients = list(to_list) + list(cc_list) + list(bcc_list)

    if args.dry_run:
        envelope_sender = args.from_addr or sender
        send(cfg["smtp"], envelope_sender, None, msg, envelope_recipients, dry_run=True)
        return

    username, password = get_credentials(cfg)

    log_extras = []
    if cc_list:     log_extras.append(f"cc: {', '.join(cc_list)}")
    if bcc_list:    log_extras.append(f"bcc: {len(bcc_list)} recipient(s)")
    if args.attach: log_extras.append(f"attach: {len(args.attach)} file(s)")
    extras = f" ({'; '.join(log_extras)})" if log_extras else ""
    print(f"Sending email to {', '.join(to_list)}{extras} ...", file=sys.stderr)
    try:
        # Envelope sender is the SMTP-authenticated username unless --from
        # was given, in which case we trust the caller (the SMTP server may
        # or may not honor it).
        env_sender = args.from_addr or username
        send(cfg["smtp"], env_sender, password, msg, envelope_recipients)
        print("Sent.", file=sys.stderr)
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
