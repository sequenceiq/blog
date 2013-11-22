#!/bin/bash
export PATH="/usr/local/rbenv/shims:$HOME/.rbenv/bin:$PATH"


cd /home/ubuntu/seq-blog
TITLE="$*"
rake new_post["${TITLE}"]

git add source
git commit -m "[script] blog created: $TITLE"
git push hub master
