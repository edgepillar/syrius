#!/usr/bin/env bash
# The Syrius lab: a go-zenon devnet for this repo's harnessed test runs.
#
#   tools/devnet/lab/lab.sh build    znnd image from go-zenon at the pinned commit
#   tools/devnet/lab/lab.sh up       start it (builds and makes assets if needed)
#   tools/devnet/lab/lab.sh status   containers, and whether it is producing
#   tools/devnet/lab/lab.sh down     stop it, chain kept
#   tools/devnet/lab/lab.sh wipe     stop it and delete the chain and assets
#
# Needs bash, git, Docker and Node. See README.md.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
build="$here/.build"
assets="$here/assets"

# go-zenon is fetched from GitHub at one commit into .build/, so the lab needs
# no checkout beside this repository and every machine builds the same node.
# The reference recipe and this fixed source pass the isolated lab command gate.
go_zenon_url="${GO_ZENON_URL:-https://github.com/zenon-network/go-zenon.git}"
go_zenon_rev="${GO_ZENON_REV:-0e80915fb9569f2fc3f6bd90c2a54e4c10d7bc1b}"
go_zenon="$build/go-zenon"
build_recipe="${LAB_BUILD_RECIPE:-reference}"
case "$build_recipe" in
  upstream) stop_timeout=10 ;;
  reference) stop_timeout=20 ;;
  *) echo "Unknown lab build recipe." >&2; exit 2 ;;
esac

fetch_go_zenon() {
  if ! git -C "$go_zenon" cat-file -e "$go_zenon_rev^{commit}" 2> /dev/null; then
    rm -rf "$go_zenon"
    git init -q "$go_zenon"
    git -C "$go_zenon" fetch -q --depth 1 "$go_zenon_url" "$go_zenon_rev"
  fi
}

# The image is tagged with the go-zenon commit it was built from, and that is
# remembered, so a later `up` runs what was built even if go-zenon has moved.
tag() {
  local revision
  if [ ! -f "$build/revision" ]; then
    echo "No image yet: run 'lab.sh build'." >&2
    exit 1
  fi
  revision="$(cat "$build/revision")"
  if { [ "$build_recipe" = upstream ] && [[ "$revision" =~ ^[a-f0-9]{7,40}$ ]]; } ||
     { [ "$build_recipe" = reference ] && [[ "$revision" =~ ^[a-f0-9]{7,40}-reference$ ]]; }; then
    echo "$revision"
  else
    echo "Lab image recipe differs: select the recipe used to build it." >&2
    return 1
  fi
}

compose() {
  local revision
  revision="$(tag)" || return
  LAB_ZNND_TAG="$revision" docker compose -f "$here/docker-compose.yml" "$@"
}

do_build() {
  local revision
  fetch_go_zenon
  revision="$(git -C "$go_zenon" rev-parse --short "$go_zenon_rev")"
  # An export of the commit, not a checkout: git on Windows may check files
  # out with CRLF, and an entrypoint with CRLF does not run in the image.
  rm -rf "$build/src"
  mkdir -p "$build/src"
  git -C "$go_zenon" archive "$go_zenon_rev" | tar -x -C "$build/src"
  if [ "$build_recipe" = reference ]; then
    revision="$revision-reference"
    docker build -f "$here/Dockerfile.reference" -t "syrius-lab-znnd:$revision" "$build/src"
  else
    docker build -t "syrius-lab-znnd:$revision" "$build/src"
  fi
  echo "$revision" > "$build/revision"
  echo "built syrius-lab-znnd:$revision"
}

do_assets() {
  [ -f "$assets/genesis.json" ] && return 0
  node "$here/make-assets.js" "$build/src/docker/devnet" "$assets"
}

do_down() {
  local offered id prior count=0
  local ids=()
  offered="$(compose ps -a -q)" || return
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    if [[ ! "$id" =~ ^[a-f0-9]{64}$ ]]; then
      echo "Lab container identity refused." >&2
      return 1
    fi
    if [ "$count" -gt 0 ]; then
      for prior in "${ids[@]}"; do
        if [ "$prior" = "$id" ]; then
          echo "Lab container identity refused." >&2
          return 1
        fi
      done
    fi
    if [ "$count" -ge 5 ]; then
      echo "Lab container identity refused." >&2
      return 1
    fi
    ids[$count]="$id"
    count=$((count + 1))
  done <<< "$offered"
  if [ "$count" -gt 0 ]; then
    # Compose retires dependants before their live peers. Submit the complete
    # set together. The reference recipe uses the existing hosted backend's
    # twenty-second grace; upstream keeps ten. Retain any stop error.
    docker stop --timeout "$stop_timeout" "${ids[@]}"
  fi
  compose down
}

case "${1:-}" in
  build)
    do_build
    ;;
  up)
    [ -f "$build/revision" ] || do_build
    image_tag="$(tag)"
    docker image inspect "syrius-lab-znnd:$image_tag" > /dev/null
    do_assets
    compose up -d
    node "$here/frontier.js" 180 --wait 90 --advances 2
    ;;
  status)
    compose ps -a
    node "$here/frontier.js" 30
    ;;
  down)
    do_down
    ;;
  wipe)
    compose down -v
    rm -rf "$assets"
    ;;
  *)
    sed -n '2,10p' "$0"
    exit 2
    ;;
esac
