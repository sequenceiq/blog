#!/bin/bash

export PATH="/usr/local/rbenv/shims:$HOME/.rbenv/bin:$PATH"
cd /home/ubuntu/seq-blog

git stash
git pull origin master --rebase
rake generate
rake deploy
git stash pop
