#!/bin/bash
# docs/export-rules.md exists; docs/partner-terms.md, which the request names, does not.
set -e
mkdir -p docs
cat > docs/export-rules.md <<'MD'
# Export rules
1. Only workspace admins can start an export.
2. An export contains every row of the workspace, one CSV file per table.
3. Exports of workspaces with more than 10,000 rows are queued and sent by email, not downloaded directly.
4. Export files are deleted from the server after 24 hours.
MD
