#!/bin/bash

# This module should be pulled and run from an ITKModule root directory to generate the Linux python wheels of this module,
# it is used by the circle.yml file contained in ITKModuleTemplate: https://github.com/InsightSoftwareConsortium/ITKModuleTemplate

curl https://data.kitware.com/api/v1/file/592dd8068d777f16d01e1a92/download -o zstd-1.2.0-linux.tar.gz
gunzip -d zstd-1.2.0-linux.tar.gz
tar xf zstd-1.2.0-linux.tar

curl -L https://github.com/InsightSoftwareConsortium/ITKPythonBuilds/releases/download/${ITK_PACKAGE_VERSION:=v5.0.1}/ITKPythonBuilds-linux.tar.zst -O
./zstd-1.2.0-linux/bin/unzstd ITKPythonBuilds-linux.tar.zst -o ITKPythonBuilds-linux.tar
tar xf ITKPythonBuilds-linux.tar

rm ITKPythonBuilds-linux.tar

mkdir tools
curl https://data.kitware.com/api/v1/file/5c0aa4b18d777f2179dd0a71/download -o doxygen-1.8.11.linux.bin.tar.gz
tar -xvzf doxygen-1.8.11.linux.bin.tar.gz -C tools

#### scripts/dockcross-manylinux-build-module-wheels.sh cp35

# Pull dockcross manylinux images
docker pull dockcross/manylinux-x64
#docker pull dockcross/manylinux-x86

# Generate dockcross scripts
docker run dockcross/manylinux-x64 > /tmp/dockcross-manylinux-x64
chmod u+x /tmp/dockcross-manylinux-x64
#docker run dockcross/manylinux-x86 > /tmp/dockcross-manylinux-x86
#chmod u+x /tmp/dockcross-manylinux-x86

script_dir=$(cd $(dirname $0) || exit 1; pwd)
chmod u+x manylinux-build-module-wheels.sh

# Build wheels
mkdir -p dist
DOCKER_ARGS="-v $(pwd)/dist:/work/dist/ -v $script_dir:/work -v $script_dir/ITKPythonPackage:/ITKPythonPackage -v $(pwd)/tools:/tools"
/tmp/dockcross-manylinux-x64 \
  -a "$DOCKER_ARGS" \
  "/work/manylinux-build-module-wheels.sh" "$@"
