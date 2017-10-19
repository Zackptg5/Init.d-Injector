#!/sbin/sh
# Backups and restores boot (kernel) parition - credits to Osm0sis @xda-developers

. /tmp/backuptool.functions
block=<block>

list_files() {
cat <<EOF
<FILES>
EOF
}

case "$1" in
  backup)
    list_files | while read FILE DUMMY; do
      backup_file $S/$FILE
    done
    # backup custom kernel
    if [ -e "$block" ]; then
      dd if=$block of=/tmp/boot.img
    fi
  ;;
  restore)
    list_files | while read FILE REPLACEMENT; do
      R=""
      [ -n "$REPLACEMENT" ] && R="$S/$REPLACEMENT"
      [ -f "$C/$S/$FILE" ] && restore_file $S/$FILE $R
    done
  ;;
  pre-backup)
    # Stub
  ;;
  post-backup)
    # Stub
  ;;
  pre-restore)
    # Stub
  ;;
  post-restore)
    <FILES2>
    # wait out ROM kernel flash then restore custom kernel
    while sleep 5; do
      [ -e /tmp/boot.img -a -e "$block" ] && dd if=/tmp/boot.img of=$block
      exit
    done&
  ;;
esac
