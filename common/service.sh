# This script will be executed in late_start service mode
# More info in the main Magisk thread
for i in /system/etc/init.d/*; do
  case $i in
    *-ls|*-ls.sh) if [ -f "$i" -a -x "$i" ]; then $i & fi;;
    *) ;;
  esac
done
