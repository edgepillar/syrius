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
# 590f43c is the commit the lab was first proven on (2026-10-11).
go_zenon_url="${GO_ZENON_URL:-https://github.com/zenon-network/go-zenon.git}"
go_zenon_rev="${GO_ZENON_REV:-590f43ca7a24dccd8e883bc8903a0cb02e54528a}"
go_zenon="$build/go-zenon"

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
  if [ ! -f "$build/revision" ]; then
    echo "No image yet: run 'lab.sh build'." >&2
    exit 1
  fi
  cat "$build/revision"
}

compose() {
  LAB_ZNND_TAG="$(tag)" docker compose -f "$here/docker-compose.yml" "$@"
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
  docker build -t "syrius-lab-znnd:$revision" "$build/src"
  echo "$revision" > "$build/revision"
  echo "built syrius-lab-znnd:$revision"
}

do_assets() {
  [ -f "$assets/genesis.json" ] && return 0
  node "$here/make-assets.js" "$build/src/docker/devnet" "$assets"
}

case "${1:-}" in
  build)
    do_build
    ;;
  up)
    [ -f "$build/revision" ] || do_build
    docker image inspect "syrius-lab-znnd:$(tag)" > /dev/null
    do_assets
    compose up -d
    node "$here/frontier.js" 180 --wait 90
    ;;
  status)
    compose ps -a
    node "$here/frontier.js" 30
    ;;
  down)
    compose down
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
