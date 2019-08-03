if ! $OG_AK && [ "$RD" != "/system" ]; then
  uninstall_files $INFORD; sed -i "/#$MODID-UnityIndicator/d" $RD/init.rc
elif ! $OG_AK && [ "$RD" == "/system" ]; then
  sed -i "/#$MODID-UnityIndicator/d" /system/init.rc
fi
if ! $OG_AK && $DIRSEPOL || [ -f /system/addon.d/$MODID-unityrd ]; then
  $MAGISK && ! $SYSOVER && { mount -o rw,remount /system; [ -L /system/vendor ] && mount -o rw,remount /vendor; }
  rm -f /system/addon.d/$MODID-unityrd
  $MAGISK && ! $SYSOVER && { mount -o ro,remount /system; [ -L /system/vendor ] && mount -o ro,remount /vendor; }
fi
. $TMPDIR/addon/AnyKernel3/custom_uninstall.sh
