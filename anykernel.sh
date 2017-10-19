# AnyKernel2 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() {
kernel.string=Kernel Init.d Injector
do.devicecheck=0
do.modules=0
do.cleanup=1
do.cleanuponabort=1
} # end properties

# shell variables
# determine the location of the boot partition
if [ -e /dev/block/platform/*/by-name/boot ]; then
  block=/dev/block/platform/*/by-name/boot
elif [ -e /dev/block/platform/*/*/by-name/boot ]; then
  block=/dev/block/platform/*/*/by-name/boot
fi

# force expansion of the path so we can use it
block=`echo -n $block`;
# enables detection of the suffix for the active boot partition on slot-based devices
is_slot_device=0;

## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. /tmp/anykernel/tools/ak2-core.sh

## AnyKernel file attributes
# set permissions/ownership for included ramdisk files
chmod -R 750 $ramdisk/*
chown -R root:root $ramdisk/*

# Detect if LG bump devicecheck (credits to topjohnwu and Drgravy @xda-developers
LGE_G=false
RBRAND=$(grep_prop ro.product.brand)
RMODEL=$(grep_prop ro.product.device)
if [ "$RBRAND" = "lge" ] || [ "$RBRAND" = "LGE" ];  then 
  if [ "$RMODEL" = "d800" ] ||
     [ "$RMODEL" = "d801" ] ||
     [ "$RMODEL" = "d802" ] ||
     [ "$RMODEL" = "d803" ] || 
     [ "$RMODEL" = "ls980" ] ||
     [ "$RMODEL" = "vs980" ] ||
     [ "$RMODEL" = "l01f" ] || 
     [ "$RMODEL" = "d850" ] ||
     [ "$RMODEL" = "d852" ] ||
     [ "$RMODEL" = "d855" ] ||
     [ "$RMODEL" = "ls990" ] ||
     [ "$RMODEL" = "vs985" ] ||
     [ "$RMODEL" = "f400" ]; then
    LGE_G=true
    ui_print "! Bump device detected !"
	ui_print " "
  fi
fi

ABILONG=`grep_prop ro.product.cpu.abi`

# detect setools (binaries by xmikos @github)
  case $ABILONG in
    arm64*) SETOOLS=/tmp/anykernel/tools/setools-android/arm64-v8a;;
    armeabi-v7a*) SETOOLS=/tmp/anykernel/tools/setools-android/armeabi-v7a;;
    arm*) SETOOLS=/tmp/anykernel/tools/setools-android/armeabi;;
    x86_64*) SETOOLS=/tmp/anykernel/tools/setools-android/x86_64;;
    x86*) SETOOLS=/tmp/anykernel/tools/setools-android/x86;;
    mips64*) SETOOLS=/tmp/anykernel/tools/setools-android/mips64;;
    mips*) SETOOLS=/tmp/anykernel/tools/setools-android/mips;;
    *) ui_print " "; abort " ! CPU Type not supported for sepolicy patching! Exiting!";;
  esac

## AnyKernel install
ui_print "Unpacking boot image..."
ui_print " "
dump_boot

# determine install or uninstall
test -f "initdpatch" && ACTION=Uninstall || ACTION=Install

# begin ramdisk changes
replace_and_patch() {
  test -f $1 && { backup_file $1; rm -f $1; sed -i -e "\|<FILES>| a\$1~" -e "\|<FILES2>| a\  rm -f $1" -e "s|rm -f /system|rm -f $S|g" $patch/initd.sh; }
}

if [ "$ACTION" == "Install" ]; then
  # Add indicator file
  touch initdpatch

  # Search for init.d support
  [ "$(find . -name 'init*.rc' -type f -exec grep -l 'init.d' {} \;)" ] && ui_print "Init files already patched!" || { ui_print "Patching init files..."; backup_file init.rc; append_file init.rc "# init.d" init; }
  
  # replace old broken init.d
  ui_print "Replacing sysinit..."
  test -f /system/bin/sysinit && { backup_file /system/bin/sysinit; sed -i -e '\|<FILES>| a\bin/sysinit' -e '\|<FILES>| a\bin/sysinit~' $patch/initd.sh; }
  test -f /system/xbin/sysinit && { backup_file /system/xbin/sysinit; sed -i -e '\|<FILES>| a\xbin/sysinit' -e '\|<FILES>| a\xbin/sysinit~' $patch/initd.sh; }
  replace_and_patch /system/bin/sepolicy-inject
  replace_and_patch /system/xbin/sepolicy-inject
  replace_and_patch /system/bin/seinfo
  replace_and_patch /system/xbin/seinfo
  replace_and_patch /system/bin/sesearch
  replace_and_patch /system/xbin/sesearch
  cp -f $patch/sysinit /system/bin/sysinit
  chmod 0755 /system/bin/sysinit

  # Add backup script
  sed -i -e "s|<block>|$block|" -e "/<FILES>/d" -e "/<FILES2>/d" $patch/initd.sh
  test -d "/system/addon.d" && { ui_print "Installing addon.d script..."; cp -f $patch/initd.sh /system/addon.d/99initd.sh; chmod 0755 /system/addon.d/99initd.sh; } || { ui_print "No addon.d support detected!"; "Patched boot img won't survive dirty flash!"; }

  # copy setools
  ui_print "Installing setools to /sbin..."
  cp -f $SETOOLS/* sbin
  chmod 0755 sbin/*

  # sepolicy patches by CosmicDan @xda-developers
  ui_print "Injecting sepolicy with init.d permissions..."
  
  backup_file sepolicy
  $SETOOLS/sepolicy-inject -z sysinit -P sepolicy
  $SETOOLS/sepolicy-inject -Z sysinit -P sepolicy
  $SETOOLS/sepolicy-inject -s init -t sysinit -c process -p transition -P sepolicy
  $SETOOLS/sepolicy-inject -s init -t sysinit -c process -p rlimitinh -P sepolicy
  $SETOOLS/sepolicy-inject -s init -t sysinit -c process -p siginh -P sepolicy
  $SETOOLS/sepolicy-inject -s init -t sysinit -c process -p noatsecure -P sepolicy
  $SETOOLS/sepolicy-inject -s sysinit -t sysinit -c dir -p search,read -P sepolicy
  $SETOOLS/sepolicy-inject -s sysinit -t sysinit -c file -p read,write,open -P sepolicy
  $SETOOLS/sepolicy-inject -s sysinit -t sysinit -c unix_dgram_socket -p create,connect,write,setopt -P sepolicy
  $SETOOLS/sepolicy-inject -s sysinit -t sysinit -c lnk_file -p read -P sepolicy
  $SETOOLS/sepolicy-inject -s sysinit -t sysinit -c process -p fork,sigchld -P sepolicy
  $SETOOLS/sepolicy-inject -s sysinit -t sysinit -c capability -p dac_override -P sepolicy
  $SETOOLS/sepolicy-inject -s sysinit -t system_file -c file -p entrypoint,execute_no_trans -P sepolicy
  $SETOOLS/sepolicy-inject -s sysinit -t devpts -c chr_file -p read,write,open,getattr,ioctl -P sepolicy
  $SETOOLS/sepolicy-inject -s sysinit -t rootfs -c file -p execute,read,open,execute_no_trans,getattr -P sepolicy
  $SETOOLS/sepolicy-inject -s sysinit -t shell_exec -c file -p execute,read,open,execute_no_trans,getattr -P sepolicy
  $SETOOLS/sepolicy-inject -s sysinit -t zygote_exec -c file -p execute,read,open,execute_no_trans,getattr -P sepolicy
  $SETOOLS/sepolicy-inject -s sysinit -t toolbox_exec -c file -p getattr,open,read,ioctl,lock,getattr,execute,execute_no_trans,entrypoint -P sepolicy

else
  ui_print "Removing init.d patches and sepolicy-inject..."
  rm -f sbin/sepolicy-inject sbin/sesearch sbin/seinfo /system/addon.d/99initd.sh
  restore_file /system/bin/sysinit
  restore_file /system/xbin/sysinit
  restore_file /system/bin/sepolicy-inject
  restore_file /system/xbin/sepolicy-inject
  restore_file init.rc
  restore_file sepolicy
fi

# end ramdisk changes
ui_print " "
ui_print "Repacking boot image..."
write_boot

## end install
