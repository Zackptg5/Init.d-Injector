# AnyKernel2 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# reinitialize needed vars and functions
INSTALLER=<INSTALLER>
OUTFD=<OUTFD>
BOOTMODE=<BOOTMODE>
SLOT=<SLOT>
MAGISK=<MAGISK>

ui_print() {
  $BOOTMODE && echo "$1" || echo -e "ui_print $1\nui_print" >> /proc/self/fd/$OUTFD
}

. $INSTALLER/config.sh
. $INSTALLER/common/unityfiles/util_functions.sh

# shell variables
ramdisk_compression=auto
block=auto;


## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. $INSTALLER/common/ak2/tools/ak2-core.sh

## AnyKernel file attributes
# set permissions/ownership for included ramdisk files
chmod -R 750 $ramdisk/*
chown -R root:root $ramdisk/*

# File list
list="sepolicy"

# detect setools (binaries by xmikos @github)
case $(grep_prop ro.product.cpu.abi) in
  arm64*) SETOOLS=$INSTALLER/common/ak2/tools/setools-android/arm64-v8a;;
  armeabi-v7a*) SETOOLS=$INSTALLER/common/ak2/tools/setools-android/armeabi-v7a;;
  arm*) SETOOLS=$INSTALLER/common/ak2/tools/setools-android/armeabi;;
  x86_64*) SETOOLS=$INSTALLER/common/ak2/tools/setools-android/x86_64;;
  x86*) SETOOLS=$INSTALLER/common/ak2/tools/setools-android/x86;;
  mips64*) SETOOLS=$INSTALLER/common/ak2/tools/setools-android/mips64;;
  mips*) SETOOLS=$INSTALLER/common/ak2/tools/setools-android/mips;;
  *) ui_print " "; abort " ! CPU Type not supported for sepolicy patching! Exiting!";;
esac

## AnyKernel install
ui_print "   Unpacking boot image..."
ui_print " "
dump_boot

# determine install or uninstall
[ -f "/system/etc/init/init.initd.rc" ] && ACTION=Uninstall

# use sudaemon if present, permissive shell otherwise
if [ "$($SETOOLS/sesearch --allow -s su $overlay/sepolicy)" ]; then
  DOMAIN=su
elif [ "$($SETOOLS/sesearch --allow -s sudaemon $overlay/sepolicy)" ]; then
  DOMAIN=sudaemon
else
  DOMAIN=shell
fi

# detect already present init.d support
for FILE in $(find $overlay /system /vendor -type f -name '*.rc'); do
  [ "$(grep 'service sysinit' $FILE)" ] && { INITFILE=$FILE; break; }
done

# begin ramdisk changes
if [ -z $ACTION ]; then
  scripts_install() {
    ui_print "   Installing scripts..."
    sed -i "s/<DOMAIN>/$DOMAIN/g" $INSTALLER/common/ak2/patch/init.initd.rc
    cp_ch_nb $INSTALLER/common/ak2/patch/init.initd.rc /system/etc/init/init.initd.rc 0644 false
    cp_ch_nb $INSTALLER/common/ak2/patch/initd.sh /system/bin/initd.sh 0755 false
  }
  
  ui_print "- Installing"    
  # add proper init.d patch
  if [ "$INITFILE" ]; then
    if [ "$(sed -n "/service sysinit/,/^$/{/seclabel/p}" $INITFILE)" ]; then
      ui_print "   Sysinit w/ seclabel detected in $(echo $INITFILE | sed "s|$ramdisk||")!"
      DOMAIN=$(sed -n "/service sysinit/,/^$/{/seclabel u:r:.*:s0/{s/.*seclabel u:r:\(.*\):s0.*/\1/; p}}" $INITFILE)
    else
      scripts_install
    fi
  else
    scripts_install
  fi
  
  case $DOMAIN in
    "su"|"sudaemon") ui_print "   $DOMAIN found! No need for sepolicy patching";;
    "shell") ui_print "   Setting $DOMAIN to permissive..."; backup_file $overlay/sepolicy; $SETOOLS/sepolicy-inject -Z $DOMAIN -P $overlay/sepolicy;;
  esac
    
  # copy setools
  ui_print "   Adding setools to /sbin..."
  backup_and_remove /system/bin/sepolicy-inject
  backup_and_remove /system/xbin/sepolicy-inject
  backup_and_remove /system/bin/seinfo
  backup_and_remove /system/xbin/seinfo
  backup_and_remove /system/bin/sesearch
  backup_and_remove /system/xbin/sesearch
  cp -f $SETOOLS/* $overlay/sbin
  chmod 0755 $overlay/sbin/*
else
  ui_print "- Uninstalling"
  ui_print "   Removing patches and setools..."
  rm -f /system/bin/initd.sh /system/etc/init/init.initd.rc $overlay/sbin/sepolicy-inject $overlay/sbin/sesearch $overlay/sbin/seinfo
  ui_print "   Restoring original files..."
  [ "$DOMAIN" == "shell" ] && restore_file $overlay/sepolicy
  for FILE in /system/bin/sepolicy-inject /system/xbin/sepolicy-inject /system/bin/seinfo /system/xbin/seinfo /system/bin/sesearch /system/xbin/sesearch; do
    restore_file $FILE
  done
fi

#end ramdisk changes
ui_print "   Repacking boot image..."
write_boot

# end install
