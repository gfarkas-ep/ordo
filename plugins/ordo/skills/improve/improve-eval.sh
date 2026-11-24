#!/bin/sh
# Helper for ordo:improve. Every add-on and history file is written by this script, never by hand.
# Usage:
#   improve-eval.sh scope [--project-dir D]
#   improve-eval.sh limit [--project-dir D]
#   improve-eval.sh write --root R --name N --from FILE --lesson TEXT --result TEXT [--project-dir D]
#   improve-eval.sh restore --root R --name N --version HISTORYFILE [--project-dir D]
#   improve-eval.sh history --root R --name N [--project-dir D]
#   improve-eval.sh run --stage red|lesson|regression --name N [--case DIR] [--global FILE] [--project FILE]
#                       [--earlier DIR]... [--plugin-case NAME]... [--allow-tools TOOL]... --runs K --out DIR [--project-dir D]
# scope: prints "scope: <global|project|ask>" and, for global and project, "root: <folder>" (HOME/.claude or D/.claude).
# limit: prints the addon_max_lines value (positive integer, default 40).
# Settings are read like the other `ordo <key>: <value>` settings: a whole line, project CLAUDE.md (D/CLAUDE.md, D defaults to the
# current folder) before ~/.claude/CLAUDE.md, the last valid line of a file wins, an invalid value is ignored.
# Paths: --project-dir, --root, --out, --from and --version refuse a "." or ".." part. A root is exactly HOME/.claude or D/.claude (D must exist; its
# physical path is compared). Below the root, ordo, addons, history and the add-on file must not be symlinks, and the physical path must not lie in
# ~/.claude/plugins or in the plugin's own folder; both are checked again after the folders are created.
# restore: the entry becomes the add-on (the current one is saved to history first); an entry that records "no previous add-on" removes the add-on.
# run: --case is the lesson case (red and lesson stages; the regression stage does not run it, AC28). --out must be a new folder under
#   <root>/ordo/improve/ (absolute; no results.json in it yet). --allow-tools TOOL is passed to claude as is, once per option; the plugin cases of a
#   regression need the grants of their batch tag (ba-readers and bash-skills: Bash, worth-it: Edit, reader-write: Write, dev-agent: Bash, Edit and Write, as scripts/run-eval-suite.sh
#   has them), so a regression refuses plugin cases that need different grants, or a --allow-tools that differs from theirs. --scaffold is always on.
# Settings files: a file that is not valid UTF-8 is ignored when iconv exists. Difference from the plugin's Python settings reader: Python's strip() also trims Unicode
#   whitespace around a line; this script trims ASCII whitespace and CR only.
# A refusal prints one "improve-eval: ..." line on stderr and exits 1; a usage error exits 2.
# run output: line 1 of stdout is the results JSON path, then "fail <case> run <i> <grader>: <explanation>" per failing grader per run. When a grader
#   threw (explanation starts "grader threw", for example an invalid regex) the stage is void: "error: grader <g> threw in case <c>: <explanation>" on
#   stderr, results.json kept, exit 3. A regex with an inline flag group such as (?i), or with \A, \Z or \z, in a placed case's grader is refused before claude is called.

die() { printf 'improve-eval: %s\n' "$1" >&2; exit 1; }
usage() { printf 'improve-eval: %s\n' "$1" >&2; exit 2; }

# setting_in FILE KEY FORM: last valid value of `ordo KEY: value` in FILE (form: number, or alternatives like a|b|c); nothing when none
setting_in() {
  [ -f "$1" ] || return 0
  [ "$(wc -c < "$1" | tr -d ' ')" -le 1048576 ] || return 0
  if command -v iconv >/dev/null 2>&1; then iconv -f UTF-8 -t UTF-8 < "$1" >/dev/null 2>&1 || return 0; fi
  awk -v key="$2" -v form="$3" '
    NR == 1 { sub(/^\357\273\277/, "") }
    { gsub(/^[ \t\r\f\v]+|[ \t\r\f\v]+$/, "") }
    index($0, "ordo " key ": ") == 1 {
      v = substr($0, length("ordo " key ": ") + 1)
      if (v == "" || v ~ /[ \t]/) next
      if (form == "number") { if (v ~ /^[0-9]+$/ && length(v) <= 18 && v + 0 > 0) { sub(/^0+/, "", v); val = v } }
      else { n = split(form, a, "|"); for (i = 1; i <= n; i++) if (a[i] == v) val = v }
    }
    END { if (val != "") print val }' "$1"
}

# setting KEY FORM DEFAULT: project CLAUDE.md beats ~/.claude/CLAUDE.md
setting() {
  v=$(setting_in "$pdir/CLAUDE.md" "$1" "$2")
  [ -n "$v" ] || v=$(setting_in "$HOME/.claude/CLAUDE.md" "$1" "$2")
  printf '%s\n' "${v:-$3}"
}

[ $# -ge 1 ] || usage "usage: improve-eval.sh scope|limit|write|restore|history|run ... (see the top of the script)"
cmd=$1; shift
case $cmd in
  scope|limit) allow=" --project-dir " ;;
  write) allow=" --root --name --from --lesson --result --project-dir " ;;
  restore) allow=" --root --name --version --project-dir " ;;
  history) allow=" --root --name --project-dir " ;;
  run) allow=" --stage --name --case --global --project --earlier --plugin-case --runs --out --project-dir --allow-tools " ;;
  *) usage "unknown subcommand $cmd" ;;
esac
pdir=$(pwd)
root= name= from= lesson= result= version=
stage= case= glob= proj= runs= out= earlier= pcases= tools=
while [ $# -gt 0 ]; do
  case $allow in *" $1 "*) ;; *) usage "unknown argument $1 for $cmd" ;; esac
  [ $# -ge 2 ] || usage "$1 needs a value"
  case $1 in
    --project-dir|--root|--out|--from|--version)
      case "/$2/" in */./*|*/../*) die "$1 '$2' has a '.' or '..' part; give the path without them" ;; esac ;;
  esac
  case $1 in
    --project-dir) pdir=$2 ;;
    --root) root=$2 ;;
    --name) name=$2 ;;
    --from) from=$2 ;;
    --lesson) lesson=$2 ;;
    --result) result=$2 ;;
    --version) version=$2 ;;
    --stage) stage=$2 ;;
    --case) case=$2 ;;
    --global) glob=$2 ;;
    --project) proj=$2 ;;
    --earlier) earlier="$earlier$2
" ;;
    --plugin-case) pcases="$pcases$2
" ;;
    --runs) runs=$2 ;;
    --allow-tools)
      case $2 in ''|*[!A-Za-z]*) usage "--allow-tools needs a plain tool name, got '$2'" ;; esac
      tools="$tools$2
" ;;
    --out) out=$2 ;;
  esac
  shift 2
done
case $pdir in /*) ;; *) pdir=$(pwd)/$pdir ;; esac
while [ "${pdir%/}" != "$pdir" ] && [ "$pdir" != / ]; do pdir=${pdir%/}; done

plugroot=$(cd "$(dirname "$0")/../.." && pwd -P)

# phys PATH: absolute path with the deepest existing folder resolved through symlinks
phys() {
  _d=$1 _rest=
  while [ ! -d "$_d" ]; do _rest="/$(basename "$_d")$_rest"; _d=$(dirname "$_d"); done
  printf '%s%s\n' "$(cd -P "$_d" && pwd -P)" "$_rest"
}

# check_name N: a skill or agent name of this plugin, never improve or coach
check_name() {
  case $1 in
    ''|improve|coach|*[!a-z0-9-]*|-*) die "name '$1' is not a skill or agent name of this plugin that takes an add-on (improve and coach take none)" ;;
  esac
  [ -d "$plugroot/skills/$1" ] || [ -f "$plugroot/agents/$1.md" ] || die "name '$1' is not a skill or agent name of this plugin"
}

# nolinks REL: no symlink among the parts of REL below the root
nolinks() {
  _cur=$root
  _oifs=$IFS; IFS=/; set -f
  for _c in $1; do
    _cur=$_cur/$_c
    [ ! -L "$_cur" ] || die "$_cur is a symlink; refusing to write through it"
  done
  IFS=$_oifs; set +f
}

# check_tree REL: REL below the root has no symlink part and lies in neither ~/.claude/plugins nor the plugin's own folder
check_tree() {
  nolinks "$1"
  case $1 in ordo/addons*) [ ! -L "$root/ordo/addons/$name.md" ] || die "$root/ordo/addons/$name.md is a symlink; refusing to write through it" ;; esac
  _real=$(phys "$root/$1")
  for _x in "$(phys "$HOME/.claude/plugins")" "$plugroot"; do
    case "$_real/" in "$_x"/*|"$_x"/) die "root resolves into the plugins folder or the plugin's own folder ($_real)" ;; esac
  done
}

# ensure_dir REL: check_tree, create, check_tree again
ensure_dir() {
  check_tree "$1"
  mkdir -p "$root/$1" || die "cannot create $root/$1"
  check_tree "$1"
}

# check_root: the root is exactly HOME/.claude or D/.claude (D exists); compared by physical path; then root becomes the physical one
check_root() {
  case $HOME in /*) ;; *) die "HOME is not an absolute path" ;; esac
  while [ "${root%/}" != "$root" ] && [ "$root" != / ]; do root=${root%/}; done
  hp=$(cd -P "$HOME" 2>/dev/null && pwd -P) || die "HOME '$HOME' is not a folder"
  pp=$(cd -P "$pdir" 2>/dev/null && pwd -P) || die "--project-dir '$pdir' is not an existing folder"
  [ "$(basename "$root")" = .claude ] || die "root '$root' must be exactly $HOME/.claude or <project-dir>/.claude"
  rp=$(cd -P "$(dirname "$root")" 2>/dev/null && pwd -P) || die "root '$root' must be exactly $HOME/.claude or <project-dir>/.claude (its parent folder does not exist)"
  [ "$rp" = "$hp" ] || [ "$rp" = "$pp" ] || die "root '$root' must be exactly $HOME/.claude or <project-dir>/.claude"
  root=$rp/.claude
}

# history_save N LESSON RESULT: copy the current add-on (or a "no previous add-on" record) to history under a name that never collides
history_save() {
  _dir=$root/ordo/addons
  ensure_dir ordo/addons/history
  _stamp=$(date +%Y%m%d-%H%M%S)
  _f=$_dir/history/$1-$_stamp.md _k=1
  while ! ( set -C; : > "$_f" ) 2>/dev/null; do
    _k=$((_k + 1))
    [ "$_k" -le 99 ] || die "no free history name for $1-$_stamp"
    _f=$(printf '%s/history/%s-%s-%02d.md' "$_dir" "$1" "$_stamp" "$_k")
  done
  _l=$(printf '%s' "$2" | tr '\n\r' '  ' | sed 's/-->/-- >/g')
  _r=$(printf '%s' "$3" | tr '\n\r' '  ' | sed 's/-->/-- >/g')
  if [ -e "$_dir/$1.md" ]; then _prev=add-on; else _prev=none; fi
  {
    printf '<!-- ordo add-on history\nname: %s\nsaved: %s\nlesson: %s\nresult: %s\nprevious: %s\n-->\n' "$1" "$_stamp" "$_l" "$_r" "$_prev"
    if [ "$_prev" = none ]; then echo "no previous add-on"; else cat "$_dir/$1.md"; fi
  } > "$_f" || die "cannot write $_f"
}

# put_addon N FILE: replace the add-on file in one step, through a fresh temp file made by mktemp in the same folder
put_addon() {
  check_tree ordo/addons
  _t=$(mktemp "$root/ordo/addons/.$1.md.XXXXXX") || die "cannot create a temp file in $root/ordo/addons"
  cp "$2" "$_t" && chmod 644 "$_t" && mv "$_t" "$root/ordo/addons/$1.md" || { rm -f "$_t"; die "cannot write $root/ordo/addons/$1.md"; }
}

# check_lines FILE [LABEL]: refuse a file with more lines than the limit; every line counts, an unterminated last line too
check_lines() {
  _max=$(setting addon_max_lines number 40)
  _n=$(awk 'END { print NR }' "$1")
  [ "$_n" -le "$_max" ] || die "${2:-$1} has $_n lines, over the limit of $_max (addon_max_lines)"
}

case $cmd in
  scope)
    s=$(setting addon_scope 'global|project|ask' global)
    echo "scope: $s"
    case $s in
      global) echo "root: $HOME/.claude" ;;
      project) echo "root: $pdir/.claude" ;;
    esac ;;
  limit) setting addon_max_lines number 40 ;;
  write)
    [ -n "$root" ] && [ -n "$name" ] && [ -n "$from" ] && [ -n "$lesson" ] && [ -n "$result" ] || usage "write needs --root, --name, --from, --lesson and --result"
    check_root
    check_name "$name"
    [ -f "$from" ] && [ -r "$from" ] || die "--from FILE '$from' is not a readable file"
    check_lines "$from"
    history_save "$name" "$lesson" "$result"
    put_addon "$name" "$from" ;;
  restore)
    [ -n "$root" ] && [ -n "$name" ] && [ -n "$version" ] || usage "restore needs --root, --name and --version"
    check_root
    check_name "$name"
    check_tree ordo/addons/history
    hdir=$root/ordo/addons/history
    case $version in */*) vfile=$version ;; *) vfile=$hdir/$version ;; esac
    [ -f "$vfile" ] || die "--version '$version' is not a file"
    [ "$(phys "$(dirname "$vfile")")" = "$(phys "$hdir")" ] || die "--version '$version' is not in the history folder $hdir"
    case $(basename "$vfile") in "$name"-[0-9]*.md) ;; *) die "--version '$version' is not a history entry of '$name'" ;; esac
    [ "$(sed -n 1p "$vfile")" = "<!-- ordo add-on history" ] || die "--version '$version' is not a history entry (header missing)"
    body=$(mktemp "${TMPDIR:-/tmp}/improve-restore.XXXXXX") || die "cannot create a temp file"
    trap 'rm -f "$body"' EXIT
    sed '1,/^-->$/d' "$vfile" > "$body"
    if [ "$(sed -n 's/^previous: //p' "$vfile" | head -1)" = add-on ]; then
      check_lines "$body" "history entry $(basename "$vfile")"
      history_save "$name" "restore of $(basename "$vfile")" "restored"
      put_addon "$name" "$body"
    else
      # the entry records "no previous add-on": that version is no add-on at all; the current one is saved first
      history_save "$name" "restore of $(basename "$vfile")" "restored"
      check_tree ordo/addons
      rm -f "$root/ordo/addons/$name.md" || die "cannot remove $root/ordo/addons/$name.md"
    fi ;;
  history)
    [ -n "$root" ] && [ -n "$name" ] || usage "history needs --root and --name"
    check_root
    check_name "$name"
    check_tree ordo/addons/history
    hdir=$root/ordo/addons/history
    [ -d "$hdir" ] || exit 0
    for f in "$hdir/$name"-[0-9]*.md; do [ -f "$f" ] && basename "$f" .md; done | sort -r | while read -r b; do
      f=$hdir/$b.md
      printf '%s\t%s\t%s\n' "$b.md" "$(sed -n 's/^lesson: //p' "$f" | head -1)" "$(sed -n 's/^result: //p' "$f" | head -1)"
    done ;;
  run)
    [ -n "$stage" ] && [ -n "$name" ] && [ -n "$runs" ] && [ -n "$out" ] || usage "run needs --stage, --name, --runs and --out"
    case $stage in red|lesson|regression) ;; *) usage "--stage must be red, lesson or regression" ;; esac
    case $runs in *[!0-9]*|0|0*) usage "--runs needs a positive integer" ;; esac
    if [ "$stage" != regression ] && [ -n "$earlier$pcases" ]; then usage "--earlier and --plugin-case belong to the regression stage only"; fi
    if [ "$stage" != regression ] && [ -z "$case" ]; then usage "the $stage stage needs --case"; fi
    [ "$stage" != regression ] || case=   # the regression stage does not run the lesson case (AC28)
    check_name "$name"
    # --out: a new folder under <root>/ordo/improve/ of one of the two roots, checked like a write
    out_root=
    for _r in "$HOME/.claude" "$pdir/.claude"; do
      case $out in "$_r/ordo/improve/"?*) out_root=$_r; out_rel=${out#"$_r/ordo/improve/"}; break ;; esac
    done
    [ -n "$out_root" ] || die "--out '$out' must be a folder under $HOME/.claude/ordo/improve/ or <project-dir>/.claude/ordo/improve/ (absolute path)"
    root=$out_root
    check_root
    check_tree "ordo/improve/$out_rel"
    [ ! -e "$out/results.json" ] || die "--out '$out' already holds a results.json; use a new folder"
    [ -z "$case" ] || [ -f "$case/prompt.md" ] || die "case folder '$case' has no prompt.md"
    while IFS= read -r _c; do
      [ -z "$_c" ] || [ -f "$_c/prompt.md" ] || die "case folder '$_c' has no prompt.md"
    done <<EOF
$earlier
EOF
    # grants: normalised to a sorted list; the plugin cases fix what the run may grant
    norm() { printf '%s\n' $1 | sort -u | tr '\n' ' '; }
    G=$(norm "$(printf '%s' "$tools" | tr '\n' ' ')")
    need=; need_set=
    while IFS= read -r _c; do
      [ -n "$_c" ] || continue
      case $_c in */*|.*) die "plugin case '$_c' is not a case name" ;; esac
      [ -f "$plugroot/evals/$_c/prompt.md" ] || die "plugin case '$_c' not found in $plugroot/evals"
      _g=
      for _t in $(sed -n 's/^tags: *\[\(.*\)\]$/\1/p' "$plugroot/evals/$_c/prompt.md" | tr -d ' ' | tr ',' ' '); do
        case $_t in ba-readers|bash-skills) _g="$_g Bash" ;; worth-it) _g="$_g Edit" ;; reader-write) _g="$_g Write" ;; dev-agent) _g="$_g Bash Edit Write" ;; esac
      done
      _g=$(norm "$_g")
      if [ -n "$need_set" ] && [ "$_g" != "$need" ]; then die "the plugin cases need different tool grants ('$need' and '$_g'); run them in separate invocations"; fi
      need=$_g need_set=1
    done <<EOF
$pcases
EOF
    if [ -n "$need_set" ] && [ "$G" != "$need" ]; then die "the plugin cases need --allow-tools '${need:-none}', got '${G:-none}'"; fi
    if [ "$stage" = regression ] && [ -z "$earlier$pcases" ]; then die "regression has no earlier or plugin cases; skip the round"; fi
    for _f in "$glob" "$proj"; do
      [ -z "$_f" ] && continue
      [ -f "$_f" ] && [ -r "$_f" ] || die "layer file '$_f' is not a readable file"
    done
    # the real home of the user running this script (physical path): HOME now, and the account's home
    acct=$(eval "printf %s ~$(id -un)" 2>/dev/null)
    ap=$(cd -P "$acct" 2>/dev/null && pwd -P)
    # shq TEXT: TEXT as one single-quoted shell word
    shq() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }
    guard_homes="$(shq "$hp") $(shq "$ap")"
    tmp_root=${TMPDIR:-/tmp}
    tmp_root=${tmp_root%/}
    work=$(mktemp -d "$tmp_root/ordo-improve.XXXXXX") || die "cannot create a temp folder"
    cleanup() {
      if [ -n "${work:-}" ] && [ -d "$work" ] && [ "${work#"$tmp_root"/}" != "$work" ]; then rm -r "$work"; fi
    }
    trap cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    copy=$work/ordo
    rsync -a --exclude results "$plugroot/" "$copy/" || die "cannot copy the plugin"
    evals=$copy/evals-improve
    mkdir -p "$evals"
    placed=
    # place_case SRC: copy the case, set its runs, put the layers and the case's own scaffold into one scaffold script
    place_case() {
      _name=$(basename "$1")
      case "$placed" in *"
$_name
"*) die "two cases are named '$_name'" ;; esac
      placed="$placed
$_name
"
      _dst=$evals/$_name
      cp -R "$1" "$_dst" || die "cannot copy case '$1'"
      _p=$_dst/prompt.md
      [ "$(sed -n 1p "$_p")" = --- ] || die "prompt.md of case '$_name' has no front matter"
      awk -v k="$runs" '
        NR == 1 { fm = 1; print; next }
        fm && $0 == "---" { if (!done) print "runs: " k; fm = 0; print; next }
        fm && /^runs:/ { print "runs: " k; done = 1; next }
        { print }' "$_p" > "$_p.new" && mv "$_p.new" "$_p" || die "cannot set runs in '$_name'"
      _sname=scaffold.sh _own=
      if [ -f "$_dst/case.yaml" ]; then
        _sname=$(sed -n 's/^[ ]*scaffold_script:[ ]*//p' "$_dst/case.yaml" | head -1 | tr -d '"'"'"' \r')
        [ -n "$_sname" ] || die "case.yaml of case '$_name' names no scaffold_script"
        case $_sname in */*|.*) die "scaffold_script '$_sname' of case '$_name' is not a plain file name" ;; esac
        [ -f "$_dst/$_sname" ] || die "scaffold script '$_sname' of case '$_name' not found"
        _own=$_dst/$_sname
      else
        printf 'schema_version: "1.0"\ncontext:\n  scaffold_script: scaffold.sh\n' > "$_dst/case.yaml"
      fi
      _gen=$_dst/.scaffold.gen
      _sh=$( [ -n "$_own" ] && sed -n '1{/^#!/p;}' "$_own" )
      {
        echo "${_sh:-#!/bin/sh}"
        echo "# generated by improve-eval.sh: the add-on layers under test, then the case's own scaffold"
        printf '%s\n' '_cur=$(cd -P "$HOME" 2>/dev/null && pwd -P) || _cur=' \
          '[ -n "$_cur" ] || { echo "improve-eval scaffold: HOME is not a folder" >&2; exit 1; }' \
          "for _rh in $guard_homes; do" \
          '  [ -n "$_rh" ] && [ "$_cur" = "$_rh" ] && { echo "improve-eval scaffold: HOME is the real home of the user ($_rh); refusing to write add-ons there" >&2; exit 1; }' \
          'done'
        for _l in "global:$glob:\$HOME/.claude/ordo/addons" "project:$proj:.claude/ordo/addons"; do
          _src=${_l#*:}; _dir=${_src#*:}; _src=${_src%%:*}
          [ -n "$_src" ] || continue
          _k=1; while grep -qx "ORDO_ADDON_EOF_$_k" "$_src"; do _k=$((_k + 1)); done
          printf 'mkdir -p "%s" && cat > "%s/%s.md" <<'"'"'ORDO_ADDON_EOF_%s'"'"'\n' "$_dir" "$_dir" "$name" "$_k"
          cat "$_src"; [ -z "$(tail -c1 "$_src")" ] || echo
          printf 'ORDO_ADDON_EOF_%s\n' "$_k"
        done
        [ -z "$_own" ] || sed '1{/^#!/d;}' "$_own"
      } > "$_gen" || die "cannot build the scaffold of case '$_name'"
      mv "$_gen" "$_dst/$_sname" && chmod +x "$_dst/$_sname" || die "cannot place the scaffold of case '$_name'"
    }
    [ -z "$case" ] || place_case "$case"
    while IFS= read -r _c; do [ -z "$_c" ] || place_case "$_c"; done <<EOF
$earlier
EOF
    while IFS= read -r _c; do [ -z "$_c" ] || place_case "$plugroot/evals/$_c"; done <<EOF
$pcases
EOF
    # the eval's regex engine is JavaScript: an inline flag group such as (?i) makes the grader throw, so refuse it before any paid call
    for _g in "$evals"/*/graders/*; do
      [ -f "$_g" ] || continue
      _bad=$(awk '/^[ \t]*(pattern|input_match):/ && /\(\?[A-Za-z]/ { print; exit }' "$_g")
      [ -z "$_bad" ] || die "case '$(basename "$(dirname "$(dirname "$_g")")")', grader file '$(basename "$_g")': the regex has an inline flag group like (?i) ($_bad); the eval uses JavaScript regex, so use a 'flags: i' line instead"
      # \A, \Z and \z are Python-style anchors; JavaScript reads them as the letters A, Z, z (an even run of backslashes before the letter is an escaped backslash)
      _bad=$(awk '/^[ \t]*(pattern|input_match):/ && /(^|[^\\])(\\\\)*\\[AZz]/ { print; exit }' "$_g")
      [ -z "$_bad" ] || die "case '$(basename "$(dirname "$(dirname "$_g")")")', grader file '$(basename "$_g")': the regex has \\A, \\Z or \\z ($_bad); JavaScript has no \\A/\\Z/\\z (they match the letters), so use ^ and $ (without a 'flags: m' line they anchor the whole text), or a lookahead such as (?![\\s\\S])"
    done
    ensure_dir "ordo/improve/$out_rel"
    set -- plugin eval "$copy" --eval-dir evals-improve --ablation none --no-publish --trust-plugin --scaffold
    while IFS= read -r _t; do [ -z "$_t" ] || set -- "$@" --allow-tools "$_t"; done <<EOF
$tools
EOF
    set -- "$@" --output-dir "$out" --json "$out/results.json"
    claude "$@"
    _rc=$?
    # a case below full pass makes the eval exit 1; that is a result, not an error
    [ -s "$out/results.json" ] || die "claude plugin eval exit $_rc and no results JSON at $out/results.json"
    echo "$out/results.json"
    # fail lines (stdout) for every failing grader of every run; a grader that threw is no result: stderr lines and exit 3
    python3 -I -c '
import json, sys
try:
    data = json.load(open(sys.argv[1]))
    cases = data.get("cases", []) if isinstance(data, dict) else []
    threw = []
    for c in cases:
        for i, run in enumerate((c.get("arms") or {}).get("with") or [], 1):
            for g in run.get("graders") or []:
                if g.get("passed") is True:
                    continue
                e = " ".join(str(g.get("explanation", "")).split())
                print("fail %s run %d %s: %s" % (c.get("name"), i, g.get("name"), e))
                if e.startswith("grader threw"):
                    t = "error: grader %s threw in case %s: %s" % (g.get("name"), c.get("name"), e)
                    if t not in threw:
                        threw.append(t)
except Exception as x:
    sys.stderr.write("improve-eval: cannot read %s: %s\n" % (sys.argv[1], x))
    sys.exit(4)
for t in threw:
    sys.stderr.write(t + "\n")
sys.exit(3 if threw else 0)' "$out/results.json"
    _py=$?
    [ "$_py" -ne 4 ] || exit 1
    exit "$_py" ;;
esac
