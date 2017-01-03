#!/bin/sh

# Copyright (C) 2016 Andrew Clemons, Wellington, New Zealand
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

set -e

for cmd in w3m git curl jsawk ; do
  if ! command -v "$cmd" > /dev/null 2>&1 ; then
    >&2 echo "This script requires $cmd to run."
    exit 1
  fi
done

SLACKBUILDS_DIR=${SLACKBUILDS_DIR:-~/workspace/slackbuilds.org}
MAINTAINER=${MAINTAINER:-andrew clemons}

if [ "x$MAINTAINER" = "x" ] ; then
 >&2 echo "maintainer?"
 exit 1
fi

cd "$SLACKBUILDS_DIR"
git pull --rebase

find . -name \*.info -exec sh -c "i=\"\$1\"; grep -i \"$MAINTAINER\" \"\$i\" > /dev/null" _ {} \; -print | while read -r project ; do
  # shellcheck source=/dev/null
  . "$project"

  echo "Checking for updates of $PRGNAM. Currently $VERSION"

  if [ "x$PRGNAM" = "xt-prot" ] ; then
    CURRENT="$(w3m -T text/html  -o frame=0 -o meta_refresh=0 -o auto_image=0 -dump http://www.escape.de/~tolot/mutt/t-prot/downloads/ | sed '/t-prot-/!d' | tail -n1 | sed 's/.*t-prot-\(.*\)\.tar\.gz.*/\1/')"
  elif case $PRGNAM in eclim|fzf|imapfilter|jsawk|kitchen-sync|rbenv|ruby-build) true ;; *) false ;; esac ; then
    USER="$(
      case $PRGNAM in
                   eclim) printf "%s\n" "ervandew" ;;
                     fzf) printf "%s\n" "junegunn" ;;
              imapfilter) printf "%s\n" "lefcha" ;;
                   jsawk) printf "%s\n" "micha" ;;
            kitchen-sync) printf "%s\n" "willbryant" ;;
        rbenv|ruby-build) printf "%s\n" "rbenv" ;;
                       *) printf "\n" ;;
      esac
    )"

    RESOURCE="$(
      case $PRGNAM in
        fzf|imapfilter|jsawk|kitchen-sync) printf "%s\n" "tags" ;;
                                        *) printf "%s\n" "releases" ;;
      esac
    )"

    FIELD="$(
     case $PRGNAM in
      fzf|imapfilter|jsawk|kitchen-sync) printf "%s\n" "name" ;;
                                      *) printf "%s\n" "tag_name" ;;
      esac
    )"

    if [ "x$PRGNAM" = "xkitchen-sync" ] ; then
      PRGNAM="$(printf "%s\n" "$PRGNAM" | tr '-' '_')"
    fi

    CURRENT="$(curl -s -H "Accept: application/json" "https://api.github.com/repos/$USER/$PRGNAM/$RESOURCE" | jsawk -n "if (\$_ == 0) out(this.$FIELD)" | sed 's/^v//')"
  elif [ "x$PRGNAM" = "xrun-one" ] ; then
    CURRENT="$(w3m -T text/html  -o frame=0 -o meta_refresh=0 -o auto_image=0 -dump https://launchpad.net/run-one/+download | sed '/^[[:digit:]\.]* release from the .* series/!d' | head -n1 | sed 's/^\([[:digit:]\.]*\) .*$/\1/')"
  else
    >&2 echo "Unknown program $PRGNAM"
    exit 2
  fi

  if [ "x$VERSION" != "x$CURRENT" ] ; then
    >&2 echo "Update detected for $PRGNAM. New Version $CURRENT"
  fi
done
