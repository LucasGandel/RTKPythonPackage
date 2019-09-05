#!/usr/bin/env bash

# Run this script to build the Python wheel packages for macOS for an ITK
# external module.
#
# Versions can be restricted by passing them in as arguments to the script
# For example,
#
#   scripts/macpython-build-module-wheels.sh 2.7 3.5

# -----------------------------------------------------------------------
# These variables are set in common script:
#
MACPYTHON_PY_PREFIX=""
# PYBINARIES="" # unused
PYTHON_LIBRARY=""
SCRIPT_DIR=""
VENVS=()

# script_dir=$(cd $(dirname $0) || exit 1; pwd)
# source "${script_dir}/macpython-build-common.sh"

# Content common to macpython-build-wheels.sh and
# macpython-build-module-wheels.sh

set -e -x

SCRIPT_DIR=/Users/Kitware/Dashboards/ITK/ITKPythonPackage/scripts/

MACPYTHON_PY_PREFIX=/Library/Frameworks/Python.framework/Versions

# Versions can be restricted by passing them in as arguments to the script
# For example,
# macpython-build-wheels.sh 2.7 3.5
if [[ $# -eq 0 ]]; then
  PYBINARIES=(${MACPYTHON_PY_PREFIX}/*)
else
  PYBINARIES=()
  for version in "$@"; do
    PYBINARIES+=(${MACPYTHON_PY_PREFIX}/*${version}*)
  done
fi

VENVS=()
mkdir -p ${SCRIPT_DIR}/../venvs
for PYBIN in "${PYBINARIES[@]}"; do
    if [[ $(basename $PYBIN) = "Current" ]]; then
      continue
    fi
    py_mm=$(basename ${PYBIN})
    VENV=${SCRIPT_DIR}/../venvs/${py_mm}
    VENVS+=(${VENV})
done

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
PYTHON_LIBRARY=${SCRIPT_DIR}/internal/libpython-not-needed-symbols-exported-by-interpreter
touch ${PYTHON_LIBRARY}

# -----------------------------------------------------------------------

VENV="${VENVS[0]}"
PYTHON_EXECUTABLE=${VENV}/bin/python
${PYTHON_EXECUTABLE} -m pip install --no-cache cmake
# CMAKE_EXECUTABLE=${VENV}/bin/cmake
${PYTHON_EXECUTABLE} -m pip install --no-cache ninja
NINJA_EXECUTABLE=${VENV}/bin/ninja
${PYTHON_EXECUTABLE} -m pip install --no-cache delocate
DELOCATE_LISTDEPS=${VENV}/bin/delocate-listdeps
DELOCATE_WHEEL=${VENV}/bin/delocate-wheel

# Compile wheels re-using standalone project and archive cache
for VENV in "${VENVS[@]}"; do
    py_mm=$(basename ${VENV})
    PYTHON_EXECUTABLE=${VENV}/bin/python
    PYTHON_INCLUDE_DIR=$( find -L ${MACPYTHON_PY_PREFIX}/${py_mm}/include -name Python.h -exec dirname {} \; )

    echo ""
    echo "PYTHON_EXECUTABLE:${PYTHON_EXECUTABLE}"
    echo "PYTHON_INCLUDE_DIR:${PYTHON_INCLUDE_DIR}"
    echo "PYTHON_LIBRARY:${PYTHON_LIBRARY}"

    if [[ -e $PWD/requirements-dev.txt ]]; then
      ${PYTHON_EXECUTABLE} -m pip install --upgrade -r $PWD/requirements-dev.txt
    fi
    itk_build_path="${SCRIPT_DIR}/../ITK-${py_mm}-macosx_x86_64"
    ${PYTHON_EXECUTABLE} setup.py bdist_wheel --build-type MinSizeRel --plat-name macosx-10.9-x86_64 -G Ninja -- \
      -DCMAKE_MAKE_PROGRAM:FILEPATH=${NINJA_EXECUTABLE} \
      -DITK_DIR:PATH=${itk_build_path} \
      -DITK_USE_SYSTEM_SWIG:BOOL=ON \
      -DWRAP_ITK_INSTALL_COMPONENT_IDENTIFIER:STRING=PythonWheel \
      -DSWIG_EXECUTABLE:FILEPATH=${itk_build_path}/Wrapping/Generators/SwigInterface/swig/bin/swig \
      -DCMAKE_OSX_DEPLOYMENT_TARGET:STRING=10.9 \
      -DCMAKE_OSX_ARCHITECTURES:STRING=x86_64 \
      -DBUILD_TESTING:BOOL=OFF \
      -DRTK_BUILD_APPLICATIONS:BOOL=OFF \
      -DRTK_USE_CUDA:BOOL=OFF \
      -DPYTHON_EXECUTABLE:FILEPATH=${PYTHON_EXECUTABLE} \
      -DPYTHON_INCLUDE_DIR:PATH=${PYTHON_INCLUDE_DIR} \
      -DPYTHON_LIBRARY:FILEPATH=${PYTHON_LIBRARY} \
    || exit 1
    ${PYTHON_EXECUTABLE} setup.py clean
done

${DELOCATE_LISTDEPS} $PWD/dist/*.whl # lists library dependencies
${DELOCATE_WHEEL} $PWD/dist/*.whl # copies library dependencies into wheel