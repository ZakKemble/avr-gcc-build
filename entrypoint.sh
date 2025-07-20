#!/bin/bash

./avr-gcc-build.sh
echo "Moving toolchains to /output/..."
mv ${BASE}* /output/
mv ./avr-gcc-build.log /output/
echo "Done"
