if $MAGISK; then
  POSTFSDATA=false
  rm -rf $INSTALLER/system/bin
  cp_ch_nb $INSTALLER/common/post-fs-data2.sh $MOUNTPATH/.core/post-fs-data.d/0000InitdInjector.sh 0755
  patch_script $MOUNTPATH/.core/post-fs-data.d/0000InitdInjector.sh
  cp_ch_nb $INSTALLER/common/service.sh $MOUNTPATH/.core/service.d/0000InitdInjector.sh 0755
  patch_script $MOUNTPATH/.core/service.d/0000InitdInjector.sh
elif [ "$MODPATH" == "/system/etc/init.d" ]; then
  ui_print "   Using Anykernel2 by osm0sis @ xda-developers"
  rm -f $INFO
  sed -i -e "s|<INSTALLER>|$INSTALLER|" -e "s|<OUTFD>|$OUTFD|" -e "s|<BOOTMODE>|$BOOTMODE|" $INSTALLER/common/ak2/anykernel.sh
  if [ -z $SLOT ]; then sed -i "/<SLOT>/d" $INSTALLER/common/ak2/anykernel.sh; else sed -i "s|<SLOT>|$SLOT|" $INSTALLER/common/ak2/anykernel.sh; fi
  mkdir -p $INSTALLER/common/ak2/bin
  cd $INSTALLER/common/ak2
  BB=$INSTALLER/common/ak2/tools/busybox
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
else
  ui_print "   Adding init.d support to rom..."
  cp_ch_nb $SYS/bin/debuggerd $UNITY$SYS/bin/debuggerd.real
fi
