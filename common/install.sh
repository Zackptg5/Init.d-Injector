mkdir -p $UNITY/system/etc/init.d
if [ "$MODPATH" == "/system/etc/init.d" ]; then
  ui_print "   Using Anykernel2 by osm0sis @ xda-developers"
  rm -f $INFO
  sed -i -e "s|<INSTALLER>|$INSTALLER|" -e "s|<OUTFD>|$OUTFD|" -e "s|<BOOTMODE>|$BOOTMODE|" $INSTALLER/common/ak2/anykernel.sh
  if [ -z $SLOT ]; then 
    sed -i "/<SLOT>/d" $INSTALLER/common/ak2/anykernel.sh
  else
    sed -i "s|<SLOT>|$SLOT|" $INSTALLER/common/ak2/anykernel.sh
  fi
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
ui_print "   Adding init.d support to rom..."
