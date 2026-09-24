#!/bin/bash

dir=$PWD
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

pwd

python3 generate_libflux.py LibFlux.hpp.in > "$dir/LibFlux.hpp"
python3 generate_libflux.py --compiler-check LibFlux.hpp.in > "$dir/LibFluxCompat.hpp"


