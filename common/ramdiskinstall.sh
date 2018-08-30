PATCHONLY=false
# detect setools (binaries by xmikos @github)
tar -xf $INSTALLER/common/setools-android.tar.xz -C $INSTALLER/common
case $ABILONG in
  x86_64*) SETOOLS=$INSTALLER/common/setools-android/x86_64;;
  x86*) SETOOLS=$INSTALLER/common/setools-android/x86;;
  arm64*) SETOOLS=$INSTALLER/common/setools-android/arm64-v8a;;
  armeabi-v7a*) SETOOLS=$INSTALLER/common/setools-android/armeabi-v7a;;
  arm*) SETOOLS=$INSTALLER/common/setools-android/armeabi;;
esac
chmod -R 0755 $SETOOLS

# use sudaemon if present, permissive shell otherwise
if [ "$($SETOOLS/sesearch --allow -s su $RD/sepolicy)" ]; then
  DOMAIN=su
elif [ "$($SETOOLS/sesearch --allow -s sudaemon $RD/sepolicy)" ]; then
  DOMAIN=sudaemon
else
  DOMAIN=shell
fi

# detect already present init.d support
for FILE in $(find $RD /system /vendor -type f -name '*.rc'); do
  if [ "$(grep 'service sysinit' $FILE)" ]; then
    if [ "$(sed -n "/service sysinit/,/^$/{/seclabel/p}" $FILE)" ]; then
      # Only patch for current init.d implementation if it uses same seclabel to avoid scripts running more than once at boot
      DOMAIN2=$(sed -n "/service sysinit/,/^$/{/seclabel u:r:.*:s0/{s/.*seclabel u:r:\(.*\):s0.*/\1/; p}}" $FILE)
      [ "$DOMAIN" == "$DOMAIN2" ] && { PATCHONLY=true; $INSTALL && { ui_print "   Sysinit w/ seclabel detected in $(echo $FILE | sed "s|$ramdisk||")!"; "   Using existing init.d implementation!"; }; }
    fi
    break
  fi
done

# add proper init.d patch
if ! $PATCHONLY; then
  sed -i "s/<DOMAIN>/$DOMAIN/g" $INSTALLER/common/init.initd.rc
  cp_ch -n $INSTALLER/common/init.initd.rc /system/etc/init/init.initd.rc
  cp_ch -np 0755 $INSTALLER/common/initd.sh /system/bin/initd.sh
fi

case $DOMAIN in
  "su"|"sudaemon") ui_print "   $DOMAIN secontext found! No need for sepolicy patching";;
  *) ui_print "   Setting $DOMAIN to permissive..."; cp_ch $RD/sepolicy $RD/sepolicy; $SETOOLS/sepolicy-inject -Z $DOMAIN -P $RD/sepolicy;;
esac
  
# copy setools
ui_print "   Adding setools to /sbin..."
for FILE in /system/bin/sepolicy-inject /system/xbin/sepolicy-inject /system/bin/seinfo /system/xbin/seinfo /system/bin/sesearch /system/xbin/sesearch; do
  [ -f "$FILE" ] && mv -f $FILE $FILE.bak
done
for FILE in sepolicy-inject seinfo sesearch; do
  cp_ch -p 0755 $SETOOLS/$FILE $RD/sbin/$FILE
done
