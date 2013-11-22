#!/bin/bash

echo === $0 ===
date "+%Y-%m-%d %H:%M"
echo ===

set -x
cd /home/ubuntu/seq-blog
git pull --rebase origin master

EXISTS=$(find source/_posts -name \*-$(cat .newblog|tr ' ' '-').markdown|wc -l)

if [ $EXISTS -eq 0 ] ; then 
  TITLE=$(head -1 .newblog)
  ./create_post.sh "$TITLE"
fi
