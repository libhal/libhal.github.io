#!/bin/bash

set -e

LIBHAL_LIBRARIES=(
  "libhal"

  ## platforms
  "libhal-arm-mcu"

  ## Devices
  "libhal-soft"
  "libhal-actuator"
  "libhal-sensor"
  "libhal-expander"

  ## Utility
  "libhal-util"
  "libhal-canrouter"
  "libhal-mock"

  ## Board Library
  "libhal-micromod"
)

rm -rf libraries
mkdir -p libraries
cd libraries
mkdir include

for library in ${LIBHAL_LIBRARIES[@]}
do
    git clone "https://github.com/libhal/$library.git"
done
