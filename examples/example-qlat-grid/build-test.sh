#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ -z "$prefix" ]; then
    echo "Error: Please set prefix environment variable."
    echo ""
    echo "Usage:"
    echo "  export prefix=/path/to/qlat"
    echo ""
    echo "Example:"
    echo "  export prefix=/opt/lattice-package/qlat-0.90-cpp"
    echo "  ./build-test.sh"
    exit 1
fi

export QLAT_PREFIX="$prefix"
echo "Using prefix: $prefix"

rm -rf build
mkdir build
cd build

cmake ..

make -j$(nproc)

echo ""
echo "=== Build completed ==="
echo "Run ./test to execute the test"
