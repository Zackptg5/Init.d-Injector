# AnyKernel2 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() {
kernel.string=Kernel Audio Modification Library Injector Add-on
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

## AnyKernel install
ui_print "Unpacking boot image..."
dump_boot

# determine install or uninstall
test -f "initdpatch" && ACTION=Uninstall || ACTION=Install

# begin ramdisk changes

# other needed functions
remove_section_mod() {
  sed -i "/${2//\//\\/}/,/^$/d" $1
}

# restore_file <file>
restore_file() { test -f $1~ && mv -f $1~ $1; }

grep_prop() {
  REGEX="s/^$1=//p"
  shift
  FILES=$@
  [ -z "$FILES" ] && FILES='/system/build.prop'
  sed -n "$REGEX" $FILES 2>/dev/null | head -n 1
}

cp_ch() {
  cp -af "$1" "$2"
  chmod 0755 "$2"
  restorecon "$2"
}


					 
if [ "$ACTION" == "Install" ]; then
  ABILONG=`grep_prop ro.product.cpu.abi`
  
  # Search for init.d support
  INITDPRESENT=$(find . -name 'init*.rc' -type f -exec grep -l 'init.d' {} \;)
  
  if [ -z $INITDPRESENT ]; then
    ui_print "Patching init files..."
  
    # remove old broken init.d	
    test -f /system/bin/sysinit && { backup_file /system/bin/sysinit; sed -i -e '\|<FILES>| a\bin/sysinit~' -e '\|<FILES2>| a\  rm -f $S/bin/sysinit' $patch/initd.sh; }
    test -f /system/xbin/sysinit && { backup_file /system/xbin/sysinit; sed -i -e '\|<FILES>| a\xbin/sysinit~' -e '\|<FILES2>| a\  rm -f $S/xbin/sysinit' $patch/initd.sh; }
    test -f /system/bin/sepolicy-inject && { backup_file /system/bin/sepolicy-inject; sed -i -e '\|<FILES>| a\bin/sepolicy-inject~' -e '\|<FILES2>| a\  rm -f $S/bin/sepolicy-inject' $patch/initd.sh; }
    test -f /system/xbin/sepolicy-inject && { backup_file /system/xbin/sepolicy-inject; sed -i -e '\|<FILES>| a\xbin/sepolicy-inject~' -e '\|<FILES2>| a\  rm -f $S/xbin/sepolicy-inject' $patch/initd.sh; }				   
    for FILE in init*.rc; do
      backup_file $FILE
      remove_section_mod $FILE "# Run sysinit"
      remove_line $FILE "start sysinit"
      remove_section_mod $FILE "# sysinit"
      remove_section_mod $FILE "service sysinit"
      remove_section_mod $FILE "# init.d"
      remove_section_mod $FILE "service userinit"
    done
  
    # add new init.d
    append_file init.rc "# init.d" init
    cp_ch $patch/sysinit sbin/sysinit
    # add indicator file
    cp -f $patch/initdpatch initdpatch
  else
    ui_print "Init.d support already present !"
    ui_print "Adding missing sepolicy patches..."
  fi

  # detect/copy sepolicy-inject (binaries by xmikos@github)
  ui_print "Installing sepolicy-inject to /sbin..."
  case $ABILONG in
    arm64*) cp_ch /tmp/anykernel/tools/setools-android/arm64-v8a/sepolicy-inject sbin/sepolicy-inject;;
    armeabi-v7a*) cp_ch /tmp/anykernel/tools/setools-android/armeabi-v7a/sepolicy-inject sbin/sepolicy-inject;;
    arm*) cp_ch /tmp/anykernel/tools/setools-android/armeabi/sepolicy-inject sbin/sepolicy-inject;;
    x86_64*) cp_ch /tmp/anykernel/tools/setools-android/x86_64/sepolicy-inject sbin/sepolicy-inject;;
    x86*) cp_ch /tmp/anykernel/tools/setools-android/x86/sepolicy-inject sbin/sepolicy-inject;;
    mips64*) cp_ch /tmp/anykernel/tools/setools-android/mips64/sepolicy-inject sbin/sepolicy-inject;;
    mips*) cp_ch /tmp/anykernel/tools/setools-android/mips/sepolicy-inject sbin/sepolicy-inject;;
    *) abort "   ! CPU Type not supported for sepolicy patching! Exiting!";;
  esac

  # SEPOLICY PATCHES BY CosmicDan @xda-developers
  ui_print "Injecting sepolicy with init.d permissions..."
  
  backup_file sepolicy
  sbin/sepolicy-inject -z sysinit -P sepolicy
  sbin/sepolicy-inject -Z sysinit -P sepolicy
  sbin/sepolicy-inject -s init -t sysinit -c process -p transition -P sepolicy
  sbin/sepolicy-inject -s init -t sysinit -c process -p rlimitinh -P sepolicy
  sbin/sepolicy-inject -s init -t sysinit -c process -p siginh -P sepolicy
  sbin/sepolicy-inject -s init -t sysinit -c process -p noatsecure -P sepolicy
  sbin/sepolicy-inject -s sysinit -t sysinit -c dir -p search,read -P sepolicy
  sbin/sepolicy-inject -s sysinit -t sysinit -c file -p read,write,open -P sepolicy
  sbin/sepolicy-inject -s sysinit -t sysinit -c unix_dgram_socket -p create,connect,write,setopt -P sepolicy
  sbin/sepolicy-inject -s sysinit -t sysinit -c lnk_file -p read -P sepolicy
  sbin/sepolicy-inject -s sysinit -t sysinit -c process -p fork,sigchld -P sepolicy
  sbin/sepolicy-inject -s sysinit -t sysinit -c capability -p dac_override -P sepolicy
  sbin/sepolicy-inject -s sysinit -t system_file -c file -p entrypoint,execute_no_trans -P sepolicy
  sbin/sepolicy-inject -s sysinit -t devpts -c chr_file -p read,write,open,getattr,ioctl -P sepolicy
  sbin/sepolicy-inject -s sysinit -t rootfs -c file -p execute,read,open,execute_no_trans,getattr -P sepolicy
  sbin/sepolicy-inject -s sysinit -t shell_exec -c file -p execute,read,open,execute_no_trans,getattr -P sepolicy
  sbin/sepolicy-inject -s sysinit -t zygote_exec -c file -p execute,read,open,execute_no_trans,getattr -P sepolicy
  sbin/sepolicy-inject -s sysinit -t toolbox_exec -c file -p getattr,open,read,ioctl,lock,getattr,execute,execute_no_trans,entrypoint -P sepolicy
  
  # Add backup script
  sed -i -e "s|<block>|$block|" -e "/<FILES>/d" -e "/<FILES2>/d" $patch/initd.sh
  test -d "/system/addon.d" && { ui_print "Installing addon.d script..."; cp_ch $patch/initd.sh /system/addon.d/99initd.sh; } || { ui_print "No addon.d support detected!"; "Patched boot img won't survive dirty flash!"; }

else
  ui_print "Removing init.d patches and sepolicy-inject..."
  rm -f sbin/sysinit sbin/sepolicy-inject initdpatch /system/addon.d/99initd.sh
  restore_file /system/bin/sysinit
  restore_file /system/xbin/sysinit
  restore_file /system/bin/sepolicy-inject
  restore_file /system/xbin/sepolicy-inject
  # restore all .rc files
  for FILE in init*.rc; do
    restore_file $FILE
  done
  restore_file sepolicy
fi

# end ramdisk changes
ui_print "Repacking boot image..."
write_boot

## end install

