#!/usr/bin/env bash
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/guest_milestone_c_post_reboot.sh" "$@"
