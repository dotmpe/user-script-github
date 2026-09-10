#!/usr/bin/env bash
#
# configure.sh - Configure worktree from template project
#
# Copyright (c) 2026 .mpe  <me@dotmpe.com>
#
# Distributed under terms of the MIT license.
#
set -eETuCo pipefail
shopt -s failglob
IFS=$' \t\n'

while [[ ${1:+set} && ${1} == *=* ]]; do
  declare "$1"
  shift
done

: "${US_LOCAL_SH:=./.env.sh}"
[[ ! -e $US_LOCAL_SH ]] || \builtin . "$US_LOCAL_SH"

: "${GIT_TEMPLATE_REPOSITORY:=dotmpe/user-script-template}"

: "${GIT_TEMPLATE_REPOSITORY#*/}"
: "${US_SKELETON_DIR:=/src/local/${_:?}+dev}"
if [[ ! -d $US_SKELETON_DIR ]]; then
  >&2 echo "No template project to copy from"
  exit 2
fi

if ! diff -bqr "$US_SKELETON_DIR/configure+skeleton.bash" "./configure.bash"; then
  # Update configure.sh from configure+skeleton.sh and respawn this script
  printf -v cmd 'cp "%s" "%s" && exec bash %s' \
    $US_SKELETON_DIR/configure+skeleton.bash ./configure.bash ./configure.bash
  exec bash -c "$cmd"
fi

: "${US_TEMPLATE_CONFIG:=.local/etc/user_script_template.bash}"
if [[ ! -e ${US_TEMPLATE_CONFIG:?} ]]; then
  US_TEMPLATE_CONFIG=$US_SKELETON_DIR/etc/user_script_template.bash
fi
\builtin . "$US_TEMPLATE_CONFIG"

#shellcheck disable=2154
for file in "${us_skeleton_copy[@]}"; do
  if [[ ! -s ${file} ]]; then
    >&2 mkdir -vp "${file%/*}" &&
    >&2 cp -v "$US_SKELETON_DIR/${file}" "./${file}"
  fi
done

#shellcheck disable=2154
for file in "${us_skeleton_symlink[@]}"; do
  if [[ ! -e ${file} ]]; then
    if [[ -h ${file} ]]; then rm "$file" || exit; fi
    >&2 mkdir -vp "${file%/*}" &&
    >&2 ln -s "$US_SKELETON_DIR/${file}" "$file"
  fi
done

# Configure project
: "${GIT_ORIGIN_URL:-$(git config --get remote.${GIT_REMOTE:-origin}.url)}"
: "${_#"${GIT_ORIGIN_NETPATH:-git@github.com:}"}"
GIT_PROJECT_REPOSITORY=${_%.git}

if [[ ${GIT_PROJECT_REPOSITORY} == "${GIT_TEMPLATE_REPOSITORY}" ]]; then
  >&2 echo "The template project does not need to be configured"
  exit 2
fi

local_env_vars=(
  GIT_TEMPLATE_REPOSITORY
  GIT_PROJECT_REPOSITORY
  US_SKELETON_DIR
  BUILD_SELECT_SH
)

# Configure Redo (project build targets)

if [[ ! -e ${XREDO_CONFIG:=.local/etc/redo_default.bash} ]]; then

  xredo_all_targets=( @config )
  xredo_build_targets=( )

  if [[ -d src/ ]] &&
    src=$(find src/ -maxdepth 2 -type f -print -quit) &&
    [[ ${src:+set} && -f "$src" ]]
  then
    xredo_all_targets+=( @build )

    if [[ -d var/schema/ ]] &&
      sch=$(find var/schema/ -maxdepth 1 -type f -print -quit) &&
      [[ ${sch:+set} && -f "$sch" ]]
    then
      xredo_build_targets+=( @build:schema )
    fi
    unset sch
  fi

  if [[ -d test/ ]] &&
    test=$(find test/ -maxdepth 1 -type f -print -quit) &&
    [[ ${test:+set} && -f "$test" ]]
  then
    xredo_all_targets+=( @test )
  fi
  xredo_all_targets+=( @check )
  unset src test

  seed=etc/redo_default+seed.bash
  [[ -s $seed ]] || seed=$US_SKELETON_DIR/$seed

  cp "$seed" "${XREDO_CONFIG:?}" &&
  repl_all="xredo_all_targets=( ${xredo_all_targets[*]} )" &&
  repl_build="xredo_build_targets=( ${xredo_build_targets[*]} )"  &&

  command ed - "${XREDO_CONFIG:?}" <<EOF
/^#xredo_all_targets=/c
$repl_all
.
/^#xredo_build_targets=/c
$repl_build
.
\$s/redo_default+seed\ /redo_default+local/
w
q
EOF

  unset seed repl_{all,build}
fi

# Configure Redo (script files)

if [[ ! -e ${XREDO_ENV:=.local/build/xredo_env.bash} ]]; then
  xredo_env_sources=(
    "env_common.bash"
    "dsl-common.bash"
  )
  xredo_scr_sources=(
    "build-select.bash"
    "build_common.bash"
    "build_schema.bash"
  )

  path=$PATH:tool/local:$US_SKELETON_DIR/tool/local

  declare -ga env_files
  for xredo_env_src in "${xredo_env_sources[@]}"; do
    env_files+=( "$(PATH=$path command -v "${xredo_env_src:?}")" )
  done

  declare -ga build_configs
  for xredo_scr in "${xredo_scr_sources[@]}"; do
    build_configs+=( "$(PATH=$path command -v "${xredo_scr:?}")" )
  done

  declare -gn \
    build_select='build_configs[0]' \
    build_common='build_configs[1]' \
    build_schema='build_configs[2]' \
    BUILD_SELECT_SH=build_select

  local_env_vars+=( env_files build_{configs,select,common,schema} )

  {
    declare -p "${local_env_vars[@]}" |
      command sed 's/^declare --*\([xn]*\)/declare -g\1/'
    echo "PATH+=:tool/local:$US_SKELETON_DIR/tool/local"
    echo export PATH
    echo
    echo . \"${XREDO_CONFIG:?}\"
    printf '. "%s"\n' "${env_files[@]}"
  } > "${XREDO_ENV:?}"

  unset path local_env_vars
fi

# TODO: init other resources: license, docs, alt. gitignore setups

# Id: configure+skeleton+us                      vim:set ft=bash sw=2 sts=2 et:
