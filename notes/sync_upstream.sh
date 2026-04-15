#!/usr/bin/env bash

set -euo pipefail

echo "Fetching upstream..."
git fetch upstream

old_main="$(git rev-parse main)"
new_main="$(git rev-parse upstream/main)"

echo
if [[ "$old_main" == "$new_main" ]]; then
    echo "No new upstream commits."
else
    echo "New upstream commits:"
    git log --reverse --oneline "${old_main}..${new_main}"
fi

echo
echo "Updating main..."
git checkout main
git merge --ff-only upstream/main
git push origin main

echo
echo "Updating notes..."
git checkout notes
git rebase main
git push --force-with-lease origin notes

echo
echo "Done."
