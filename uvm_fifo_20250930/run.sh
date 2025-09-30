#!/usr/bin/env bash
# Linux helper script to compile & run with QuestaSim (UVM 1.1d).
# Usage: ./run.sh [gui]
set -euo pipefail

if [[ -z "${UVM_HOME:-}" ]]; then
  echo "ERROR: UVM_HOME is not set. Point it to your UVM 1.1d (contains src/uvm.sv)."
  echo "Example: export UVM_HOME=$QUESTA_HOME/uvm-1.1d"
  exit 1
fi

make "$@"
