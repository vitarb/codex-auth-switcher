#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
codex_auth="$repo_root/codex-auth"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export CODEX_HOME="$tmp"

write_auth() {
  local token="$1"
  printf '{"OPENAI_API_KEY":null,"tokens":{"access_token":"%s","refresh_token":"r","id_token":"i","account_id":"acct"},"last_refresh":"2026-05-27T00:00:00Z"}\n' "$token" > "$CODEX_HOME/auth.json"
  chmod 600 "$CODEX_HOME/auth.json"
}

write_auth alpha

"$codex_auth" save foo >/tmp/codex-auth-test.out
[[ "$(readlink "$CODEX_HOME/auth.json")" == 'auth.d/foo.json' ]]
[[ "$(stat -c %a "$CODEX_HOME/auth.d")" == '700' ]]
[[ "$(stat -c %a "$CODEX_HOME/auth.d/foo.json")" == '600' ]]

"$codex_auth" save bar >/tmp/codex-auth-test.out
[[ "$(readlink "$CODEX_HOME/auth.json")" == 'auth.d/bar.json' ]]

list_output="$("$codex_auth" list)"
[[ "$list_output" == *"bar [current] $CODEX_HOME/auth.d/bar.json"* ]]
[[ "$list_output" == *"foo $CODEX_HOME/auth.d/foo.json"* ]]

"$codex_auth" use foo >/tmp/codex-auth-test.out
[[ "$(readlink "$CODEX_HOME/auth.json")" == 'auth.d/foo.json' ]]

"$codex_auth" next >/tmp/codex-auth-test.out
[[ "$(readlink "$CODEX_HOME/auth.json")" == 'auth.d/bar.json' ]]

"$codex_auth" next >/tmp/codex-auth-test.out
[[ "$(readlink "$CODEX_HOME/auth.json")" == 'auth.d/foo.json' ]]

fakebin="$tmp/bin"
mkdir -p "$fakebin"
cat > "$fakebin/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[[ "${1:-}" == "login" ]] || exit 2
printf '{"OPENAI_API_KEY":null,"tokens":{"access_token":"baz","refresh_token":"r","id_token":"i","account_id":"acct"},"last_refresh":"2026-05-27T00:00:00Z"}\n' > "$CODEX_HOME/auth.json"
chmod 600 "$CODEX_HOME/auth.json"
EOF
chmod 755 "$fakebin/codex"

PATH="$fakebin:$PATH" "$codex_auth" add baz >/tmp/codex-auth-test.out
[[ "$(readlink "$CODEX_HOME/auth.json")" == 'auth.d/baz.json' ]]
[[ "$(stat -c %a "$CODEX_HOME/auth.d/baz.json")" == '600' ]]
grep -q '"access_token":"baz"' "$CODEX_HOME/auth.d/baz.json"

if PATH="$fakebin:$PATH" "$codex_auth" add baz >/tmp/codex-auth-test.out 2>/tmp/codex-auth-test.err; then
  echo 'expected duplicate add to fail' >&2
  exit 1
fi
[[ "$(readlink "$CODEX_HOME/auth.json")" == 'auth.d/baz.json' ]]

failbin="$tmp/failbin"
mkdir -p "$failbin"
cat > "$failbin/codex" <<'EOF'
#!/usr/bin/env bash
exit 42
EOF
chmod 755 "$failbin/codex"

if PATH="$failbin:$PATH" "$codex_auth" add qux >/tmp/codex-auth-test.out 2>/tmp/codex-auth-test.err; then
  echo 'expected failed login add to fail' >&2
  exit 1
fi
[[ "$(readlink "$CODEX_HOME/auth.json")" == 'auth.d/baz.json' ]]
[[ ! -e "$CODEX_HOME/auth.d/qux.json" ]]

"$codex_auth" use foo >/tmp/codex-auth-test.out
[[ "$(readlink "$CODEX_HOME/auth.json")" == 'auth.d/foo.json' ]]

"$codex_auth" remove baz >/tmp/codex-auth-test.out
[[ ! -e "$CODEX_HOME/auth.d/baz.json" ]]

"$codex_auth" remove bar >/tmp/codex-auth-test.out
[[ ! -e "$CODEX_HOME/auth.d/bar.json" ]]

if "$codex_auth" remove foo >/tmp/codex-auth-test.out 2>/tmp/codex-auth-test.err; then
  echo 'expected remove current to fail' >&2
  exit 1
fi
[[ -e "$CODEX_HOME/auth.d/foo.json" ]]

rm "$CODEX_HOME/auth.json"
list_output="$("$codex_auth" list)"
[[ "$list_output" == "foo $CODEX_HOME/auth.d/foo.json" ]]
"$codex_auth" next >/tmp/codex-auth-test.out
[[ "$(readlink "$CODEX_HOME/auth.json")" == 'auth.d/foo.json' ]]

unmanaged="$(mktemp -d)"
mkdir -p "$unmanaged/auth.d"
printf '{}\n' > "$unmanaged/auth.json"
printf '{}\n' > "$unmanaged/auth.d/foo.json"
if CODEX_HOME="$unmanaged" "$codex_auth" use foo >/tmp/codex-auth-test.out 2>/tmp/codex-auth-test.err; then
  echo 'expected unmanaged regular auth switch to fail' >&2
  exit 1
fi
[[ ! -L "$unmanaged/auth.json" ]]
rm -rf "$unmanaged"

if "$codex_auth" delete foo >/tmp/codex-auth-test.out 2>/tmp/codex-auth-test.err; then
  echo 'expected delete command to fail' >&2
  exit 1
fi

if "$codex_auth" rm foo >/tmp/codex-auth-test.out 2>/tmp/codex-auth-test.err; then
  echo 'expected rm command to fail' >&2
  exit 1
fi

rm -f /tmp/codex-auth-test.out /tmp/codex-auth-test.err
echo 'codex-auth smoke tests passed'
