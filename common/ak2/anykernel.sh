# AnyKernel2 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# reinitialize needed vars and functions
INSTALLER=<INSTALLER>
OUTFD=<OUTFD>
BOOTMODE=<BOOTMODE>
SLOT=<SLOT>
MAGISK=false

ui_print() {
  $BOOTMODE && echo "$1" || echo -e "ui_print $1\nui_print" >> /proc/self/fd/$OUTFD
}

. $INSTALLER/config.sh
. $INSTALLER/common/unityfiles/util_functions.sh

# shell variables
ramdisk_compression=auto
# determine the location of the boot partition
if [ "$(find /dev/block -name boot | head -n 1)" ]; then
  block=$(find /dev/block -name boot | head -n 1)
elif [ -e /dev/block/platform/sdhci-tegra.3/by-name/LNX ]; then
  block=/dev/block/platform/sdhci-tegra.3/by-name/LNX
else
  abort "   ! Boot img not found! Aborting!"
fi

# force expansion of the path so we can use it
block=`echo -n $block`;

## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. $INSTALLER/common/ak2/tools/ak2-core.sh

## AnyKernel file attributes
# set permissions/ownership for included ramdisk files
chmod -R 750 $ramdisk/*
chown -R root:root $ramdisk/*

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

# File list
for FILE in $(find $overlay /system /vendor -type f -name '*.rc'); do
  [ "$(grep 'service sysinit' $FILE)" ] && { INITFILE=$FILE; break; }
done

if [ "$INITFILE" ] && [ "$(dirname $INITFILE)" == "$INSTALLER/common/ak2/ramdisk" ]; then
  list="init.rc sepolicy $INITFILE"
else
  list="init.rc sepolicy"
fi

# determine install or uninstall
if [ "$INITFILE" ]; then
  [ "$(grep '#initdinjector' $INITFILE)" ] && ACTION=Uninstall
else
  [ "$(grep '#initdinjector' $overlay/init.rc)" ] && ACTION=Uninstall
fi

# use sudaemon if present, permissive shell otherwise
if [ "$($SETOOLS/sesearch --allow -s sudaemon $overlay/sepolicy)" ]; then
  DOMAIN=sudaemon
else
  DOMAIN=shell
fi

# begin ramdisk changes
if [ -z $ACTION ]; then
  ui_print "- Installing"
  ui_print "   Adding init.d support to kernel..."
  
  if [ "$DOMAIN" == "sudaemon" ]; then
    ui_print "   Sudaemon found! No need for sepolicy patching"
  else
    ui_print "   Sudaemon not found! Patching sepolicy..."
    backup_file $overlay/sepolicy
    $SETOOLS/sepolicy-inject -Z shell -P $overlay/sepolicy
  fi
  
  # add proper init.d patch
  if [ "$INITFILE" ]; then
    if [ ! "$(sed -n "/service sysinit/,/^$/{/seclabel/p}" $INITFILE)" ]; then
      ui_print "   Sysinit detected!"
      ui_print "   Patching $INITFILE..."
      sed -i "/service sysinit/a\    seclabel u:r:$DOMAIN:s0 #initdinjector" $INITFILE
    else
      ui_print "   Sysinit detected! Init.d support natively present!"
      abort "   Aborting!"
    fi
  else
    ui_print "   Sysinit not detected!"
    ui_print "   Patching init.rc..."
    sed -i "s/<DOMAIN>/$DOMAIN/" $INSTALLER/common/ak2/patch/init.initd.rc
    cp -f $INSTALLER/common/ak2/patch/init.initd.rc $overlay/init.initd.rc
    backup_file $overlay/init.rc
    sed -i '1 i\import /init.initd.rc #initdinjector' $overlay/init.rc
    ui_print "   Installing sysinit..."
    cp -f $INSTALLER/common/ak2/patch/sysinit /system/bin/sysinit
    chown 0:2000 /system/bin/sysinit
    chmod 0755 /system/bin/sysinit
    chcon 'u:object_r:system_file:s0' /system/bin/sysinit
  fi
  
  # add test init.d script
  ui_print "   Installing test init.d script..."
  mkdir -p /system/etc/init.d
  cp -f $INSTALLER/common/ak2/patch/0000InitdinjectorTest /system/etc/init.d/0000InitdinjectorTest
  
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
  
  ui_print "   Setting permissions..."
  set_permissions
else
  ui_print "- Uninstalling"
  ui_print "   Removing init.d support to kernel..."
  ui_print "   Removing init.d patches and sepolicy-inject..."
  rm -f $overlay/init.initd.rc /system/etc/init.d/InitdinjectorTest $overlay/sbin/sepolicy-inject $overlay/sbin/sesearch $overlay/sbin/seinfo
  ui_print "   Restoring original files..."
  if [ "$INITFILE" ]; then
    sed -i "/seclabel u:r:.*:s0 #initdinjector/d" $INITFILE
  else
    sed -i "/import \/init.initd.rc #initdinjector/d" $overlay/init.rc
  fi
  [ "$DOMAIN" == "shell" ] && restore_file $overlay/sepolicy
  for FILE in /system/bin/sepolicy-inject /system/xbin/sepolicy-inject /system/bin/seinfo /system/xbin/seinfo /system/bin/sesearch /system/xbin/sesearch; do
    restore_file $FILE
  done
fi

#end ramdisk changes
ui_print "   Repacking boot image..."
write_boot

# end install
