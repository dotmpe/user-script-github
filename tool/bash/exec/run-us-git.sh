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

# scm-parts config and entry-point

SCRIPTPATH+=:$PWD/tool/bash/part
usp scm-git

case "${0##*/}" in
  ( run-scm-git.* )
      case "${1:---tag}" in
        ( --ensure-dev )          ${us_git_pre:?}ensure-... "${@:2}"  ;;
        ( --ensure-worktree )     ${us_git_pre:?}ensure-worktree "${@:2}"  ;;
        ( --ensure-current)       ${us_git_pre:?}ensure-... "${@:2}"  ;;
        ( --status )              ${us_git_pre:?}workflow-status "${@:2}"  ;;
        ( * ) :failerr "${1@Q}?"
      esac
    ;;
esac
# Id: run-scm-git                                 vim:set ft=bash sw=2 sts=2 et:
