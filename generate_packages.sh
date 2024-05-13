#!/bin/bash

set -e

package_beat() {
  BEAT=$1
  VERSION=$2

  ARMHF_NAME="${BEAT}-${VERSION}-linux-armv7l"
  BIN_DIR="${INSTALL_DIR}/bin"
  BIN_PATH="${BIN_DIR}/${ARMHF_NAME}"
  BUILD_DIR="${INSTALL_DIR}/build"
  DEBIAN_DIR="${BUILD_DIR}/${ARMHF_NAME}"
  DIST_DIR="${INSTALL_DIR}/dist"

  # Get the beat binary for armhf (compatible with armv6l/armv7l)
  if [ ! -f "${BIN_PATH}.tar.gz" ]; then
    wget "https://github.com/vrince/arm-beats/releases/download/v${VERSION}/${ARMHF_NAME}.tar.gz" -P "${BIN_DIR}"
  fi

  # Extract the beat armhf binary
  rm -rf "${BIN_PATH}"
  tar -xf "${BIN_PATH}.tar.gz" -C "${BIN_DIR}"

  mkdir -p "${DIST_DIR}"

  # Get the official beat arm64 deb package
  if [ ! -f "${DIST_DIR}/${BEAT}-${VERSION}-arm64.deb" ]; then
    wget --no-clobber --continue "https://artifacts.elastic.co/downloads/beats/${BEAT}/${BEAT}-${VERSION}-arm64.deb" -P "${DIST_DIR}"
  fi
  ARM64_DEB="$(find "${DIST_DIR}" -name "${BEAT}-${VERSION}-arm64.deb" -type f -printf "%f\n" | awk 'FNR <= 1')"

  # Extract the official beat arm64 deb package
  mkdir -p "${DEBIAN_DIR}"
  dpkg-deb -x "${DIST_DIR}/${ARM64_DEB}" "${DEBIAN_DIR}/"
  dpkg-deb -e "${DIST_DIR}/${ARM64_DEB}" "${DEBIAN_DIR}/DEBIAN"

  # Replace the arm64 beat binary with the armhf beat binary
  rm "${DEBIAN_DIR}/usr/share/${BEAT}/bin/${BEAT}"
  cp "${BIN_PATH}/${BEAT}" "${BUILD_DIR}/${ARMHF_NAME}/usr/share/${BEAT}/bin/"

  # Update the control file and md5sums
  BEAT_MD5="$(md5sum "${DEBIAN_DIR}/usr/share/${BEAT}/bin/${BEAT}" | awk '{print $1}')"
  sed -i 's/arm64/armhf/g' "${DEBIAN_DIR}/DEBIAN/control"
  sed -i "s/.*usr\/share\/${BEAT}\/bin\/${BEAT}.*/${BEAT_MD5}  usr\/share\/${BEAT}\/bin\/${BEAT}/g" "${DEBIAN_DIR}/DEBIAN/md5sums"

  # Build the armhf beat deb package
  cd "${BUILD_DIR}" ; dpkg-deb --root-owner-group --build "${ARMHF_NAME}" ../dist/"${BEAT}-${VERSION}-armv7l.deb"
}

# Get the version from command line argument or use the latest release version
if [ -z "$1" ]; then
  VERSION=$(curl --silent -qI https://github.com/vrince/arm-beats/releases/latest \
  | awk -F '/' '/^location/ {print  substr($NF, 1, length($NF)-1)}') VERSION="${VERSION#v}"
else
  VERSION=$1
  # Check if the specified version is available
  HTTP_STATUS=$(curl --write-out "%{http_code}" --silent --output /dev/null "https://github.com/vrince/arm-beats/releases/tag/v${VERSION}")
  if [ "$HTTP_STATUS" != "200" ]; then
    echo "Error: Version ${VERSION} is not available at https://github.com/vrince/arm-beats/releases/"
    exit 1
  fi
fi

export VERSION=$VERSION

INSTALL_DIR=$(pwd)

# Package each beat
for BEAT in filebeat metricbeat heartbeat; do
  package_beat $BEAT $VERSION
done
