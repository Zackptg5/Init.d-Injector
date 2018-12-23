# Init.d Injector
Injects init.d support:
Via post-fs-data script if using magisk
Via init script if system install (also installs setools by Xmikos (https://github.com/xmikos/setools-android))
Built with Unity installer by Zackptg5 (https://github.com/Zackptg5/Unity) and AnyKernel2 by Osm0sis (https://github.com/osm0sis/AnyKernel2/)
[More details in support thread](https://forum.xda-developers.com/android/software-hacking/mod-universal-init-d-injector-wip-t3692105).

## Change Log
### v1.8.4 - 12.23.2018
* Unity v2.2 update

### v1.8.3 -12.21.2018
* Updated to unity v2.1

### v1.8.2 - 12.18.2018
* Unity v2.0 update

### v1.8.1 - 12.10.2018
* Unity v1.8.2 update

### v1.8 - 12.9.2018
* Unity v1.8.1 update
* Fixed limitation in zipname triggers - you can use spaces in the zipname now and trigger is case insensitive
* Removed setools - installs magiskpolicy instead

### v1.7.2 - 10.23.2018
* Unity v1.7.2 update

### v1.7.1 - 9.20.2018
* Unity v1.7.1 update

### v1.7 - 9.2.2018
* Unity v1.7 update

### v1.6 - 8.30.2018
* Unity v1.6.1 update

### v1.5 - 8.24.2018
* Updated to unity v1.6

### v1.4 - 7.18.2018
* Updated ak2
* Unity v1.5.5 update

### v1.3 - 5.7.2018
* Redid ak2 logic - redo scripting (uses initd.sh rather than sysinit), has capability to run init.d scripts as post-fs-data (default) and late_start (add '-ls' to the end of the name of it), use this logic for all system installs
* Magisk uses magisk boot scripts but does the same thing
* Update it so it'll work with sysover if user chooses
* Unity v1.5.4 update

### v1.2.1 - 4.26.2018
* Unity v1.5.3 update

### v1.2 - 4.16.2018
* Unity v1.5.2 update

### v1.1 - 3.17.2018
* Run all scripts except live boot as late start in magisk due to magisk mount occuring after post-fs-data script

### v1.0 - 3.16.2018
* Initial rerelease

## Source Code
* Module [GitHub](https://github.com/Zackptg5/Init.d-Injector)
