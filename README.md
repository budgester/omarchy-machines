# Machines for the Omarchy bar

Rebuild a freshly installed [Omarchy](https://omarchy.org) machine from your
own Ansible repo, then keep an eye on whether it still matches that repo.

## On a fresh install

```sh
omarchy plugin add https://github.com/budgester/omarchy-machines.git --enable --yes
```

The icon turns red and a notification offers to set the machine up. Click
it, or **Set up this machine** in the panel. A terminal opens and:

1. logs in to GitHub with `gh`, if you are not logged in yet;
2. clones your machines repo (default `budgester/machines` to
   `~/Projects/machines`);
3. runs its `bootstrap.sh`, which asks for your password.

## What the icon says

| Icon | State |
|---|---|
| Laptop | The machine matches the repo |
| Amber warning | **Drift**: the panel lists what the playbook would change and which packages are missing. **Apply** runs `bootstrap.sh` in a terminal |
| Red warning | Not set up yet, or the check failed (the panel says why) |
| Arrows | Checking |

It checks when the shell starts, every hour (`checkIntervalMin`), when the
panel opens, and on a right-click. `R` in the open panel also checks.

## What your machines repo needs

- `bootstrap.sh`: applies the repo to this machine; run in a terminal.
- `status.sh --json`: reports without changing anything and without sudo.
  It prints one object:

  ```json
  {"state": "in-step|drift|error",
   "changes": [{"role": "mise", "task": "Write mise config"}],
   "missing_packages": ["nmap"],
   "error": "", "checked_at": "2026-10-26T17:43:58+00:00",
   "last_apply": "2026-10-26T18:00:00+00:00 966ebbe"}
  ```

[budgester/machines](https://github.com/budgester/machines) is private, but
its `status.sh` runs the playbook with `--check` and the `ansible.posix.json`
callback, and is easy to copy.

## Settings

| Key | Default | |
|---|---|---|
| `repo` | `budgester/machines` | GitHub `owner/name` to clone |
| `repoPath` | `~/Projects/machines` | where it is cloned |
| `checkIntervalMin` | `60` | minutes between checks |

From a script: `omarchy-shell budgester.machines status` prints the state, and
`omarchy-shell budgester.machines refresh` checks again.
