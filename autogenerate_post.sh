#!/bin/bash

set -x

cd /home/ubuntu/seq-blog
git pull --rebase origin master

EXISTS=$(find public/blog/blog/ -name $(cat .newblog|tr ' ' '-') -type d|wc -l)

if [ $EXISTS -eq 0 ] ; then 
  TITLE=$(head -1 .newblog)
  ./create_post.sh "$TITLE"
fi
