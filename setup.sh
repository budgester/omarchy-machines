#!/bin/bash
# Set up a freshly installed machine from its machines repo.
# Usage: setup.sh <owner/repo> <clone path>
#
# Run in a floating terminal by the bar widget: it logs in to GitHub if
# needed, clones the repo and runs its bootstrap.sh, which asks for sudo.

set -euo pipefail

repo=${1:?usage: setup.sh <owner/repo> <clone path>}
path=${2:?usage: setup.sh <owner/repo> <clone path>}

fail() {
  echo
  echo "Setup stopped: $1"
  echo "Fix that and click Set up again in the Machines widget."
  exit 1
}

if ! command -v gh >/dev/null 2>&1; then
  fail "gh is not installed. Install it with: mise use -g gh"
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "Logging in to GitHub to clone $repo..."
  gh auth login --web --git-protocol https || fail "GitHub login did not finish."
  gh auth setup-git
fi

if [[ -d $path/.git ]]; then
  echo "$path is already cloned: pulling the latest."
  git -C "$path" pull --ff-only || fail "could not update $path."
else
  mkdir -p "$(dirname "$path")"
  gh repo clone "$repo" "$path" || fail "could not clone $repo."
fi

[[ -x $path/bootstrap.sh ]] || fail "$repo has no bootstrap.sh."
"$path/bootstrap.sh" || fail "bootstrap.sh failed. Its output is above."

omarchy-shell -q budgester.machines refresh
echo
echo "This machine is set up from $repo."
