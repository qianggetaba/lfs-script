# lfs-script
shell script for linux from scratch


after clone this repo.

download book and package
```
bash lfs-8.4.sh
```
after lfs-8.4.sh, run ``su -lfs``, begin to make ``/tools``
```
bash lfs_tools.sh
```
at the end of ``lfs_tools.sh``, exit to normal user 'run pre-chroot.sh'

```
sudo chroot "$LFS" /tools/bin/env -i \
    HOME=/root                  \
    TERM="$TERM"                \
    PS1='(lfs chroot) \u:\w\$ ' \
    PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin \
    /tools/bin/bash --login +h
```

after into chroot, first run inchroot.sh, then inchroot2.sh


if in chroot need recompile tools
1. sudo chown -R -v lfs $LFS/tools # run as normal user with sudo permission, note: echo echo "LFS:$LFS"
2. su - lfs  # then make and install
3. sudo chown -R -v root $LFS/tools # back to chown to root
