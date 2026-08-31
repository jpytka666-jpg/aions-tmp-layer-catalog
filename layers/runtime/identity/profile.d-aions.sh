# Shown after login for user aions
if [[ -x /opt/aions/repo/scripts/aions-ctl ]]; then
  /opt/aions/repo/scripts/aions-ctl status 2>/dev/null | head -12
fi
