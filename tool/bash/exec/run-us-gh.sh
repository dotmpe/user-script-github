#!/bin/bash
#
# Copyright (c) 2026 .mpe  <me@dotmpe.com>
#
# Distributed under terms of the MIT license.
set -euo pipefail
shopt -s failglob nullglob
IFS=$' \t\n'

[[ ! -e .env.sh ]] || \builtin . ./.env.sh

: "${US_SKELETON_DIR:=/src/local/user-script-template+dev}"
PATH+=:"${US_SKELETON_DIR:?}/tool/local"

scr_pre=tool/local
PATH+=:$scr_pre

\builtin . setup_common.bash
\builtin . usenv_common.bash
\builtin . env_common.bash

# us-parts config and entry-point

SCRIPTPATH+=:$PWD/tool/bash/part
US_GH_REPO_LIMIT=200
US_GH_OWNERS=dotmpe\ user-tools
usp us-gh

case "${0##*/}" in
  ( run-us-gh.* )
      case "${1:---tag}" in
        ( --fetch )              ${us_gh_pre:?}fetch-repolist.tsv
          ;;
        ( --fetch-details )      ${us_gh_pre:?}fetch-repolist-details.tsv
          ;;
        ( --tag )                ${us_gh_pre:?}tag-repolist
          ;;
        ( --sync )               ${us_gh_pre:?}tag-repolist.sync
          ;;
        ( --status )             ${us_gh_pre:?}workflow-status "${@:2}"
          ;;
        ( * ) :failerr "${1@Q}?"
      esac
    ;;
esac
# Id: run-us-gh                                  vim:set ft=bash sw=2 sts=2 et:
