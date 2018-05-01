##########################################################################################
#
# Magisk Module Template Config Script
# by topjohnwu
# 
##########################################################################################
##########################################################################################
# 
# Instructions:
# 
# 1. Place your files into system folder (delete the placeholder file)
# 2. Fill in your module's info into module.prop
# 3. Configure the settings in this file (config.sh)
# 4. If you need boot scripts, add them into common/post-fs-data.sh or common/service.sh
# 5. Add your additional or modified system properties into common/system.prop
# 
##########################################################################################

##########################################################################################
# Defines
##########################################################################################

# NOTE: This part has to be adjusted to fit your own needs

# Set to true if you need to enable Magic Mount
# Most mods would like it to be enabled
AUTOMOUNT=false

# Set to true if you need to load system.prop
PROPFILE=false

# Set to true if you need post-fs-data script
POSTFSDATA=true

# Set to true if you need late_start service script
LATESTARTSERVICE=true

# Unity Variables
# Uncomment and change 'MINAPI' and 'MAXAPI' to the minimum and maxium android version for your mod (note that magisk has it's own minimum api: 21 (lollipop))
# Uncomment DYNAMICOREO if you want libs installed to vendor for oreo and newer and system for anything older
# Uncomment DYNAMICAPP if you want anything in $INSTALLER/system/app to be installed to the optimal app directory (/system/priv-app if it exists, /system/app otherwise)
# Uncomment SYSOVERRIDE if you want the mod to always be installed to system (even on magisk)
#MINAPI=21
#MAXAPI=25
#SYSOVERRIDE=true
#DYNAMICOREO=true
#DYNAMICAPP=true

# Custom Variables - Keep everything within this function
unity_custom() {
  # Patch boot img if not using root solution that supports boot scripts
  if ! $MAGISK || $SYSOVERRIDE; then
    ui_print "   Using Anykernel2 by osm0sis @ xda-developers"
    rm -f $INFO
    sed -i -e "s|<INSTALLER>|$INSTALLER|" -e "s|<OUTFD>|$OUTFD|" -e "s|<BOOTMODE>|$BOOTMODE|" -e "s|<SLOT>|$SLOT|" -e "s|<MAGISK>|$MAGISK|" $INSTALLER/common/ak2/anykernel.sh
    mkdir -p $INSTALLER/common/ak2/bin
    cd $INSTALLER/common/ak2
    case $ABILONG in
      arm64*) BBABI=arm64;;
      arm*) BBABI=arm;;
      x86_64*) BBABI=x86_64;;
      x86*) BBABI=x86;;
      mips64*) BBABI=mips64;;
      mips*) BBABI=mips;;
      *) $MAGISK && rm -rf $MODPATH; abort "Unknown architecture: $ABILONG";;
    esac
    BB=$INSTALLER/common/ak2/tools/busybox-$BBABI
    chmod 755 $BB
    $BB chmod -R 755 $INSTALLER/common/ak2/tools $INSTALLER/common/ak2/bin
    for i in $($BB --list); do
      $BB ln -s $BB $INSTALLER/common/ak2/bin/$i
    done
    if [ $? != 0 -o -z "$(ls $INSTALLER/common/ak2/bin)" ]; then
      abort "   ! Recovery busybox setup failed!"
    fi
    PATH="$INSTALLER/common/ak2/bin:$PATH" $BB ash $INSTALLER/common/ak2/anykernel.sh $2
    if [ $? != "0" ]; then
      abort "   ! Install failed!"
    fi
    cleanup
  fi
}

##########################################################################################
# Installation Message
##########################################################################################

# Set what you want to show when installing your mod

print_modname() {
  ui_print " "
  ui_print "    *******************************************"
  ui_print "    *<name>*"
  ui_print "    *******************************************"
  ui_print "    *<version>*"
  ui_print "    *<author>*"
  ui_print "    *******************************************"
  ui_print " "
}

##########################################################################################
# Replace list
##########################################################################################

# List all directories you want to directly replace in the system
# By default Magisk will merge your files with the original system
# Directories listed here however, will be directly mounted to the correspond directory in the system

# You don't need to remove the example below, these values will be overwritten by your own list
# This is an example
REPLACE="
/system/app/Youtube
/system/priv-app/SystemUI
/system/priv-app/Settings
/system/framework
"

# Construct your own list here, it will overwrite the example
# !DO NOT! remove this if you don't need to replace anything, leave it empty as it is now
REPLACE="
"

##########################################################################################
# Permissions
##########################################################################################

# NOTE: This part has to be adjusted to fit your own needs

set_permissions() {
  # DEFAULT PERMISSIONS, DON'T REMOVE THEM 
  $MAGISK && set_perm_recursive $MODPATH 0 0 0755 0644
 
  # CUSTOM PERMISSIONS
  
  # Some templates if you have no idea what to do:
  # Note that all files/folders have the $UNITY prefix - keep this prefix on all of your files/folders
  # Also note the lack of '/' between variables - preceding slashes are already included in the variables
  # Use $SYS for system and $VEN for vendor (Do not use $SYS$VEN, the $VEN is set to proper vendor path already - could be /vendor, /system/vendor, etc.)

  # set_perm_recursive  <dirname>                <owner> <group> <dirpermission> <filepermission> <contexts> (default: u:object_r:system_file:s0)
  # set_perm_recursive $UNITY$SYS/lib 0 0 0755 0644
  # set_perm_recursive $UNITY$VEN/lib/soundfx 0 0 0755 0644

  # set_perm  <filename>                         <owner> <group> <permission> <contexts> (default: u:object_r:system_file:s0)
  # set_perm $UNITY$SYS/lib/libart.so 0 0 0644
}
