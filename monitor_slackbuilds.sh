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

set -e

w3m_fetch() {
  w3m -T text/html  -o frame=0 -o meta_refresh=0 -o auto_image=0 -dump "$1"
}

for cmd in w3m git curl jsawk ; do
  if ! command -v "$cmd" > /dev/null 2>&1 ; then
    >&2 echo "This script requires $cmd to run."
    exit 1
  fi
done

SLACKBUILDS_DIR=${SLACKBUILDS_DIR:-~/workspace/slackbuilds.org}
MYSLACKBUILDS_DIR=${MYSLACKBUILDS_DIR:-~/workspace/slackbuilds}
HINTS_DIR=${HINTS_DIR:-~/workspace/slackrepo-hints}
MAINTAINER=${MAINTAINER:-andrew clemons}

if [[ -z $MAINTAINER ]] ; then
 >&2 echo "maintainer?"
 exit 1
fi

for dir in "$SLACKBUILDS_DIR" "$HINTS_DIR" "$MYSLACKBUILDS_DIR" ; do
  (
    cd "$dir"
#    git pull --rebase
  )
done

{
    find "$HINTS_DIR" -name \*.hint
    find "$SLACKBUILDS_DIR" -name \*.info -exec sh -c "i=\"\$1\"; grep -i \"$MAINTAINER\" \"\$i\" > /dev/null" _ {} \; -print
    find "$MYSLACKBUILDS_DIR" -name \*.info -print
} | while read -r project ; do

  VERSION=
  PRGNAM=
  # shellcheck source=/dev/null
  . "$project"

  FILENAME="$(basename "$project")"
  EXTENSION="${FILENAME##*.}"
  FILENAME="${FILENAME%.*}"

  if [[ -z $PRGNAM ]] ; then
    PRGNAM="$FILENAME"
  fi

  if [[ -z $VERSION ]] || [[ $PRGNAM == libqsqlpsql ]] || [[ $PRGNAM == sbt ]] || [[ $PRGNAM == henplus ]] || [[ $PRGNAM == remacs ]] || [[ $PRGNAM == chkboot ]] || [[ $PRGNAM == mssql-server ]] || [[ $PRGNAM == vacation ]] || [[ $PRGNAM == picasa ]] ; then
    continue
  fi

  if case "$PRGNAM" in oracle*) true ;; *l10n*) true ;; prosody-mod-*) true ;; *) false ;; esac; then
    continue
  fi

  if [[ $EXTENSION == hint ]] ; then
    echo "Checking for updates of $PRGNAM. Currently $VERSION (non-maintainer)"
  else
    echo "Checking for updates of $PRGNAM. Currently $VERSION"
  fi

  if [[ $PRGNAM == eclipse-cpp ]] || [[ $PRGNAM == eclipse-java ]] || [[ $PRGNAM == eclipse-jee ]] ; then
    CURRENT="$(w3m_fetch "https://www.eclipse.org/downloads/eclipse-packages/" | sed '/^Eclipse /!d' | head -n1 | sed 's/^Eclipse .*(\(.*\)) Release.*$/\1/')"
  elif [[ $PRGNAM == dropbear ]]; then
    CURRENT="$(w3m_fetch "https://matt.ucc.asn.au/dropbear/" | sed -n '/^Release /,$p' | sed -n '1p' | sed 's/^Release \(.*\) is latest\.$/\1/')"
  elif [[ $PRGNAM == postgrey ]]; then
    CURRENT="$(w3m_fetch "http://postgrey.schweikert.ch/pub/" | sed -n '/postgrey-/p' | sed '$d' | sed '$!d' | sed 's/^.*postgrey-\(.*\)\.tar\.gz.*$/\1/')"
  elif [[ $PRGNAM == emailrelay ]]; then
    CURRENT="$(w3m_fetch "https://sourceforge.net/projects/emailrelay/files/emailrelay/" | sed -n '/^      Name/,$p' | sed -n '3p' | sed 's/^[[:space:]]*//' | sed 's/\([^ ]*\).*$/\1/')"
  elif [[ $PRGNAM == t-prot ]]; then
    CURRENT="$(w3m_fetch "http://www.escape.de/~tolot/mutt/t-prot/downloads/" | sed '/t-prot-/!d' | tail -n1 | sed 's/.*t-prot-\(.*\)\.tar\.gz.*/\1/')"
  elif [[ $PRGNAM == postfix ]]; then
    CURRENT="$(w3m_fetch "ftp://ftp.pca.dfn.de/pub/tools/net/postfix/official/" | sed -n '/^postfix-3\.1.*tar\.gz.*$/p' | sed '$!d' | sed 's/^postfix-\(3\.1.*\)\.tar\.gz.*$/\1/')"
  elif [[ $PRGNAM == postgresql ]]; then
    CURRENT="$(w3m_fetch "https://www.postgresql.org/ftp/source/" | sed -n '/^v9\.6/p' | sed -n '1 s/^v\(9\.6\.[[:digit:]]*\).*$/\1/p')"
  elif [[ $PRGNAM == python-axolotl-curve25519 ]]; then
    CURRENT="$(curl -s -H "Accept: application/json" "https://pypi.python.org/pypi/python-axolotl-curve25519/json" | jsawk "return Object.keys(this.releases)[0]")"
  elif [[ $PRGNAM == prosody ]]; then
    CURRENT="$(xmllint --xpath "string((//*[local-name()='entry']/*[local-name()='link']//@href)[1])" <(curl -s https://hg.prosody.im/0.10/atom-log) | sed 's/http:/https:/')"
    CURRENT="0.10.r$(w3m_fetch "$CURRENT" | sed -n '/^changeset /p' | sed 's/^changeset \(.*\)$/\1/')"
  elif [[ $PRGNAM == run-one ]]; then
    CURRENT="$(w3m_fetch "https://launchpad.net/run-one/+download" | sed '/^[[:digit:]\.]* release from the .* series/!d' | head -n1 | sed 's/^\([[:digit:]\.]*\) .*$/\1/')"
  else
    USER="$(
      case $PRGNAM in
               alacritty) printf "%s\n" "jwilm" ;;
          appstream-glib) printf "%s\n" "hughsie" ;;
            cargo-vendor) printf "%s\n" "alexcrichton" ;;
                   eclim) printf "%s\n" "ervandew" ;;
                  efivar) printf "%s\n" "rhboot" ;;
                     exa) printf "%s\n" "ogham" ;;
                   fwupd) printf "%s\n" "hughsie" ;;
                fwupdate) printf "%s\n" "rhboot" ;;
                     fzf) printf "%s\n" "junegunn" ;;
                   gajim) printf "%s\n" "gajim" ;;
                  groovy) printf "%s\n" "apache" ;;
                git-fame) printf "%s\n" "casperdcl" ;;
      haskell-ShellCheck) printf "%s\n" "koalaman" ;;
              imapfilter) printf "%s\n" "lefcha" ;;
                   jsawk) printf "%s\n" "micha" ;;
              kde1-*|qt1) printf "%s\n" "KDE" ;;
       kitchen-sync|verm) printf "%s\n" "willbryant" ;;
        libreadline-java) printf "%s\n" "aclemons" ;;
                  mrustc) printf "%s\n" "thepowersgang" ;;
            node-xoauth2) printf "%s\n" "andris9" ;;
              noto-emoji) printf "%s\n" "googlei18n" ;;
          python-axolotl) printf "%s\n" "tgalal" ;;
        python-fonttools) printf "%s\n" "fonttools" ;;
           python-nbxmpp) printf "%s\n" "gajim" ;;
     python-unicodedata2) printf "%s\n" "mikekap" ;;
                  qtpass) printf "%s\n" "IJHack" ;;
        rbenv|ruby-build) printf "%s\n" "rbenv" ;;
                 ripgrep) printf "%s\n" "BurntSushi" ;;
                  rlwrap) printf "%s\n" "hanslub42" ;;
               rtl8192eu) printf "%s\n" "Mange" ;;
                    rust) printf "%s\n" "rust-lang" ;;
               slackroll) printf "%s\n" "rg3" ;;
                 sslscan) printf "%s\n" "rbsec" ;;
     svn-all-fast-export) printf "%s\n" "svn-all-fast-export" ;;
                  rustup) printf "%s\n" "rust-lang-nursery" ;;
              slack-term) printf "%s\n" "jvalduvieco" ;;
            ttf-mononoki) printf "%s\n" "madmalik" ;;
                   vtcol) printf "%s\n" "phi-gamma" ;;
                       *) >&2 printf "Unknown program %s\n" "$PRGNAM" && exit 1 ;;
      esac
    )"

    RESOURCE="$(
      case $PRGNAM in
        appstream-glib|cargo-vendor|exa|fwupd|fzf|gajim|groovy|haskell-ShellCheck|imapfilter|jsawk|kitchen-sync|libreadline-java|node-xoauth2|python-axolotl|python-nbxmpp|qtpass|ripgrep|rust|rustup|sslscan|svn-all-fast-export|verm|vtcol) printf "%s\n" "tags" ;;
                                                                                                                 alacritty|kde1-*|mrustc|noto-emoji|qt1|rtl8192eu|slack-term) printf "%s\n" "commits" ;;
                                                                                                                                                                           *) printf "%s\n" "releases" ;;
      esac
    )"

    FIELD="$(
      case $PRGNAM in
        appstream-glib|cargo-vendor|exa|fwupd|fzf|gajim|groovy|haskell-ShellCheck|imapfilter|jsawk|kitchen-sync|libreadline-java|node-xoauth2|python-axolotl|python-nbxmpp|qtpass|ripgrep|rust|rustup|sslscan|svn-all-fast-export|verm|vtcol) printf "%s\n" "name" ;;
                                                                                                                 alacritty|kde1-*|mrustc|noto-emoji|qt1|rtl8192eu|slack-term) printf "%s\n" "sha" ;;
                                                                                                                                                                           *) printf "%s\n" "tag_name" ;;
      esac
    )"

    if [[ $PRGNAM == haskell-ShellCheck ]]; then
      PRGNAM="$(printf "%s\n" "$PRGNAM" | cut -d- -f2 | tr '[:upper:]' '[:lower:]')"
    elif [[ $PRGNAM == kitchen-sync ]]; then
      PRGNAM="$(printf "%s\n" "$PRGNAM" | tr '-' '_')"
    elif [[ $PRGNAM == libreadline-java ]]; then
      PRGNAM="java-readline"
    elif [[ $PRGNAM == node-xoauth2 ]]; then
      PRGNAM="xoauth2"
    elif [[ $PRGNAM == python-fonttools ]] || [[ $PRGNAM == python-unicodedata2 ]]; then
      PRGNAM="$(printf "%s\n" "$PRGNAM" | sed 's/^python-//' )"
    elif [[ $PRGNAM == python-fonttools ]]; then
      PRGNAM="$(printf "%s\n" "$PRGNAM" | tr 'qp' 'QP')"
    elif [[ $PRGNAM == rtl8192eu ]]; then
      PRGNAM="$PRGNAM-linux-driver"
    elif [[ $PRGNAM == rustup ]]; then
      PRGNAM="$PRGNAM.rs"
    elif [[ $PRGNAM == svn-all-fast-export ]]; then
      PRGNAM="svn2git"
    elif [[ $PRGNAM == ttf-mononoki ]]; then
      PRGNAM="mononoki"
    fi

    JSON="$(curl -f --user "aclemons:$(pass github | head -1)" -s -H "Accept: application/json" "https://api.github.com/repos/$USER/$PRGNAM/$RESOURCE")"

    if [[ $PRGNAM == python-axolotl ]]; then
      JSON="$(printf '%s\n' "$JSON" | jsawk 'if (this.name === "v0.1.6") return null')"
    elif [[ $PRGNAM == cargo-vendor ]]; then
      JSON="$(printf '%s\n' "$JSON" | jsawk 'if (this.name === "v0.0.1-pre" || this.name === "0.10.0" || this.name === "0.9.0" || this.name === "0.8.0" || this.name === "0.7.0" || this.name === "0.6.0" || this.name === "0.5.0" || this.name === "0.4.0" || this.name === "0.3.0" || this.name === "0.2.0") return null')"
    elif [[ $PRGNAM == groovy ]]; then
      JSON="$(printf '%s\n' "$JSON" | jsawk 'if (this.name.indexOf("ALPHA") >= 0) return null')"
    elif [[ $PRGNAM == ripgrep ]]; then
      JSON="$(printf '%s\n' "$JSON" | jsawk 'if (this.name.substring(0, 8) === "wincolor" || this.name.substring(0, 9) === "termcolor" || this.name.substring(0, 6) === "ignore" || this.name.substring(0, 4) === "grep" || this.name.substring(0, 7) === "globset") return null')"
    elif [[ $PRGNAM == rust ]]; then
      JSON="$(printf '%s\n' "$JSON" | jsawk 'if (this.name.substring(0, 8) === "release-") return null')"
    elif [[ $PRGNAM == verm ]]; then
      JSON="$(printf '%s\n' "$JSON" | jsawk 'if (this.name.substring(0, 5) === "test.") return null')"
    fi

    CURRENT="$(printf '%s\n' "$JSON" | jsawk -n "if (\$_ == 0) out(this.$FIELD)" | sed 's/^v//')"

    if [[ $PRGNAM == appstream-glib ]] ; then
      CURRENT="$(echo "$CURRENT" | sed -e 's/^appstream_glib_//' -e 's/_/./g')"
    elif [[ $PRGNAM == slackroll ]] ; then
      CURRENT="v$CURRENT"
    elif [[ $PRGNAM == noto-emoji ]] || [[ $PRGNAM == mrustc ]] || [[ $PRGNAM == alacritty ]] || [[ $PRGNAM == "slack-term" ]]; then
      CURRENT="git$(printf "%s\n" "$CURRENT" | sed -e 's/^\(.\{7\}\).*/\1/')"
    elif case "$PRGNAM" in kde1-*) true ;; *) false;; esac ; then
      CURRENT="1.1.2.git$(printf "%s\n" "$CURRENT" | sed -e 's/^\(.\{7\}\).*/\1/')"
    elif [[ $PRGNAM == sslscan ]] ; then
      CURRENT="$(printf '%s\n' "$CURRENT" | sed 's/-rbsec$//')"
    elif [[ $PRGNAM == unicodedat-la2 ]] ; then
      CURRENT="$(printf '%s\n' "$CURRENT" | tr - _)"
    elif [[ $PRGNAM == gajim ]] ; then
      CURRENT="$(printf '%s\n' "$CURRENT" | sed 's/^gajim-//')"
    elif [[ $PRGNAM == python-nbxmpp ]] ; then
      CURRENT="$(printf '%s\n' "$CURRENT" | sed 's/^nbxmpp-//')"
    elif [[ $PRGNAM == qt1 ]] ; then
      CURRENT="1.45.git$(printf "%s\n" "$CURRENT" | sed -e 's/^\(.\{7\}\).*/\1/')"
    elif [[ $PRGNAM == groovy ]] ; then
      CURRENT="$(printf '%s\n' "$CURRENT" | tr _ . | sed 's/^GROOVY\.//')"
    fi
  fi

  if [[ $VERSION != "$CURRENT" ]] ; then
    >&2 printf "Update detected for %s. New Version '%s'\n" "$PRGNAM" "$CURRENT"
  fi
done
