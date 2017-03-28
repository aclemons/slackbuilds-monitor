#!/bin/bash

# Copyright (C) 2016-2017 Andrew Clemons, Wellington, New Zealand
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

w3m_fetch() {
  w3m -T text/html  -o frame=0 -o meta_refresh=0 -o auto_image=0 -dump "$1"
}

set -e

for cmd in w3m git curl jsawk ; do
  if ! command -v "$cmd" > /dev/null 2>&1 ; then
    >&2 echo "This script requires $cmd to run."
    exit 1
  fi
done

SLACKBUILDS_DIR=${SLACKBUILDS_DIR:-~/workspace/slackbuilds.org}
HINTS_DIR=${HINTS_DIR:-~/workspace/slackrepo-hints}
MAINTAINER=${MAINTAINER:-andrew clemons}

if [ "x$MAINTAINER" = "x" ] ; then
 >&2 echo "maintainer?"
 exit 1
fi

for dir in "$SLACKBUILDS_DIR" "$HINTS_DIR" ; do
  (
    cd "$dir"
    git pull --rebase
  )
done

{
    find "$HINTS_DIR" -name \*.hint
    find "$SLACKBUILDS_DIR" -name \*.info -exec sh -c "i=\"\$1\"; grep -i \"$MAINTAINER\" \"\$i\" > /dev/null" _ {} \; -print
} | while read -r project ; do
  VERSION=
  PRGNAM=
  # shellcheck source=/dev/null
  . "$project"

  FILENAME="$(basename "$project")"
  EXTENSION="${FILENAME##*.}"
  FILENAME="${FILENAME%.*}"

  if [ "x$PRGNAM" = "x" ] ; then
    PRGNAM="$FILENAME"
  fi

  if [ "x$VERSION" = "x" ] || [ "x$PRGNAM" = "xlibqsqlpsql" ]; then
    continue
  fi

  if [ "x$EXTENSION" = "xhint" ] ; then
    echo "Checking for updates of $PRGNAM. Currently $VERSION (non-maintainer)"
  else
    echo "Checking for updates of $PRGNAM. Currently $VERSION"
  fi

  if [ "$PRGNAM" = "eclipse-cpp" ] || [ "$PRGNAM" = "eclipse-java" ] || [ "$PRGNAM" = "eclipse-jee" ] ; then
    CURRENT="$(w3m_fetch "https://www.eclipse.org/downloads/eclipse-packages/" | sed '/^Eclipse /!d' | head -n1 | sed 's/^Eclipse .*(\(.*\)) Release.*$/\1/')"
  elif [ "$PRGNAM" = "dropbear" ] ; then
    CURRENT="$(w3m_fetch "https://matt.ucc.asn.au/dropbear/" | sed -n '/^Release /,$p' | sed -n '1p' | sed 's/^Release \(.*\) is latest\.$/\1/')"
  elif [ "$PRGNAM" = "dovecot" ] ; then
    CURRENT="$(w3m_fetch "http://www.dovecot.org/releases/2.2/" | sed -n '/dovecot-2\.2\.[[:digit:]]*\.tar\.gz[[:space:]].*$/p' | sed '$!d' | sed 's/.*dovecot-\(2\.2\.[[:digit:]]*\)\.tar\.gz[[:space:]].*$/\1/')"
  elif [ "$PRGNAM" = "postgrey" ] ; then
    CURRENT="$(w3m_fetch "http://postgrey.schweikert.ch/pub/" | sed -n '/postgrey-/p' | sed '$d' | sed '$!d' | sed 's/^.*postgrey-\(.*\)\.tar\.gz.*$/\1/')"
  elif [ "$PRGNAM" = "emailrelay" ] ; then
    CURRENT="$(w3m_fetch "https://sourceforge.net/projects/emailrelay/files/emailrelay/" | sed -n '/^      Name/,$p' | sed -n '3p' | sed 's/^[[:space:]]*//' | sed 's/\([^ ]*\).*$/\1/')"
  elif [ "$PRGNAM" = "t-prot" ] ; then
    CURRENT="$(w3m_fetch "http://www.escape.de/~tolot/mutt/t-prot/downloads/" | sed '/t-prot-/!d' | tail -n1 | sed 's/.*t-prot-\(.*\)\.tar\.gz.*/\1/')"
  elif [ "$PRGNAM" = "postfix" ] ; then
    CURRENT="$(w3m_fetch "ftp://ftp.pca.dfn.de/pub/tools/net/postfix/official/" | sed -n '/^postfix-3\.1.*tar\.gz.*$/p' | sed '$!d' | sed 's/^postfix-\(3\.1.*\)\.tar\.gz.*$/\1/')"
  elif [ "$PRGNAM" = "postgresql" ] ; then
    CURRENT="$(w3m_fetch "https://www.postgresql.org/ftp/source/" | sed -n '/^v9\.6/p' | sed -n '1 s/^v\(9\.6\.[[:digit:]]*\).*$/\1/p')"
  elif [ "$PRGNAM" = "python-axolotl-curve25519" ] ; then
    CURRENT="$(curl -s -H "Accept: application/json" "https://pypi.python.org/pypi/python-axolotl-curve25519/json" | jsawk "return Object.keys(this.releases)[0]")"
  elif [ "$PRGNAM" = "prosody" ] ; then
		CURRENT="$(xmllint --xpath "string((//*[local-name()='entry']/*[local-name()='link']//@href)[1])" <(curl -s https://hg.prosody.im/0.10/atom-log) | sed 's/http:/https:/')"
    CURRENT="0.10.r$(w3m_fetch "$CURRENT" | sed -n '/^changeset /p' | sed 's/^changeset \(.*\)$/\1/')"
  elif [ "$PRGNAM" = "run-one" ] ; then
    CURRENT="$(w3m_fetch "https://launchpad.net/run-one/+download" | sed '/^[[:digit:]\.]* release from the .* series/!d' | head -n1 | sed 's/^\([[:digit:]\.]*\) .*$/\1/')"
  elif case $PRGNAM in cargo|cargo-vendor|eclim|fzf|gajim|groovy|imapfilter|jsawk|kitchen-sync|noto-emoji|python-axolotl|python-fonttools|python-unicodedata2|qtpass|rbenv|rlwrap|ruby-build|rust|slackroll|sslscan|svn-all-fast-export|verm|vtcol) true ;; *) false ;; esac ; then
    USER="$(
      case $PRGNAM in
                   cargo) printf "%s\n" "rust-lang" ;;
            cargo-vendor) printf "%s\n" "alexcrichton" ;;
                   eclim) printf "%s\n" "ervandew" ;;
                     fzf) printf "%s\n" "junegunn" ;;
                   gajim) printf "%s\n" "gajim" ;;
                  groovy) printf "%s\n" "apache" ;;
              imapfilter) printf "%s\n" "lefcha" ;;
                   jsawk) printf "%s\n" "micha" ;;
       kitchen-sync|verm) printf "%s\n" "willbryant" ;;
              noto-emoji) printf "%s\n" "googlei18n" ;;
          python-axolotl) printf "%s\n" "tgalal" ;;
        python-fonttools) printf "%s\n" "fonttools" ;;
     python-unicodedata2) printf "%s\n" "mikekap" ;;
                  qtpass) printf "%s\n" "IJHack" ;;
        rbenv|ruby-build) printf "%s\n" "rbenv" ;;
                  rlwrap) printf "%s\n" "hanslub42" ;;
                    rust) printf "%s\n" "rust-lang" ;;
               slackroll) printf "%s\n" "rg3" ;;
                 sslscan) printf "%s\n" "rbsec" ;;
     svn-all-fast-export) printf "%s\n" "svn-all-fast-export" ;;
                   vtcol) printf "%s\n" "phi-gamma" ;;
                       *) printf "\n" ;;
      esac
    )"

    RESOURCE="$(
      case $PRGNAM in
        cargo|cargo-vendor|fzf|gajim|groovy|imapfilter|jsawk|kitchen-sync|python-axolotl|qtpass|rust|sslscan|svn-all-fast-export|verm|vtcol) printf "%s\n" "tags" ;;
                                                                                                                                 noto-emoji) printf "%s\n" "commits" ;;
                                                                                                                                          *) printf "%s\n" "releases" ;;
      esac
    )"

    FIELD="$(
      case $PRGNAM in
        cargo|cargo-vendor|fzf|gajim|groovy|imapfilter|jsawk|kitchen-sync|python-axolotl|qtpass|rust|sslscan|svn-all-fast-export|verm|vtcol) printf "%s\n" "name" ;;
                                                                                                                                 noto-emoji) printf "%s\n" "sha" ;;
                                                                                                                                          *) printf "%s\n" "tag_name" ;;
      esac
    )"

    if [ "$PRGNAM" = "kitchen-sync" ] ; then
      PRGNAM="$(printf "%s\n" "$PRGNAM" | tr '-' '_')"
    elif [ "$PRGNAM" = "python-fonttools" ] || [ "$PRGNAM" = "python-unicodedata2" ] ; then
      PRGNAM="$(printf "%s\n" "$PRGNAM" | sed 's/^python-//' )"
    elif [ "$PRGNAM" = "python-fonttools" ] ; then
      PRGNAM="$(printf "%s\n" "$PRGNAM" | tr 'qp' 'QP')"
    elif [ "$PRGNAM" = "svn-all-fast-export" ] ; then
      PRGNAM="svn2git"
    fi

    JSON="$(curl -f --user "aclemons:$(pass github | head -1)" -s -H "Accept: application/json" "https://api.github.com/repos/$USER/$PRGNAM/$RESOURCE")"

    if [ "$PRGNAM" = "python-axolotl" ] ; then
      JSON="$(printf '%s\n' "$JSON" | jsawk 'if (this.name === "v0.1.6") return null')"
    elif [ "$PRGNAM" = "cargo" ] ; then
      JSON="$(printf '%s\n' "$JSON" | jsawk 'if (this.name === "v0.0.1-pre" || this.name === "homu-tmp") return null')"
    elif [ "$PRGNAM" = "rust" ] ; then
      JSON="$(printf '%s\n' "$JSON" | jsawk 'if (this.name.substring(0, 8) === "release-") return null')"
    elif [ "$PRGNAM" = "verm" ] ; then
      JSON="$(printf '%s\n' "$JSON" | jsawk 'if (this.name.substring(0, 5) === "test.") return null')"
    fi

    CURRENT="$(printf '%s\n' "$JSON" | jsawk -n "if (\$_ == 0) out(this.$FIELD)" | sed 's/^v//')"

    if [ "$PRGNAM" = "slackroll" ] ; then
      CURRENT="v$CURRENT"
    elif [ "$PRGNAM" = "noto-emoji" ] ; then
      CURRENT="git$(echo "$CURRENT" | sed -e 's/^\(.\{7\}\).*/\1/')"
    elif [ "$PRGNAM" = "sslscan" ] || [ "$PRGNAM" = "unicodedata2" ] ; then
      CURRENT="$(printf '%s\n' "$CURRENT" | tr - _)"
    elif [ "$PRGNAM" = "gajim" ] ; then
      CURRENT="$(printf '%s\n' "$CURRENT" | sed 's/^gajim-//')"
    elif [ "$PRGNAM" = "groovy" ] ; then
      CURRENT="$(printf '%s\n' "$CURRENT" | tr _ . | sed 's/^GROOVY\.//')"
    fi
  else
    >&2 echo "Unknown program $PRGNAM"
    exit 2
  fi

  if [ "x$VERSION" != "x$CURRENT" ] ; then
    >&2 echo "Update detected for $PRGNAM. New Version $CURRENT"
  fi
done
