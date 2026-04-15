#!/usr/bin/env bash
#  SPDX-FileCopyrightText: Copyright (c) CloudZero, Inc. or its affiliates. All Rights Reserved.
#  SPDX-License-Identifier: Apache-2.0
#
# semver.sh — Fetch tags/releases, resolve current semver, bump to next version.
# Called by the composite action; expects env vars set by action.yml.

# ---------------------------------------------------------------------------
# fetch_versions — paginate the GitHub API and emit one raw name per line
# ---------------------------------------------------------------------------
fetch_versions() {
  local source="${INPUT_SOURCE}"
  local page=1
  local per_page=100

  if [[ "${source}" != "tags" && "${source}" != "releases" ]]; then
    echo "::error::Invalid source '${source}'. Must be 'tags' or 'releases'."
    exit 1
  fi

  local field="name"
  local path="tags"
  if [[ "${source}" == "releases" ]]; then
    field="tag_name"
    path="releases"
  fi

  local max_pages=50

  while true; do
    if [[ "${page}" -gt "${max_pages}" ]]; then
      echo "::warning::Reached pagination limit (${max_pages} pages). Some ${path} may be excluded."
      break
    fi

    local endpoint="${GH_API_URL}/repos/${GH_REPOSITORY}/${path}?per_page=${per_page}&page=${page}"

    local response
    response=$(curl -sf \
      --connect-timeout 10 \
      --max-time 30 \
      -H "Authorization: Bearer ${INPUT_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "${endpoint}") || {
        echo "::error::Failed to fetch ${path} from GitHub API (page ${page}). Check token permissions and network connectivity."
        exit 1
      }

    local count
    count=$(echo "${response}" | jq 'length')

    if [[ "${count}" -eq 0 ]]; then
      break
    fi

    echo "${response}" | jq -r ".[].${field}"

    if [[ "${count}" -lt "${per_page}" ]]; then
      break
    fi

    page=$((page + 1))
  done
}

# ---------------------------------------------------------------------------
# coerce_semver — extract first MAJOR.MINOR.PATCH from a string
# ---------------------------------------------------------------------------
coerce_semver() {
  local raw="$1"
  if [[ "${raw}" =~ ([0-9]+\.[0-9]+\.[0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  fi
}

# ---------------------------------------------------------------------------
# filter_and_coerce — apply prefix filter and coerce each raw name
# ---------------------------------------------------------------------------
filter_and_coerce() {
  local raw_names="$1"
  local prefix="${INPUT_PREFIX}"

  while IFS= read -r name; do
    [[ -z "${name}" ]] && continue

    if [[ -n "${prefix}" && "${name}" != "${prefix}"* ]]; then
      continue
    fi

    local coerced
    coerced=$(coerce_semver "${name}")
    if [[ -n "${coerced}" ]]; then
      echo "${coerced}"
    fi
  done <<< "${raw_names}"
}

# ---------------------------------------------------------------------------
# find_current_version — sort descending, return highest (or 0.0.0)
# ---------------------------------------------------------------------------
find_current_version() {
  local versions="$1"

  if [[ -z "$(echo "${versions}" | tr -d '[:space:]')" ]]; then
    echo "0.0.0"
    return
  fi

  local highest
  highest=$(echo "${versions}" | grep -v '^$' | sort -u -t. -k1,1nr -k2,2nr -k3,3nr | head -n1)

  if [[ -z "${highest}" ]]; then
    echo "0.0.0"
  else
    echo "${highest}"
  fi
}

# ---------------------------------------------------------------------------
# detect_increment_level — scan text for [major], [minor], etc. bracket tags
# ---------------------------------------------------------------------------
detect_increment_level() {
  local text="$1"
  local lower
  lower=$(echo "${text}" | tr '[:upper:]' '[:lower:]')

  for level in major minor patch premajor preminor prepatch prerelease; do
    if [[ "${lower}" == *"[${level}]"* ]]; then
      echo "${level}"
      return
    fi
  done
}

# ---------------------------------------------------------------------------
# resolve_increment_level — auto-detect or pass through explicit level
# ---------------------------------------------------------------------------
resolve_increment_level() {
  local level="${INPUT_INCREMENT_LEVEL}"

  if [[ "${level}" != "auto" ]]; then
    case "${level}" in
      major|minor|patch|premajor|preminor|prepatch|prerelease) ;;
      *)
        echo "::error::Invalid incrementLevel '${level}'. Must be one of: major, minor, patch, premajor, preminor, prepatch, prerelease, auto."
        exit 1
        ;;
    esac
    echo "${level}"
    return
  fi

  local detected

  detected=$(detect_increment_level "${PR_TITLE}")
  if [[ -n "${detected}" ]]; then
    echo "${detected}"
    return
  fi

  detected=$(detect_increment_level "${HEAD_COMMIT_MSG}")
  if [[ -n "${detected}" ]]; then
    echo "${detected}"
    return
  fi

  echo "patch"
}

# ---------------------------------------------------------------------------
# bump_version — increment MAJOR.MINOR.PATCH by the given level
# ---------------------------------------------------------------------------
bump_version() {
  local current="$1"
  local level="$2"

  local major minor patch
  IFS='.' read -r major minor patch <<< "${current}"

  # Strip any prerelease suffix that survived (defensive)
  local pre=""
  if [[ "${patch}" == *-* ]]; then
    pre="${patch#*-}"
    patch="${patch%%-*}"
  fi

  case "${level}" in
    major)
      echo "$((major + 1)).0.0"
      ;;
    minor)
      echo "${major}.$((minor + 1)).0"
      ;;
    patch)
      echo "${major}.${minor}.$((patch + 1))"
      ;;
    premajor)
      echo "$((major + 1)).0.0-0"
      ;;
    preminor)
      echo "${major}.$((minor + 1)).0-0"
      ;;
    prepatch)
      echo "${major}.${minor}.$((patch + 1))-0"
      ;;
    prerelease)
      if [[ -n "${pre}" ]]; then
        echo "${major}.${minor}.${patch}-$((pre + 1))"
      else
        echo "${major}.${minor}.$((patch + 1))-0"
      fi
      ;;
    *)
      echo "::error::Unknown increment level: ${level}"
      exit 1
      ;;
  esac
}

# ===========================================================================
# Main — only runs when executed directly, not when sourced
# ===========================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail

  echo "::group::Fetching versions from ${INPUT_SOURCE}"
  RAW_NAMES=$(fetch_versions)
  RAW_COUNT=$(echo "${RAW_NAMES}" | grep -c '[^[:space:]]' || true)
  echo "Fetched ${RAW_COUNT} raw names"
  echo "::endgroup::"

  echo "::group::Filtering and coercing versions"
  VERSIONS=$(filter_and_coerce "${RAW_NAMES}")
  VERSION_COUNT=$(echo "${VERSIONS}" | grep -c '[^[:space:]]' || true)
  echo "Found ${VERSION_COUNT} valid versions after filtering"
  echo "::endgroup::"

  CURRENT_VERSION=$(find_current_version "${VERSIONS}")
  echo "Current version: ${CURRENT_VERSION}"

  INCREMENT_LEVEL=$(resolve_increment_level)
  echo "Increment level: ${INCREMENT_LEVEL}"

  NEXT_VERSION=$(bump_version "${CURRENT_VERSION}" "${INCREMENT_LEVEL}")
  echo "Next version: ${NEXT_VERSION}"

  echo "currentVersion=${CURRENT_VERSION}" >> "${GITHUB_OUTPUT}"
  echo "nextVersion=${NEXT_VERSION}" >> "${GITHUB_OUTPUT}"
fi
