if $MAGISK; then
  ui_print "   Note that to remove any ramdisk changes,"
  ui_print "   you will need to flash this zip again"
  ui_print " "
  ui_print "   Removing mod in magisk manager won't remove"
  ui_print "   ramdisk changes"
  sleep 2
fi

# Only run if needed
if ! $DIRSEPOL && [ ! "$(ls -A $TMPDIR/addon/AnyKernel3/ramdisk 2>/dev/null)" ] && [ ! "$(ls -A $TMPDIR/addon/AnyKernel3/patch 2>/dev/null)" ] && [ ! "$(sed -n '/^# Add your custom install logic here - do not remove this line$/,$p' anykernel.sh | sed '1d;/^#/d;/^$/d')" ]; then
  rm -rf $TMPDIR/addon/AnyKernel3
  exit 0
fi

# Remove ramdisk mod if exists
if [ "$(grep "#$MODID-UnityIndicator" $RD/init.rc 2>/dev/null)" ]; then
  ui_print " "
  ui_print "   ! Mod detected in ramdisk!"
  ui_print "   ! Upgrading mod ramdisk modifications..."
  . $TMPDIR/addon/AnyKernel3/uninstall.sh
fi

# Use comment as install indicator
cd $TMPDIR/addon/AnyKernel3
. anykernel.sh
[ $? != 0 ] && abort
cd /
[ ! -s $INFORD ] && rm -f $INFORD
$OG_AK && DIRSEPOL=false || echo "#$MODID-UnityIndicator" >> $RD/init.rc

# Direct sepolicy patching if applicable
if $DIRSEPOL && [ -s $TMPDIR/common/sepolicy.sh ]; then
  ui_print " "
  ui_print "   Applying sepolicy patches directly to ramdisk..."
  sed -i -e '/^#.*/d' -e '/^$/d' $TMPDIR/common/sepolicy.sh
  echo -n 'magiskpolicy --load $RD/sepolicy --save $RD/sepolicy' > $TMPDIR/addon/AnyKernel3/sepolicy.sh
  while read LINE; do
    case $LINE in
      \"*\") echo -n " $LINE" >> $TMPDIR/addon/AnyKernel3/sepolicy.sh;;
      \"*) echo -n " $LINE\"" >> $TMPDIR/addon/AnyKernel3/sepolicy.sh;;
      *\") echo -n " \"$LINE" >> $TMPDIR/addon/AnyKernel3/sepolicy.sh;;
      *) echo -n " \"$LINE\"" >> $TMPDIR/addon/AnyKernel3/sepolicy.sh;;
    esac
  done < $TMPDIR/common/sepolicy.sh
  chmod 0755 $TMPDIR/addon/AnyKernel3/sepolicy.sh
  . $TMPDIR/addon/AnyKernel3/sepolicy.sh
fi

if ! $OG_AK && [ "$RD" == "/system" ] && [ -d "$ramdisk" ]; then
  $MAGISK && ! $SYSOVER && mount -o rw,remount /system
  cp_ch -r $ramdisk $RD
  $MAGISK && ! $SYSOVER && mount -o ro,remount /system
fi

# Use addon.d if available, else add script to remove mod from system/magisk in event mod is only removed from ramdisk (like dirty flashing)
if ! $OG_AK && [ "$RD" != "/system" ]; then
  if [ -d /system/addon.d ]; then
    $MAGISK && ! $SYSOVER && mount -o rw,remount /system
    # Copy needed binaries
    mkdir /system/addon.d/unitytools 2>/dev/null
    cp -rf $TMPDIR/common/unityfiles/tools/$ARCH32/* /system/addon.d/unitytools/
    # Copy ramdisk modifications and patches
    [ "$(ls -A $TMPDIR/addon/AnyKernel3/rdtmp 2>/dev/null)" ] && cp_ch -rn $TMPDIR/addon/AnyKernel3/rdtmp /system/addon.d/$MODID-unityakfiles
    [ "$(ls -A $TMPDIR/addon/AnyKernel3/patch 2>/dev/null)" ] && cp_ch -rn $TMPDIR/addon/AnyKernel3/patch /system/addon.d/$MODID-unityakfiles
    # Place mod script
    [ "$(sed -n '/^# Add your custom install logic here - do not remove this line$/,$p' $TMPDIR/addon/AnyKernel3/anykernel.sh | sed '1d;/^#/d;/^$/d')" ] && sed -i "1i #!/system/bin/sh\nMODID=$MODID" $TMPDIR/addon/AnyKernel3/anykernel.sh || echo -e "#!/system/bin/sh\nMODID=$MODID" > $TMPDIR/addon/AnyKernel3/anykernel.sh
    [ -f "$TMPDIR/addon/AnyKernel3/sepolicy.sh" ] && sed -i "2r $TMPDIR/addon/AnyKernel3/sepolicy.sh" $TMPDIR/addon/AnyKernel3/anykernel.sh
    [ "$(tail -1 "$TMPDIR/addon/AnyKernel3/anykernel.sh")" ] && echo "" >> $TMPDIR/addon/AnyKernel3/anykernel.sh
    cp_ch -n $TMPDIR/addon/AnyKernel3/anykernel.sh /system/addon.d/$MODID-unityak 0755
    # Place master Unity script
    sed -i 's|^home=.*|home=$TMPDIR/unitytools|' $TMPDIR/addon/AnyKernel3/ak3-core.sh
    cp_ch -i $TMPDIR/addon/AnyKernel3/ak3-core.sh /system/addon.d/unitytools/ak3-core 0755
    cp_ch -i $TMPDIR/addon/AnyKernel3/addon.sh /system/addon.d/99-unityak.sh 0755
    cp_ch -i $TMPDIR/addon/AnyKernel3/functions.sh /system/addon.d/unitytools/functions 0755
    $MAGISK && ! $SYSOVER && mount -o ro,remount /system
  else
    sed -i -e "/# CUSTOM USER SCRIPT/ r $TMPDIR/common/uninstall.sh" -e '/# CUSTOM USER SCRIPT/d' $TMPDIR/addon/AnyKernel3/noaddon.sh
    mv -f $TMPDIR/addon/AnyKernel3/noaddon.sh $TMPDIR/addon/AnyKernel3/$MODID-ramdisk.sh
    install_script -p $TMPDIR/addon/AnyKernel3/$MODID-ramdisk.sh
  fi
fi
