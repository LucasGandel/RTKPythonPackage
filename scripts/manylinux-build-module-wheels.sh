#!/usr/bin/env bash

# -----------------------------------------------------------------------
# These variables are set in common script:
#
ARCH=""
PYBINARIES=""
PYTHON_LIBRARY=""

# script_dir=$(cd $(dirname $0) || exit 1; pwd)
# source "${script_dir}/manylinux-build-common.sh"

# Content common to manylinux-build-wheels.sh and
# manylinux-build-module-wheels.sh

set -e -x

# Versions can be restricted by passing them in as arguments to the script
# For example,
# manylinux-build-wheels.sh cp35
if [[ $# -eq 0 ]]; then
  PYBIN=(/opt/python/*/bin)
  PYBINARIES=()
  for version in "${PYBIN[@]}"; do
    if [[ ${version} == *"cp35"* || ${version} == *"cp36"* || ${version} == *"cp37"* ]]; then
      PYBINARIES+=(${version})
    fi
  done
else
  PYBINARIES=()
  for version in "$@"; do
    PYBINARIES+=(/opt/python/*${version}*/bin)
  done
fi

# i686 or x86_64 ?
case $(uname -p) in
    i686)
        ARCH=x86
        ;;
    x86_64)
        ARCH=x64
        ;;
    *)
        die "Unknown architecture $(uname -p)"
        ;;
esac

echo "Building wheels for $ARCH"

# Since the python interpreter exports its symbol (see [1]), python
# modules should not link against any python libraries.
# To ensure it is not the case, we configure the project using an empty
# file as python library.
#
# [1] "Note that libpythonX.Y.so.1 is not on the list of libraries that
# a manylinux1 extension is allowed to link to. Explicitly linking to
# libpythonX.Y.so.1 is unnecessary in almost all cases: the way ELF linking
# works, extension modules that are loaded into the interpreter automatically
# get access to all of the interpreter's symbols, regardless of whether or
# not the extension itself is explicitly linked against libpython. [...]"
#
# Source: https://www.python.org/dev/peps/pep-0513/#libpythonx-y-so-1
PYTHON_LIBRARY=$(cd $(dirname $0); pwd)/libpython-not-needed-symbols-exported-by-interpreter
touch ${PYTHON_LIBRARY}
# -----------------------------------------------------------------------

# Compile wheels re-using standalone project and archive cache
for PYBIN in "${PYBINARIES[@]}"; do
    PYTHON_EXECUTABLE=${PYBIN}/python
    PYTHON_INCLUDE_DIR=$( find -L ${PYBIN}/../include/ -name Python.h -exec dirname {} \; )

    echo ""
    echo "PYTHON_EXECUTABLE:${PYTHON_EXECUTABLE}"
    echo "PYTHON_INCLUDE_DIR:${PYTHON_INCLUDE_DIR}"
    echo "PYTHON_LIBRARY:${PYTHON_LIBRARY}"

    if [[ -e /work/requirements-dev.txt ]]; then
      ${PYBIN}/pip install --upgrade -r /work/requirements-dev.txt
    fi
    itk_build_dir=/work/ITK-$(basename $(dirname ${PYBIN}))-manylinux1_${ARCH}
    ln -fs /ITKPythonPackage/ITK-$(basename $(dirname ${PYBIN}))-manylinux1_${ARCH} $itk_build_dir
    if [[ ! -d ${itk_build_dir} ]]; then
      echo 'ITK build tree not available!' 1>&2
      exit 1
    fi
    itk_source_dir=/work/standalone-${ARCH}-build/ITKs
    ln -fs /ITKPythonPackage/standalone-${ARCH}-build/ /work/standalone-${ARCH}-build
    if [[ ! -d ${itk_source_dir} ]]; then
      echo 'ITK source tree not available!' 1>&2
      exit 1
    fi
    ${PYBIN}/python setup.py bdist_wheel --build-type MinSizeRel -G Ninja -- \
      -DITK_DIR:PATH=${itk_build_dir} \
      -DITK_USE_SYSTEM_SWIG:BOOL=ON \
      -DWRAP_ITK_INSTALL_COMPONENT_IDENTIFIER:STRING=PythonWheel \
      -DSWIG_EXECUTABLE:FILEPATH=${itk_build_dir}/Wrapping/Generators/SwigInterface/swig/bin/swig \
      -DCMAKE_CXX_COMPILER_TARGET:STRING=$(uname -p)-linux-gnu \
      -DBUILD_TESTING:BOOL=OFF \
      -DRTK_BUILD_APPLICATIONS:BOOL=OFF \
      -DRTK_USE_CUDA:BOOL=ON \
      -DPYTHON_EXECUTABLE:FILEPATH=${PYTHON_EXECUTABLE} \
      -DPYTHON_INCLUDE_DIR:PATH=${PYTHON_INCLUDE_DIR} \
      -DPYTHON_LIBRARY:FILEPATH=${PYTHON_LIBRARY} \
    || exit 1
    ${PYBIN}/python setup.py clean
done

# Since there are no external shared libraries to bundle into the wheels
# this step will fixup the wheel switching from 'linux' to 'manylinux1' tag
for whl in dist/*linux_$(uname -p).whl; do
    auditwheel repair ${whl} -w /work/dist/
    rm ${whl}
done