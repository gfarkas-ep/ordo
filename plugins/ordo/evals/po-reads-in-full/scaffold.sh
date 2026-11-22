#!/bin/bash
set -e
mkdir -p docs/specs docs/design src
cat > docs/specs/2026-10-20-link-expiry.md <<'SPEC'
# Spec: Shared link expiry (Harbor Drive)

## Story
As a Harbor Drive user, I want to choose when a shared link I create expires, so that files are not reachable forever.

## Acceptance criteria
1. C1: Given the share dialog, when a user creates a link, then the user can pick 1 day, 7 days, 30 days or never.
2. C2: Given an expired link, when it is opened, then the page shows the expired-link message defined in docs/design/HARBOR_DESIGN.md, and no file is served.
3. C3: Given a link created before this change, when it is opened, then it behaves as before and never expires.
SPEC
python3 - <<'PY'
topics = ["Sharing", "Permissions", "Quotas", "Audit trail", "Notifications", "Sync engine", "Versioning", "Search", "Trash and restore", "Import and export", "Mobile clients", "Desktop clients", "Admin console", "Billing", "Encryption", "Rate limiting", "Webhooks", "Single sign-on", "Retention policy", "Telemetry", "Offline mode", "Previews", "Comments", "Teams and groups"]
nouns = ["workspace", "folder", "file", "member", "device", "session", "token", "policy", "job", "event"]
verbs = ["creates", "updates", "removes", "lists", "validates", "archives", "restores", "signs"]
lines = ["# Harbor Drive: Design Reference", "", "Status: approved. Owner: Platform team.", ""]
def section(n, t):
    lines.extend(["## %d. %s" % (n, t), ""])
    for k in range(1, 9):
        lines.append("### %d.%d %s: %s %s" % (n, k, t, nouns[(n + k) % 10], verbs[(n * k) % 8]))
        lines.append("")
        for j in range(1, 8):
            a, b = nouns[(n + k + j) % 10], nouns[(n * j + k) % 10]
            lines.append("- %s-%d.%d.%d: The %s service %s each %s and records the result against the owning %s; the limit is %d per %d seconds." % (t[:3].upper(), n, k, j, t.lower(), verbs[(n + k + j) % 8], a, b, 10 + (n * 7 + k * 3 + j) % 90, 5 * (1 + (n + j) % 12)))
        lines.extend(["", "| Endpoint | Method | Request field | Response field | Error code |", "|---|---|---|---|---|"])
        for j in range(1, 6):
            lines.append("| /v%d/%s/%s | %s | %s_id | %s_state | E-%d%02d |" % (1 + n % 3, t.lower().replace(" ", "-"), nouns[(k + j) % 10], ["GET", "POST", "PUT", "DELETE", "PATCH"][j - 1], nouns[(k + j) % 10], nouns[(n + j) % 10], n, k * 5 + j))
        lines.append("")
n = 0
copy_done = False
while len(lines) < 7000:
    for t in topics:
        n += 1
        if not copy_done and len(lines) > 3400:
            lines.extend(["## %d. User-facing copy" % n, "", "All strings shown to end users are defined here. Clients never invent strings.", ""])
            lines.append("- COPY-1: Saved page title: `Saved to Harbor Drive`.")
            lines.append("- COPY-2: Empty folder: `Nothing here yet.`")
            lines.append("- COPY-3: Upload failed page: `The upload did not finish. Try again.`")
            lines.append("- COPY-4: Page shown when a recipient opens a shared link after its end date: `This shared link expired on <date>.` The date is printed as YYYY-MM-DD.")
            lines.append("- COPY-5: Page shown for an unknown address: `Page not found`.")
            lines.append("")
            copy_done = True
            continue
        if len(lines) >= 7000:
            break
        section(n, t)
lines.append("End of document.")
open("docs/design/HARBOR_DESIGN.md", "w").write("\n".join(lines) + "\n")
PY
cat > src/links.py <<'PY'
from datetime import datetime, timedelta

CHOICES = {"1d": 1, "7d": 7, "30d": 30, "never": None}


def create_link(file_id, choice="never", now=None):
    now = now or datetime.utcnow()
    days = CHOICES[choice]
    expires = None if days is None else now + timedelta(days=days)
    return {"file_id": file_id, "expires": expires}


def open_link(link, now=None):
    now = now or datetime.utcnow()
    if link.get("expires") is not None and now >= link["expires"]:
        return "Link not found"
    return "file:" + link["file_id"]
PY
