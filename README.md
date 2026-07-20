# codex-auth-switcher

Small auth profile switcher for the Codex CLI.

Codex stores file-backed CLI credentials at `$CODEX_HOME/auth.json`, usually
`~/.codex/auth.json`. This tool keeps saved auth profiles as plain files under
`$CODEX_HOME/auth.d/` and makes the active `auth.json` a symlink to one of
those saved profiles.

No metadata is stored. Profile state is just files and one symlink.

## Install

```bash
install -m 755 codex-auth ~/.local/bin/codex-auth
```

Make sure `~/.local/bin` is on your shell `PATH`.

## Usage

```bash
codex-auth add <name>     # log in to a new account, save it, and switch to it
codex-auth save <name>    # save current auth.json as a profile and switch to it
codex-auth list           # list saved profiles, storage paths, and [current]
codex-auth use <name>     # switch to a saved profile
codex-auth next           # switch to the next saved profile in sorted order
codex-auth export-current <path>  # export the current profile as a direct file
codex-auth remove <name>  # remove a saved profile, refusing if it is current
```

First migration:

```bash
codex-auth save primary
```

Add a second account:

```bash
codex-auth add secondary
```

Toggle accounts:

```bash
codex-auth next
```

Export the selected profile for a service that requires a direct credential
file rather than the interactive CLI's managed symlink:

```bash
codex-auth export-current \
  "$HOME/.local/state/checkpoint-meridian-runtime/codex-subscription/auth.json"
```

Export is explicit: switching profiles does not silently update service
credentials or restart any service.

## Safety

- `save` dereferences the current `auth.json`, so saving the same active auth
  under multiple names creates independent copies.
- `use` and `next` refuse to overwrite an unmanaged regular `auth.json`. Run
  `codex-auth save <name>` first so the current credentials are preserved.
- `add` temporarily removes the managed `auth.json` symlink before running
  `codex login`, then imports the new regular `auth.json` as the requested
  profile. If login fails or is cancelled, the previous profile link is
  restored.
- `remove` refuses to remove the profile that is currently linked as
  `auth.json`.
- `export-current` copies the selected managed profile to an absolute path by
  atomic replacement. It requires direct mode-0600 source and destination
  files inside an existing, direct, current-user-owned mode-0700 directory;
  symlink destinations and symlinked parent paths are rejected.
- Running Codex sessions keep their in-process auth snapshot. Switch profiles
  before starting a new Codex session.

## Requirements

- Bash
- GNU coreutils/findutils behavior used by common Linux distributions
- Codex CLI using file-backed auth at `$CODEX_HOME/auth.json`
