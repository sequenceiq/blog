#!/bin/bash

echo === $0 ===
date "+%Y-%m-%d %H:%M"
echo ===

export PATH="/usr/local/rbenv/shims:$HOME/.rbenv/bin:$PATH"
cd /home/ubuntu/seq-blog

git stash
git pull --rebase origin master
rake generate
rake deploy
git stash pop
