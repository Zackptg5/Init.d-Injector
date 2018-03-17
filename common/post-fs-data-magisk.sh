# This script will be executed in post-fs-data mode
# More info in the main Magisk thread
[ -f $SYS/etc/init.d/0000liveboot ] && su -c $SYS/etc/init.d/0000liveboot &
