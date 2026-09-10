#!/bin/bash
#
# Copyright (c) 2026 .mpe  <me@dotmpe.com>
#
# Distributed under terms of the MIT license.
us_gh_pre=User-Script.GitHub.CLI
us_gh_man='Building some TSV

NB: field values must not be empty: Bash read collapses empty columns'
us_gh_var=(
  US_GH_DOMAIN
)
us_gh_fun=(
  .fetch-repolist-details.tsv
  .fetch-repolist.tsv
  .list-repos
  .list-repos.tsv
  .tag-repolist

  # TODO:
  .tag-repo
  #.merge-repotags
  #.archive-repos
  .workflow-status
)
declare -gA \
us_gh_hooks=(
  [declare]='
  : env "${US_GH_OWNERS:=${SCM_DOMAIN:-${DOMAIN:?}}}"
  : env "${US_GH_STATE_DIRTY:=.local/cache/gh-repos-state-dirty.bash}"
  : env "${US_GH_REPOS_OWNER_TSV:=${HOME:?}/.local/var/gh-repos-owner.tab}"
  : env "${US_GH_REPOS_OWNER_DETAILS_TSV:=${HOME:?}/.local/var/gh-repos-owner-details.tab}"
'

  [init]='
  declare -gA us_gh_dirty
  us_gh_repos_ownertab=(
    owner name tags defbr plang stars forks isfrk isarch istpl ispriv
  )
  us_gh_repos_ownerattr=(
    nameWithOwner defaultBranchRef
    stargazerCount forkCount
    primaryLanguage
    is{Fork,Archived,Template,Private}
  )

  us_gh_repos_ownerdetailtab=(
    owner name description diskuse created updated pushed
  )
  us_gh_repos_ownerdetailattr=(
    nameWithOwner
    description
    createdAt updatedAt pushedAt
    diskUsage
  )
')

User-Script.GitHub.CLI.fetch-repolist-details.tsv() {
  ! (($#)) || return ${_E_GAE:?}
: input "${US_GH_REPOS_OWNER_DETAILS_TSV:?}"
  local repotab=$_

  [[ -s "${repotab:?}" ]] &&
    :to-v wc ${repotab:?} && return

  ${us_gh_pre:?}list-repos.tsv "${repotab:?}" \
    "$(IFS=,; echo "${us_gh_repos_ownerdetailattr[*]:?}")" '[
        (.nameWithOwner | split("/")[0]),
        (.nameWithOwner | split("/")[1]),
        .description,
        .diskUsage,
        .createdAt, .updatedAt, .pushedAt
    ]' &&
  :to-v wc ${repotab:?}
}

User-Script.GitHub.CLI.fetch-repolist.tsv() {
: about 'Make repos table for tagging'
: param '~ ...'
  ! (($#)) || return ${_E_GAE:?}
: input "${US_GH_REPOS_OWNER_TSV:?}"
  local repotab=$_

  [[ -s "${repotab:?}" ]] &&
    :to-v wc ${repotab:?} && return

  ${us_gh_pre:?}list-repos.tsv "${repotab:?}" \
    "$(IFS=,; echo "${us_gh_repos_ownerattr[*]:?}")" '[
             (.nameWithOwner | split("/")[0]),
             (.nameWithOwner | split("/")[1]),
             " ",
             if (.defaultBranchRef.name? // "") == "" then "-" else
               .defaultBranchRef.name end,
             .stargazerCount, .forkCount,
             .isFork, .isArchived, .isTemplate, .isPrivate,
             .primaryLanguage.name? // "-" ]' &&
  :to-v wc ${repotab:?}
}

User-Script.GitHub.CLI.list-repos() {
: about 'Fetch new list with attributes'
: param '~ <Attribute-selection> [<Owners>] [<Limit-rows-override>] ...'
: input "${1?$(:argv-err 1 'JSON fields selector')}"
  local attrsel=${1} owners limit
  owners=${2:-${US_GH_OWNERS:?}}
  limit=${3:-${US_GH_REPO_LIMIT:-100}}

  # NOTE: without owner, empty repos (and others perhaps) would not be listed
  for owner in ${owners:?}; do
    gh repo list "${owner:?}" --json "$attrsel" --limit "$limit" || return
  done
}

User-Script.GitHub.CLI.list-repos.tsv() {
: about 'Fetch new list with attributes, and process to table'
: param '~ <Output-file> <Attribute-selection> <Jq-transform> ...'
: input "${1?$(:argv-err 1 'Output file')}"
: input "${2?$(:argv-err 1 'JSON fields selector')}"
: input "${3?$(:argv-err 1 'Jq transform')}"

  ${us_gh_pre:?}list-repos "${2}" | jq -r '.[] | '"${3}"' | @tsv' >"${1}"
}

User-Script.GitHub.CLI.tag-repolist() {
: about 'Edit tags for repositories'
  ! (($#)) || return ${_E_GAE:?}
  . <(:funbody ${FUNCNAME}._local)

  exec {tsv_fd}< "$repotab" &&
  while IFS=$'\t\n' read -u ${tsv_fd} -ra values; do
    ((row+=1))
    printf '%i. ' $row
    IFS=$'\t'; echo "${values[*]}"; IFS=$' \t\n'
    #if [[ ${tags:- } == ' ' ]]; then
    [[ ${isfrk-} != true ]] || :word-append @forks tags_upd
    [[ ${ispriv-} != true ]] || :word-append @private tags_upd
    [[ ${isarch-} != true ]] || :word-append @archived tags_upd
    [[ ${istpl-} != true ]] || :word-append @templates tags_upd
    #echo "tags_upd: $tags_upd" >&2
    #fi
    :read-tty "  Tags: " "${tags_upd:-$tags}" tags_upd || { stat=$?
      (( stat != 130 )) || stat=
      break
    }
    [[ "${tags_upd:- }" = "${tags}" ]] || dirty=1
  done < "${repotab:?}" && IFS=$' \t\n' && exec {tsv_fd}<&- ||
    :restore-ifs :failerr 'Error reading repolist' || return

  if ((dirty)); then
    say.v "Writing state to disk for ${#us_gh_dirty[*]} entries..."
    # XXX: format this on lines for readabilty may be, but key are not long and
    # values (tags) are fairly diverse and not too repetitive atm.
    declare -p us_gh_dirty >"${US_GH_STATE_DIRTY:?}"
  fi

  return ${stat-}
}

User-Script.GitHub.CLI.tag-repolist._local() {
: input "${US_GH_REPOS_OWNER_TSV:?}"
  local repotab=$_
  local -n _fields=us_gh_repos_ownertab
  local values "${_fields[@]}"  tsv_fd  stat dirty=0 row=0
  local -n owner='values[0]' name='values[1]' tags='values[2]' \
    defbr='values[3]' \
    \
    isfrk='values[6]' \
    isarch='values[7]' \
    istpl='values[8]' \
    ispriv='values[9]' \
    tags_upd='us_gh_dirty["$owner.$name.tags"]'

  ! test -s "${US_GH_STATE_DIRTY:?}" || \builtin . "$_" || return
}

User-Script.GitHub.CLI.tag-repolist.sync() {
  ! (($#)) || return ${_E_GAE:?}
  . <(:funbody ${FUNCNAME%.sync}._local)
: input "${us_gh_dirty[*]:?}" # Do not run with empty input

  exec {tsv_fd}< "$repotab" &&
  while IFS=$'\t\n' read -u ${tsv_fd} -ra values; do
    if [[ "${tags_upd:- }" != "${tags:- }" ]]; then
      tags=${tags_upd:?}
    else
      tags=${tags:- }
    fi
    IFS=$'\t'; echo "${values[*]}"; IFS=$' \t\n'
  done <"${repotab:?}" >"${repotab}.new" && IFS=$' \t\n' && exec {tsv_fd}<&- ||
    :restore-ifs :failerr 'Error reading repolist' || return

  cp "${repotab}"{,.bup} &&
  mv "${repotab}"{.new,}
}

User-Script.GitHub.CLI.tag-repo() {
: param '~ owner/name +tag1 -tag2 +tag3'

  :to-do
}

User-Script.GitHub.CLI.workflow-status() {
: param '~ [tag1,tag2,...] [branch]'
: input "${US_GH_REPOS_OWNER_TSV:?}"
  local repotab=$_

  grep " $1 " "$repotab" |
  while read -r repo defbr _; do
    gh run list --repo "$repo" --branch "${branch:-.}" --limit 1
  done
}

# Id: gh,us         vim:set ft=bash sw=2 sts=2 et:
