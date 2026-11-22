# Security

Report vulnerabilities through GitHub private vulnerability reporting: open https://github.com/gfarkas-ep/ordo/security/advisories/new, or use the "Report a vulnerability" button on the Security tab of the repository.

Do not open a public issue for a vulnerability.

What counts: the Bash guard hook (`plugins/ordo/hooks/guard_bash.py`) allowing a command it should deny, a hook or script that writes, deletes or sends data it should not, or text in the plugin that leads Claude to do so. The README's Safety hook section lists the known limits of the guard; those are documented, not vulnerabilities.

Reports are handled best-effort; no response time is promised.
