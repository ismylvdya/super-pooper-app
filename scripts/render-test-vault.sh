#!/bin/bash
# Рендерит шаблоны тестового vault (Fixtures/TestVault) с датами от «сегодня».
# Использование: scripts/render-test-vault.sh <папка назначения> [YYYY-MM-DD]
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/tools
swiftc -O -o .build/tools/render-test-vault \
  Tests/Support/TestVaultRenderer.swift scripts/render-test-vault/main.swift
.build/tools/render-test-vault Fixtures/TestVault "$1" "${2:-}"
