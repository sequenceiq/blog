#!/bin/bash

export PATH="/usr/local/rbenv/shims:$HOME/.rbenv/bin:$PATH"

TITLE="$*"

rake new_post["${TITLE}"]
