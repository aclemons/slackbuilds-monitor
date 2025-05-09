#!/bin/bash

# Copyright (C) 2016-2022 Andrew Clemons, Wellington New Zealand
# Copyright (C) 2022-2025 Andrew Clemons, Tokyo Japan
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
set -o pipefail

w3m_fetch() {
  w3m -T text/html  -o frame=0 -o meta_refresh=0 -o auto_image=0 -dump "$1"
}

for cmd in w3m git curl jq xmllint ; do
  if ! command -v "$cmd" > /dev/null 2>&1 ; then
    >&2 printf "This script requires %s to run.\n" "$cmd"
    exit 1
  fi
done

GITHUB_TOKEN="${GITHUB_TOKEN:-$(pass github | head -1)}"

SLACKBUILDS_DIR=${SLACKBUILDS_DIR:-~/workspace/slackbuilds.org}
MYSLACKBUILDS_DIR=${MYSLACKBUILDS_DIR:-~/workspace/slackbuilds}
HINTS_DIR=${HINTS_DIR:-~/workspace/slackrepo-local-hints}
MAINTAINER=${MAINTAINER:-andrew clemons}

if [[ -z $MAINTAINER ]] ; then
 >&2 printf "maintainer?\n"
 exit 1
fi

{
    find "$MYSLACKBUILDS_DIR" -name \*.info -maxdepth 3 -print
    find "$HINTS_DIR" -name \*.hint -maxdepth 3 -print
    find "$SLACKBUILDS_DIR" -name \*.info -maxdepth 3 -exec sh -c "i=\"\$1\"; grep -i \"$MAINTAINER\" \"\$i\" > /dev/null" _ {} \; -print
} | while read -r project ; do

  VERSION=
  PRGNAM=
  # shellcheck source=/dev/null
  . "$project"

  FILENAME="$(basename "$project")"
  EXTENSION="${FILENAME##*.}"
  FILENAME="${FILENAME%.*}"

  if [[ -z $VERSION ]] ; then
    continue
  fi

  if [[ $PRGNAM == "pandoc" ]] ; then
    # currently causes an HTTP 500 on hackage.haskell.org
    continue
  fi

  if [[ -z $PRGNAM ]] ; then
    PRGNAM="$FILENAME"
  fi

  if [[ $PRGNAM == henplus ]] || [[ $PRGNAM == vacation ]] || [[ $PRGNAM == picasa ]] || [[ $PRGNAM == sof-firmware ]] || [[ $PRGNAM == zulu-openjdk8 ]] || [[ $PRGNAM == zulu-openjdk11 ]] || [[ $PRGNAM == zulu-openjdk17 ]] || [[ $PRGNAM == zulu-openjdk21 ]] || [[ $PRGNAM == zulu-openjdk6 ]] || [[ $PRGNAM == zulu-openjdk7 ]] || [[ $PRGNAM == pyenv ]] || [[ $PRGNAM == qemu-user-static-bin ]] || [[ $PRGNAM == t-prot ]] ; then
    continue
  fi

  # pinned to last version which supported python2.
  if [[ $PRGNAM == python2-setuptools-scm ]] || [[ $PRGNAM == python2-pkgconfig ]] ; then
    continue
  fi

  # handled separately
  if case "$PRGNAM" in *l10n*) true ;; prosody-mod-*) true ;; *) false ;; esac; then
    continue
  fi

  if [[ $EXTENSION == hint ]] ; then
    printf "Checking for updates of %s. Currently %s (non-maintainer)\n" "$PRGNAM" "$VERSION"
  else
    if [[ -e "$HINTS_DIR/$PRGNAM.hint" ]] ; then
      # shellcheck source=/dev/null
      . "$HINTS_DIR/$PRGNAM.hint"
    fi

    printf "Checking for updates of %s. Currently %s\n" "$PRGNAM" "$VERSION"
  fi

  if [[ $PRGNAM == binfmt-support ]] ; then
    CURRENT="$(curl -f -s -H "Accept: application/json" "https://gitlab.com/api/v4/projects/22757105/repository/tags" | jq -r '.[0] | .name')"
  elif [[ $PRGNAM == eclipse-cpp ]] || [[ $PRGNAM == eclipse-java ]] || [[ $PRGNAM == eclipse-jee ]] || [[ $PRGNAM == eclipse-php ]] ; then
    CURRENT="$(w3m_fetch "https://www.eclipse.org/downloads/eclipse-packages/" | sed '/^Eclipse /!d' | grep Packages | sed 's/^Eclipse \(.*\) R Packages.*$/\1/;s/-//g;s/IDE //')"

    if [[ $CURRENT == "202503" ]] ; then
      CURRENT="4.35"
    fi
  elif [[ $PRGNAM == emailrelay ]]; then
    CURRENT="$(w3m_fetch "https://sourceforge.net/projects/emailrelay/files/emailrelay/" | sed -n '/^     Name/,$p' | sed -n '3p' | sed 's/^[[:space:]]*//' | sed 's/\([^ ]*\).*$/\1/')"
  elif [[ $PRGNAM == gajim ]]; then
    CURRENT="$(curl -f -s -H "Accept: application/json" "https://dev.gajim.org/api/v4/projects/30/repository/tags" | jq -r '.[0] | .name')"
  elif [[ $PRGNAM == gopls ]]; then
    CURRENT="$(w3m_fetch https://pkg.go.dev/golang.org/x/tools/gopls?tab=versions | sed -n '/Versions in this module/,$p' | sed 's/^v0$//' | sed -n '/^v/{s/^v//p;q}')"
  elif [[ $PRGNAM == jenkins ]]; then
    CURRENT="$(w3m_fetch "https://mirrors.jenkins.io/war-stable/" | sed '1,/^Parent Directory/d' | sed '1d' | sed -n '1p' | cut -d' ' -f1 | sed 's/\/$//')"
  elif case "$PRGNAM" in haskell-*) true ;; pandoc) true ;; *) false ;; esac; then
    HACKAGENAME="${PRGNAM#"haskell-"}"
    CURRENT="$(xmllint --xpath "string((//*[local-name()='item']/*[local-name()='title']/text())[1])" <(curl -f -s "https://hackage.haskell.org/package/$HACKAGENAME.rss") | cut -d ' ' -f1)"
    CURRENT="${CURRENT#"$HACKAGENAME"-}"
  elif [[ $PRGNAM == pre-commit ]]; then
    CURRENT="$(curl -f -s -H "Accept: application/json" https://pypi.org/pypi/pre-commit/json | jq -r '.releases | keys | last')"
  elif [[ $PRGNAM == python-axolotl-curve25519 ]]; then
    CURRENT="$(curl -f -s -H "Accept: application/json" https://pypi.org/pypi/python-axolotl-curve25519/json | jq -r '.releases  | keys | last')"
  elif [[ $PRGNAM == python3-cfgv ]]; then
    CURRENT="$(curl -f -s -H "Accept: application/json" https://pypi.org/pypi/cfgv/json | jq -r '.releases  | keys | last')"
  elif [[ $PRGNAM == python3-identify ]]; then
    CURRENT="$(curl -f -s -H "Accept: application/json" https://pypi.org/pypi/identify/json | jq -r '.releases  | keys | last')"
  elif [[ $PRGNAM == python-jeepney ]] || [[ $PRGNAM == python-css-parser ]] || [[ $PRGNAM == rfc6555 ]] ; then
    PYNAME="${PRGNAM#"python-"}"
    CURRENT="$(curl -f -s -H "Accept: application/json" "https://pypi.org/pypi/$PYNAME/json" | jq -r '.releases | keys | last')"
  elif [[ $PRGNAM == python-nbxmpp ]]; then
    CURRENT="$(curl -f -s -H "Accept: application/json" "https://dev.gajim.org/api/v4/projects/11/repository/tags" | jq -r '.[0] | .name')"
  elif [[ $PRGNAM == racer ]]; then
    CURRENT="$(curl -f -s -H "Accept: application/json" "https://crates.io/api/v1/crates/racer" | jq -r '.versions | first | .num')"
  elif case "$PRGNAM" in rubygem*) true ;; *) false ;; esac; then
    GEMNAME="${PRGNAM#"rubygem-"}"
    CURRENT="$(curl -f -s "https://rubygems.org/api/v1/gems/$GEMNAME.json" | jq -r '.version')"
  elif [[ $PRGNAM == run-one ]]; then
    CURRENT="$(w3m_fetch "https://launchpad.net/run-one/+download" | sed '/^[[:digit:]\.]* release from the .* series/!d' | head -n1 | sed 's/^\([[:digit:]\.]*\) .*$/\1/')"
  elif [[ $PRGNAM == t-prot ]]; then
    CURRENT="$(w3m_fetch "http://www.escape.de/~tolot/mutt/t-prot/downloads/" | sed '/t-prot-/!d' | tail -n1 | sed 's/.*t-prot-\(.*\)\.tar\.gz.*/\1/')"
  elif [[ $PRGNAM == vuescan ]]; then
    CURRENT="$(curl -f -s https://raw.githubusercontent.com/Homebrew/homebrew-cask/master/Casks/v/vuescan.rb | sed -n '/version /p' | sed "s/^[[:space:]]*//;s/'//g" | sed 's/"//g' | cut -d ' ' -f2)"
  else
    USER="$(
      case $PRGNAM in
                   actionlint) printf "%s\\n" "rhysd" ;;
                    alacritty) printf "%s\\n" "alacritty" ;;
               appstream-glib) printf "%s\\n" "hughsie" ;;
                         buku) printf "%s\\n" "jarun" ;;
                     bukubrow) printf "%s\\n" "SamHH" ;;
                           cw) printf "%s\\n" "lucagrulla" ;;
                        ddbsh) printf "%s\\n" "awslabs" ;;
                       disper) printf "%s\\n" "apeyser" ;;
                     dropbear) printf "%s\\n" "mkj" ;;
                docker-buildx) printf "%s\\n" "docker" ;;
                    early-ssh) printf "%s\\n" "gheja" ;;
                          exa) printf "%s\\n" "ogham" ;;
                          eza) printf "%s\\n" "eza-community" ;;
                           fd) printf "%s\\n" "sharkdp" ;;
                    fleet-bin) printf "%s\\n" "fleetdm" ;;
                        fwupd) printf "%s\\n" "fwupd" ;;
                          fzf) printf "%s\\n" "junegunn" ;;
                     git-fame) printf "%s\\n" "casperdcl" ;;
                golangci-lint) printf "%s\\n" "golangci" ;;
                   imapfilter) printf "%s\\n" "lefcha" ;;
                        jsawk) printf "%s\\n" "micha" ;;
                  json-parser) printf "%s\\n" "json-parser" ;;
                   kde1-*|qt1) printf "%s\\n" "KDE" ;;
             libreadline-java) printf "%s\\n" "aclemons" ;;
                      libjcat) printf "%s\\n" "hughsie" ;;
                    libsmbios) printf "%s\\n" "dell" ;;
                      libxmlb) printf "%s\\n" "hughsie" ;;
                     newsboat) printf "%s\\n" "newsboat" ;;
                 node-xoauth2) printf "%s\\n" "andris9" ;;
                   noto-emoji) printf "%s\\n" "googlefonts" ;;
                  osquery-bin) printf "%s\\n" "osquery" ;;
                         pnpm) printf "%s\\n" "pnpm" ;;
                python-argopt) printf "%s\\n" "casperdcl" ;;
               python-axolotl) printf "%s\\n" "tgalal" ;;
     python-mysql-replication) printf "%s\\n" "julien-duponchelle" ;;
           python-precis-i18n) printf "%s\\n" "byllyfish" ;;
          python-unicodedata2) printf "%s\\n" "fonttools" ;;
                       qtpass) printf "%s\\n" "IJHack" ;;
             rbenv|ruby-build) printf "%s\\n" "rbenv" ;;
                        rtw88) printf "%s\\n" "lwfinger" ;;
                      ripgrep) printf "%s\\n" "BurntSushi" ;;
                       rlwrap) printf "%s\\n" "hanslub42" ;;
                       rustup) printf "%s\\n" "rust-lang" ;;
           python2-selectors2) printf "%s\\n" "sethmlarson" ;;
                    slackroll) printf "%s\\n" "slackroll" ;;
                slack-osquery) printf "%s\\n" "aclemons" ;;
                         skim) printf "%s\\n" "skim-rs" ;;
              slack-libpurple) printf "%s\\n" "dylex" ;;
                    slackrepo) printf "%s\\n" "aclemons" ;;
              slackrepo-hints) printf "%s\\n" "aclemons" ;;
                      sslscan) printf "%s\\n" "rbsec" ;;
          svn-all-fast-export) printf "%s\\n" "svn-all-fast-export" ;;
                 tagainijisho) printf "%s\\n" "Gnurou" ;;
                 terraform-ls) printf "%s\\n" "hashicorp" ;;
                        tfenv) printf "%s\\n" "tfutils" ;;
                       tflint) printf "%s\\n" "terraform-linters" ;;
                      thefuck) printf "%s\\n" "nvbn" ;;
                 ttf-mononoki) printf "%s\\n" "madmalik" ;;
                      tofuenv) printf "%s\\n" "tofuutils" ;;
                        vtcol) printf "%s\\n" "phi-gamma" ;;
                       unison) printf "%s\\n" "bcpierce00" ;;
                            *) >&2 printf "Unknown program %s\\n" "$PRGNAM" && exit 1 ;;
      esac
    )"

    RESOURCE="$(
      case $PRGNAM in
        appstream-glib|disper|dropbear|exa|fwupd|fzf|imapfilter|jsawk|json-parser|libreadline-java|libjcat|libxmlb|newsboat|node-xoauth2|noto-emoji|python-axolotl|python-mysql-replication|qtpass|ruby-build|rustup|sslscan|svn-all-fast-export|slackrepo*|tagainijisho|unison|vtcol|skim) printf "%s\\n" "tags" ;;
                                                                                           early-ssh|kde1-*|qt1|rtw88|slack-libpurple) printf "%s\\n" "commits" ;;
                                                                                                                                                                           *) printf "%s\\n" "releases" ;;
      esac
    )"

    FIELD="$(
      case $PRGNAM in
        appstream-glib|disper|dropbear|exa|fwupd|fzf|imapfilter|jsawk|json-parser|libreadline-java|libjcat|libxmlb|newsboat|node-xoauth2|noto-emoji|python-axolotl|python-mysql-replication|qtpass|ruby-build|rustup|sslscan|svn-all-fast-export|slackrepo*|tagainijisho|unison|vtcol|skim) printf "%s\\n" "name" ;;
                                                                                            early-ssh|kde1-*|qt1|rtw88|slack-libpurple) printf "%s\\n" "sha" ;;
                                                                                                                                                                           *) printf "%s\\n" "tag_name" ;;
      esac
    )"

    if [[ $PRGNAM == bukubrow ]]; then
      PRGNAM="bukubrow-host"
    elif [[ $PRGNAM == ddbsh ]]; then
      PRGNAM="dynamodb-shell"
    elif [[ $PRGNAM == docker-buildx ]]; then
      PRGNAM="buildx"
    elif [[ $PRGNAM == fleet-bin ]]; then
      PRGNAM="fleet"
    elif [[ $PRGNAM == libreadline-java ]]; then
      PRGNAM="java-readline"
    elif [[ $PRGNAM == node-xoauth2 ]]; then
      PRGNAM="xoauth2"
    elif [[ $PRGNAM == osquery-bin ]]; then
      PRGNAM=osquery
    elif [[ $PRGNAM == python-unicodedata2 ]] || [[ $PRGNAM == python-argopt ]] || [[ $PRGNAM == python-precis-i18n ]] || [[ $PRGNAM == python2-selectors2 ]] ; then
      PRGNAM=${PRGNAM#python-}
      PRGNAM=${PRGNAM#python2-}
      if [[ $PRGNAM == precis-i18n ]] ; then
        PRGNAM=precis_i18n
      fi
    elif [[ $PRGNAM == svn-all-fast-export ]]; then
      PRGNAM="svn2git"
    elif [[ $PRGNAM == ttf-mononoki ]]; then
      PRGNAM="mononoki"
    fi

    JSON="$(curl -f --header "Authorization: Bearer $GITHUB_TOKEN" -s -H "Accept: application/json" "https://api.github.com/repos/$USER/$PRGNAM/$RESOURCE?per_page=100")"

    if [[ $PRGNAM == alacritty ]]; then
      JSON="$(printf '%s\n' "$JSON" | jq -r 'map(. | select(.tag_name | contains("-rc") | not))')"
    elif [[ $PRGNAM == dropbear ]] ; then
      JSON="$(printf '%s\n' "$JSON" | jq -r 'map(. | select(.name | startswith("DROPBEAR_")))')"
    elif [[ $PRGNAM == fwupd ]]; then
      JSON="$(printf '%s\n' "$JSON" | jq -r 'map(. | select(.name | startswith("fwupd_") | not))')"
    elif [[ $PRGNAM == noto-emoji ]]; then
      JSON="$(printf '%s\n' "$JSON" | jq -r 'map(. | select(.name | startswith("v201") or startswith("v202") | not))')"
    elif [[ $PRGNAM == pnpm ]]; then
      JSON="$(printf '%s\n' "$JSON" | jq -r 'map(. | select(.tag_name | contains("-rc") | not))')"
    elif [[ $PRGNAM == python-axolotl ]]; then
      JSON="$(printf '%s\n' "$JSON" | jq -r 'map(. | select(.name == "v0.1.6" | not))')"
    elif [[ $PRGNAM == osquery ]]; then
      JSON="$(printf '%s\n' "$JSON" | jq -r 'map(. | select(.prerelease != true))')"
    fi

    CURRENT="$(printf '%s\n' "$JSON" | jq -r "first | .$FIELD" | sed 's/^v//')"

    if [[ $PRGNAM == appstream-glib ]] ; then
      CURRENT="$(printf '%s\n' "$CURRENT" | sed -e 's/^appstream_glib_//' -e 's/_/./g')"
    elif [[ $PRGNAM == disper ]] ; then
      CURRENT="${CURRENT#disper-}"
    elif [[ $PRGNAM == dropbear ]] ; then
      CURRENT="${CURRENT#DROPBEAR_}"
    elif [[ $PRGNAM == fleet ]] ; then
      CURRENT="${CURRENT#fleet-v}"
    elif [[ $PRGNAM == slack-libpurple ]] || [[ $PRGNAM == early-ssh ]] ; then
      CURRENT="git$(printf "%s\\n" "$CURRENT" | sed -e 's/^\(.\{7\}\).*/\1/')"
    elif case "$PRGNAM" in kde1-*) true ;; *) false;; esac ; then
      CURRENT="1.1.2.git$(printf "%s\\n" "$CURRENT" | sed -e 's/^\(.\{7\}\).*/\1/')"
    elif [[ $PRGNAM == newsboat ]] ; then
      CURRENT="$(printf '%s\n' "$CURRENT" | sed 's/^r//')"
    elif [[ $PRGNAM == noto-emoji ]] ; then
      CURRENT="$(printf '%s\n' "$CURRENT" | sed 's/unicode13//' | tr -d -)"
      if [[ $CURRENT == "20200916_1" ]] ; then
        CURRENT="20200916"
      fi
    elif [[ $PRGNAM == qt1 ]] ; then
      CURRENT="1.45.git$(printf "%s\\n" "$CURRENT" | sed -e 's/^\(.\{7\}\).*/\1/')"
    elif [[ $PRGNAM == slackroll ]] ; then
      CURRENT="v$CURRENT"
    elif [[ $PRGNAM == sslscan ]] ; then
      CURRENT="$(printf '%s\n' "$CURRENT" | sed 's/-rbsec$//' | sed 's/-beta/_beta/')"
    elif [[ $PRGNAM == unicodedata2 ]] ; then
      CURRENT="$(printf '%s\n' "$CURRENT" | tr - _)"
    fi
  fi

  if [[ $VERSION != "$CURRENT" ]] ; then
    >&2 printf "Update detected for %s. New Version '%s'\\n" "$PRGNAM" "$CURRENT"
  fi
done
