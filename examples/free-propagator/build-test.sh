#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ -z "$QLAT_PREFIX" ]; then
    echo "Error: Please set QLAT_PREFIX environment variable."
    echo ""
    echo "Usage:"
    echo "  export QLAT_PREFIX=/path/to/qlat"
    echo ""
    echo "Example:"
    echo "  export QLAT_PREFIX=/opt/lattice-package/qlat-0.90-cpp"
    echo "  ./build-test.sh"
    exit 1
fi

echo "Using QLAT_PREFIX: $QLAT_PREFIX"

rm -rf build
mkdir build
cd build

cmake ..

make -j$(nproc)

echo ""
echo "=== Build completed ==="
echo "Executables in app/:"
ls -la app/
