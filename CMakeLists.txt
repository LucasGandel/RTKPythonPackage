project(RTKPythonPackage)

cmake_minimum_required(VERSION 2.8)

# RTK git tag
set(GIT_TAG Azure-Pipelines)

find_package(Git)

# Fetching RTK
execute_process(
  COMMAND ${GIT_EXECUTABLE} clone https://github.com/LucasGandel/RTK.git RTK
  WORKING_DIRECTORY ${CMAKE_BINARY_DIR})

execute_process(
  COMMAND ${GIT_EXECUTABLE} checkout ${GIT_TAG}
  WORKING_DIRECTORY ${CMAKE_BINARY_DIR}/RTK)

# Copy build scripts
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/BuildLinuxWheels.sh
  ${CMAKE_BINARY_DIR}/BuildLinuxWheels.sh COPYONLY)

configure_file(${CMAKE_CURRENT_SOURCE_DIR}/BuildWindowsWheels.ps1
  ${CMAKE_BINARY_DIR}/BuildWindowsWheels.ps1 COPYONLY)

configure_file(${CMAKE_CURRENT_SOURCE_DIR}/scripts/manylinux-download-cache-and-build-module-wheels.sh
  ${CMAKE_BINARY_DIR}/RTK/manylinux-download-cache-and-build-module-wheels.sh COPYONLY)

configure_file(${CMAKE_CURRENT_SOURCE_DIR}/scripts/manylinux-build-module-wheels.sh
  ${CMAKE_BINARY_DIR}/RTK/manylinux-build-module-wheels.sh COPYONLY)

configure_file(${CMAKE_CURRENT_SOURCE_DIR}/scripts/macpython-download-cache-and-build-module-wheels.sh
  ${CMAKE_BINARY_DIR}/RTK/macpython-download-cache-and-build-module-wheels.sh COPYONLY)

configure_file(${CMAKE_CURRENT_SOURCE_DIR}/scripts/macpython-build-module-wheels.sh
  ${CMAKE_BINARY_DIR}/RTK/macpython-build-module-wheels.sh COPYONLY)

configure_file(${CMAKE_CURRENT_SOURCE_DIR}/scripts/windows-download-cache-and-build-module-wheels.ps1
  ${CMAKE_BINARY_DIR}/RTK/windows-download-cache-and-build-module-wheels.ps1 COPYONLY)

configure_file(${CMAKE_CURRENT_SOURCE_DIR}/scripts/windows-build-module-wheels.py
  ${CMAKE_BINARY_DIR}/RTK/windows-build-module-wheels.py COPYONLY)