#!/bin/bash

# remove / in archs
get_short_arch() {
  arch="$1"
  echo "$arch" | sed 's#/##'
}

# convert docker architecture to qemu architecture
get_arch2arch() {
  arch="$1"

  case "$arch" in
    amd64) echo amd64 ;;
    arm64/v8) echo aarch64 ;;
    arm/v7) echo arm ;;
    arm/v6) echo arm ;;
    *) exit 1;;
  esac
}

# get qemu container for architecture
get_multiarch_qemu_container() {
  arch="$(get_arch2arch "$1")"

  [ "$arch" != "amd64" ] &&
    echo "FROM docker.io/multiarch/qemu-user-static:x86_64-$arch as qemu"
}

# get the content of the dockerfile
get_dockerfile() {
  arch="$1"; shift
  dockerfile="$1"

  dockerfile_content="$(sed -E "s#^(FROM) (.*)#\1 --platform=linux/$arch docker.io/\2#g" "$dockerfile")"

  if [ "$arch" != "amd64" ]
  then
    echo "$dockerfile_content" |
      sed "/^FROM /a COPY --from=qemu /usr/bin/qemu-$(get_arch2arch "$arch")-static /usr/bin" |
      sed "0,/FROM /!b;//i $(get_multiarch_qemu_container "$arch")\n"
  else
    echo "$dockerfile_content"
  fi
}

### main

BASEDIR="$(dirname "$0")"
ARCHITECTURES="$(cat "$BASEDIR"/build.arch)"
DOCKERFILE_PATH="$1"
IMAGE_NAME="$2"

# print help
if [ -z "$DOCKERFILE_PATH" ] || [ -z "$IMAGE_NAME" ]
then
  echo "$(basename "$0")" DOCKERFILE_PATH IMAGE_NAME
  exit 1
fi

if which podman > /dev/null 2>&1
then
  DOCKER_CMD=podman
else
  DOCKER_CMD=docker
fi

# turn on multiarch for local build
if [ "$DOCKER_CMD" = "podman" ]
then
  sudo $DOCKER_CMD run --rm --privileged docker.io/multiarch/qemu-user-static --reset
else
  $DOCKER_CMD run --rm --privileged docker.io/multiarch/qemu-user-static --reset
fi

# build for all architectures
for arch in $ARCHITECTURES
do
  echo
  echo %%
  echo %% BUILDING FOR ARCHITECTURE = "$arch" =
  echo %%
  echo

  dockerfile=$(get_dockerfile "$arch" "$DOCKERFILE_PATH")

  if [ "$DOCKER_CMD" = "podman" ]
  then
    echo "$dockerfile" |
      buildah bud --pull --tag "$IMAGE_NAME-$(get_short_arch "$arch")" --platform="linux/$arch" --file - .
  else
    echo "$dockerfile" |
      $DOCKER_CMD build --pull --tag "$IMAGE_NAME-$(get_short_arch "$arch")" --platform="linux/$arch" --file - .
  fi
done

