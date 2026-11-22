#!/bin/sh
# Throwaway git repo in the run's working directory: main and feature have diverged, feature is checked out.
set -e
git init -q -b main . && git config user.email t@t && git config user.name t
echo a > a && git add a && git commit -qm a
git checkout -qb feature && echo b > b && git add b && git commit -qm b
git checkout -q main && echo c > c && git add c && git commit -qm c && git checkout -q feature
