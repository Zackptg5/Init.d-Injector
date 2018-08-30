# This script will be executed in post-fs-data mode
# More info in the main Magisk thread
for i in /system/etc/init.d/*; do
  case $i in
    *-ls|*-ls.sh);;
    *) if [ -f "$i" -a -x "$i" ]; then $i & fi;;
  esac
done
