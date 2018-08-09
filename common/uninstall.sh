if ! $MAGISK || $SYSOVERRIDE; then
  # Patch boot img if not using root solution that supports boot scripts
  ROOTTYPE="other root/rootless"
  POSTFSDATA=false
  LATESTARTSERVICE=false
  ak2
fi
