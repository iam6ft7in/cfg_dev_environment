#!/usr/bin/env bash
# BATS tests for {{REPO_NAME}} helpers
# Run with: bats tests/test_helpers.sh

# shellcheck source=/dev/null
source "$(dirname "$0")/../lib/helpers.sh"

@test "log_info does not exit non-zero" {
    run log_info "test message"
    [ "${status}" -eq 0 ]
}

@test "require_command finds existing command" {
    run require_command bash
    [ "${status}" -eq 0 ]
}

@test "require_command fails for missing command" {
    run require_command nonexistent_command_xyz
    [ "${status}" -ne 0 ]
}
