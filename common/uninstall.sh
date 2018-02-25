if $MAGISK; then
  rm -f $MOUNTPATH/.core/post-fs-data.d/0000InitdInjector.sh $MOUNTPATH/.core/service.d/0000InitdInjector.sh
else
  mv -f $SYS/bin/debuggerd.real $SYS/bin/debuggerd
fi
