# This script will be executed in post-fs-data mode
# More info in the main Magisk thread
for i in /system/etc/init.d/*; do
  if [ -x $i ]; then
    su -c $i &
  fi
done
