#!/usr/bin/env bash
#
# MIT License
#
# Copyright (c) 2020 Yann Régis-Gianas
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

VERSION=0.1

usage () {
  cat <<'EOF'
Description
-----------
        This script retrieves all forks of a given gitlab project.

Usage
-----
          -h        Display this message.
          -v        Show version.
          -V        Activate verbose mode.

Variables
---------

        SERVER      is the URL to the Gitlab instance (must start with https://)
        TOKEN       is the personal access token
        BASE        is the identifier of the forked project

Optional variables
------------------
        OUTDIR      is the directory where forks are cloned (default is 'students')

Example
-------

        SERVER=http://my.gitlab-instance.org \
        TOKEN=sSAyTnigVb31f6nHhzPq           \
        BASE=uid/myproject                   \
        ./get-gitlab-forks.sh

Invariants
----------

        $SERVER/$BASE should point to the gitlab project homepage.

Resources
---------

        Please browse

           https://docs.gitlab.com/ee/user/profile/personal_access_tokens.html

        to learn how to obtain your personal access token.

EOF
  exit 0
}

###############
#  Main entry #
###############

process () {
  init
  parse_cmd "$@"
  check_vars
  get_forks
  show_synthesis
}

###############
#  Variables  #
###############

ROOT=$(pwd)
OUTDIR=${OUTDIR:-students}
VERBOSE=0

###############
#  Utilities  #
###############

check_var () {
  if [ -z ${!1+x} ]; then
      echo "$1" is undefined. Rerun with -h for details.
      exit 1
  fi
}

request () {
  curl -s --header "Private-Token: $TOKEN" "$1"
}

api () {
  request "$SERVER/api/v4/${1}/${2}?per_page=100"
}

info () {
  if [ "$VERBOSE" == 1 ]; then
    echo "info> $*"
  fi
}

unquote () {
  echo "$1" | tr -d '"'
}

########################
# Command line parsing #
########################

version () {
  echo $VERSION
  exit 0
}

parse_cmd () {
  while getopts "hVv" arg; do
    case $arg in
      h)
        usage
        ;;
      V)
        VERBOSE=1
        ;;
      v)
        version
        ;;
      *)
        usage
        ;;
    esac
  done
}

##################
# Initialization #
##################

check_prog () {
  info "Looking for $1..." \
  "$(if ! which "$1"; then
      echo "not found! Follow installation instructions from $2"
      exit 1
  fi)"
}

check_deps () {
  check_prog jq   'https://stedolan.github.io/jq/'
  check_prog curl 'https://curl.haxx.se/'

  if [ "$(echo "${BASH_VERSION}" | cut -f1 -d.)" -lt 4 ]; then
     echo 'Sorry I need bash > 4.'
     exit 1
  fi
}

setup_workspace () {
  mkdir -p "$OUTDIR"
}

init () {
  setup_workspace
  check_deps
}

check_vars () {

  ##########
  # Server #
  ##########
  #
  # We need a Gitlab server to interact with.
  #
  check_var SERVER

  ################
  # Base project #
  ################
  #
  # We identify a base project using its URL suffix stored in $BASE:
  # $SERVER/$BASE hould point to the URL of the gitlab project home.
  #
  check_var BASE
  BASE=${BASE/'/'/'%2F'}

  ################
  # Gitlab token #
  ################
  #
  # We use a gitlab personal access token.
  #
  check_var TOKEN
}

declare -A users
declare -A commits
declare -A lastmod
declare -A visibility

get_forks () {
  for PAGE in `seq 1 1000`
  do
    FORKS=$(api projects "$BASE/forks?per_page=100&page=$PAGE" \
                | jq -c '.[] | { url : .ssh_url_to_repo, v : .visibility }')
    if [ $? -ne 0 ]; then break; fi
    if [ "x$FORKS" = "x" ]; then break; fi
    for DATA in $FORKS
    do
      URL="$(echo "$DATA" | jq '.url')"
      URL="$(unquote "$URL")"

      info '*' Processing "$URL"

      USER="$(echo "$URL" | cut -f2 -d: | cut -d/ -f1)"
      OUT="$OUTDIR/$USER"

      info '**' Retrieving latest version of fork "$USER"

      if [ ! -d "$OUT" ]; then
          git clone "$URL" "$OUT" >/dev/null 2>&1
          if [ $? -eq 0 ]; then
              users["$USER"]='new'
          else
              users["$USER"]='denied'
              commits["$USER"]='?'
              lastmod["$USER"]='?'
              visibility["$USER"]='denied'
              continue
          fi
      else
          cd "$OUT" && git pull --rebase; cd ../..
          users["$USER"]='up to date'
      fi

      info '**' Analyzing "$USER"

      cd "$OUT" || exit
      commits[$USER]=$(git rev-list --all --count)
      lastmod[$USER]=$(git log -1 --date=short --format=%cd)
      visibility[$USER]="$(unquote "$(echo "$DATA" | jq '.v')")"
      cd "$ROOT" || exit
    done
  done
}

show_synthesis () {

  info '* Synthesis'

  echo 'Identifier,Number of commits,Last modification,Visibility' > synthesis.csv
  for user in "${!users[@]}"; do
      echo "$user,${commits[$user]},${lastmod[$user]},${visibility[$user]}" >> synthesis.csv
  done

  column -t -s, < synthesis.csv | while read -r line; do
      line=${line/public/\\033[0;31mpublic\\033[0m}
      line=${line/denied/\\033[0;31mdenied\\033[0m}
      echo -e "$line"
  done
}

process "$@"
