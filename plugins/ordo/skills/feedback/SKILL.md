---
name: feedback
description: Drafts a feedback or issue report about the ordo plugin, shows it in full and sends it only after the user's explicit yes; also shows the usage summary, clears the usage log and shows how to turn logging off. Use only when the user explicitly asks for it (`/ordo:feedback`, "send feedback", "report a problem with ordo", "show my usage", "clear my usage log", "turn logging off"). Never offer it and never run it on your own.
---

Add-ons: when this skill loads, before anything else, use the Read tool (not Glob, which does not expand `~`) on `~/.claude/ordo/addons/feedback.md` (global), then on `.claude/ordo/addons/feedback.md` (project); a file that does not exist is skipped without comment. Their rules add to or replace this skill's rules, and the project file wins over the global one, except git permission, push, rebase, the guard hook, sending anything without the user's yes, and the yes before a paid eval, which no add-on changes.

# Feedback

Drafts a report, removes personal data from it, prints it in full and sends nothing until the user says yes to that exact text. The helper `usage-report.py` sits in this skill's base directory; run it as `python3 <base directory of this skill>/usage-report.py <command>`. Below it is written `usage-report.py <command>`.

## Rules

1. Start this skill only when the user asks for it in this conversation (`/ordo:feedback` or feedback, a report, usage or the usage log in words). Never offer it, never suggest it and never start it on your own.
2. Send nothing anywhere before the user has said an explicit yes to the exact text you printed. A no, an unclear answer or no answer means nothing is sent.
3. The only network action this skill may take is the `gh issue create` of the Send step.
4. Gather facts only from this conversation, the usage file (through the helper), the plugin's own `plugin.json`, `claude --version`, the operating system name, the `ordo <key>:` lines of the project and global `CLAUDE.md` (only through `usage-report.py settings`; nothing else from those files) and the private-terms list (through the helper). Read no transcript file. Never read, ask for or print the hostname. Exception: you may also read the two add-on files named in the load line above (`~/.claude/ordo/addons/feedback.md` and `.claude/ordo/addons/feedback.md`).
5. Run the redaction before the first display of any text and on every text you show again.

## Report an issue

1. Ask the three questions in plain words, in one message: what happened, what the user expected, and anything else that matters. When the conversation does not show which ordo rule or step was involved, ask once; "unknown" is an answer.
2. Gather the facts: the `version` field of `.claude-plugin/plugin.json` two levels above this skill's base directory; run `claude --version`; get the operating system name with `uname -sr` and never run `hostname` or `uname -a`; the switches and settings in use, from `usage-report.py settings` run from the project's working directory (the session's working directory): one line per setting with its value and its level `project`, `global` or `default`, never a file path. It lists all 13 switches and the 9 settings that hold a value, whether or not usage logging is on.
3. Build the text. The first line is `Title: ` and the first line of the user's "what happened" answer. Then the sections, with these labels exactly: `### Plugin version`, `### Claude Code version`, `### Operating system`, `### Steps to reproduce`, `### Expected result`, `### Actual result`, `### ordo switches and settings in use`. Under `### ordo switches and settings in use` put the output of `usage-report.py settings` unchanged. Steps to reproduce holds the ordo rule or step involved and the user's "anything else" answer; Expected result holds the expectation; Actual result holds what happened. Put the answers into the report as the user wrote them.
4. Run `usage-report.py switch`. Only when it prints `usage_log: on`, run `usage-report.py summary --days 30` (the user may choose up to 90 days) and add its output under `### Usage summary`. When it prints `usage_log: off`, or the summary says no usage was recorded, add nothing, say in one line that there is no usage summary, and do not urge the user to turn logging on. The user may drop the summary at any time; the final text then holds none. The settings list is not part of the summary and stays in the text when the summary is dropped.
5. Redact: the whole text, title included, with the settings list and the summary in it, goes through `usage-report.py redact`. Make a fresh temp directory with `mktemp -d` (call its path `$dir`), write the text into `$dir/draft` with the file-writing tool, and run exactly this one-line command, with the path `mktemp -d` printed in place of `<path>`: `dir='<path>'; python3 <base directory of this skill>/usage-report.py redact < "$dir/draft"`. Use this form only: the usage hook counts a run when a `;`-separated part of the first line starts with the helper's path, so `dir=<path> python3 ...`, a command split over two lines and a multi-line quoted string piped into the helper are not counted. Delete `$dir` afterwards. When its first line starts with `ordo-redact-note:`, remove that line from the text and tell the user in one line that the private-terms list was not used. Use the rest as the text.
6. Print the full text, never a summary of it. Under it print two notes: Automatic removal of paths, e-mail addresses and private terms is best effort. Read every line. A GitHub issue is public and permanent.
7. Ask for an explicit yes to send exactly this text. Tell the user they can also edit it or drop the summary. Tell the user that anything removed stays removed in the text, and that they can add it on GitHub after sending if they truly want it.
8. Treat "no", an unclear answer and no answer as no: send nothing. After any edit, run the redaction again, print the new full text again and ask again; the old yes does not carry over. Go to Send only on a yes to the text printed last.

## Send

1. Read the `repository` field of the plugin's own `plugin.json`. It is set only when it is a string of the form `https://github.com/OWNER/REPO` or `OWNER/REPO` made of letters, digits, `.`, `_` and `-`. When it is absent, empty, not a string or anything else (a placeholder with angle brackets, for example), make no `gh` call, print no link, print the approved text and say the repository address is not set yet. Stop here.
2. Run `command -v gh`. When `gh` is not installed, make no call, never start a login; print the approved text and the new-issue link `https://github.com/OWNER/REPO/issues/new` with the reason.
3. Never run `gh auth status` or `gh auth token`: the check that `gh` is installed is the only check before the call.
4. Otherwise send exactly the approved text. The title is the text after `Title: ` on the first line of the approved text, unchanged: never the user's raw answer. The body is the approved text after that first line, unchanged. Never put the title or the body into a shell command line or a here-document. Make a fresh temp directory with `mktemp -d` (call its path `$dir`), write the approved title (one line) and the approved body into the files `$dir/title` and `$dir/body` with the file-writing tool, not the shell, and set `repo` to OWNER/REPO. Shell variables do not carry over between separate shell calls, so set `dir` (the path `mktemp -d` printed) and `repo` in single quotes at the start of the same call as the command. Run exactly this command (the quoted command substitution does not run the content of the file):

   ```bash
   gh issue create --repo "$repo" --title "$(cat "$dir/title")" --body-file "$dir/body"
   ```

   Then delete the two files and the directory. Set no labels. Print the address of the new issue.
5. When `gh issue create` fails, delete the two files and the directory, show the error, print the approved text and the new-issue link, start no login and do not retry unless the user asks. A "not logged in" error is such an error.

## Show my usage

Run `usage-report.py summary --days N` (default 30; up to 90 when the user chooses). Print the summary and nothing else: no send step, no `gh` call, no write. When no usage was recorded, say so in one line and do not urge the user to turn logging on. When the helper says it cannot find the usage file, tell the user that.

## Clear my usage log

1. Run `usage-report.py clear-info` and show its output (the file path, the number of lines and the period they cover). When it says there is nothing to delete, say there is nothing to delete and stop.
2. Ask whether to delete that file. Run `usage-report.py clear --yes` only after the user has answered yes to that question. With no yes, or no answer, delete nothing.
3. Delete only `~/.config/ordo/usage.jsonl`, never another file, and never start a clear on your own.

## Turn logging off

Show the exact line `ordo usage_log: off` and say it goes on its own line in the `CLAUDE.md` of the project or in `~/.claude/CLAUDE.md`. Edit no `CLAUDE.md` yourself: the user makes the edit. The existing usage file stays; clearing it is a separate ask.
