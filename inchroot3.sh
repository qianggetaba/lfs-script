#!/bin/bash -e

if [ "$(whoami)" != "root" ]; then
        echo "Script must be run as user: root"
        exit -1
fi

# after inchroot2.sh install all chapter 6 software, and use new chroot command at the end of chapter 6

rm -f /usr/lib/lib{bfd,opcodes}.a
rm -f /usr/lib/libbz2.a
rm -f /usr/lib/lib{com_err,e2p,ext2fs,ss}.a
rm -f /usr/lib/libltdl.a
rm -f /usr/lib/libfl.a
rm -f /usr/lib/libz.a

find /usr/lib /usr/libexec -name \*.la -delete

cd /sources
tar xf lfs-bootscripts-20180820.tar.bz2
pushd lfs-bootscripts-20180820
make install
popd

bash /lib/udev/init-net-rules.sh
cat /etc/udev/rules.d/70-persistent-net.rules # network device name, enp2s0

pushd /etc/sysconfig/
cat > ifconfig.enp2s0 << "EOF"
ONBOOT=yes
IFACE=enp2s0
SERVICE=ipv4-static
IP=192.168.1.45
GATEWAY=192.168.1.1
PREFIX=24
BROADCAST=192.168.1.255
EOF
popd

cat > /etc/resolv.conf << "EOF"
# Generated by NetworkManager
nameserver 202.101.172.35
nameserver 223.5.5.5
EOF

echo 'mylfs' > /etc/hostname

cat > /etc/hosts << "EOF"
127.0.0.1	localhost
::1 localhost
127.0.1.1	mylfs.localdomain	mylfs
EOF

cat > /etc/inittab << "EOF"
# Begin /etc/inittab

id:3:initdefault:

si::sysinit:/etc/rc.d/init.d/rc S

l0:0:wait:/etc/rc.d/init.d/rc 0
l1:S1:wait:/etc/rc.d/init.d/rc 1
l2:2:wait:/etc/rc.d/init.d/rc 2
l3:3:wait:/etc/rc.d/init.d/rc 3
l4:4:wait:/etc/rc.d/init.d/rc 4
l5:5:wait:/etc/rc.d/init.d/rc 5
l6:6:wait:/etc/rc.d/init.d/rc 6

ca:12345:ctrlaltdel:/sbin/shutdown -t1 -a -r now

su:S016:once:/sbin/sulogin

1:2345:respawn:/sbin/agetty --noclear tty1 9600
2:2345:respawn:/sbin/agetty tty2 9600
3:2345:respawn:/sbin/agetty tty3 9600
4:2345:respawn:/sbin/agetty tty4 9600
5:2345:respawn:/sbin/agetty tty5 9600
6:2345:respawn:/sbin/agetty tty6 9600

# End /etc/inittab
EOF

cat > /etc/sysconfig/clock << "EOF"
# Begin /etc/sysconfig/clock

UTC=1

# Set this to any options you might need to give to hwclock,
# such as machine hardware clock type for Alphas.
CLOCKPARAMS=

# End /etc/sysconfig/clock
EOF

cat > /etc/sysconfig/console << "EOF"
# Begin /etc/sysconfig/console

KEYMAP="uk"
FONT="lat1-16 -m 8859-1"

# End /etc/sysconfig/console
EOF

cat > /etc/profile << "EOF"
# Begin /etc/profile

# export LANG=<ll>_<CC>.<charmap><@modifiers> translates to:

export LANG=en_US.utf8

# End /etc/profile
EOF

cat > /etc/inputrc << "EOF"
# Begin /etc/inputrc
# Modified by Chris Lynn <roryo@roryo.dynup.net>

# Allow the command prompt to wrap to the next line
set horizontal-scroll-mode Off

# Enable 8bit input
set meta-flag On
set input-meta On

# Turns off 8th bit stripping
set convert-meta Off

# Keep the 8th bit for display
set output-meta On

# none, visible or audible
set bell-style none

# All of the following map the escape sequence of the value
# contained in the 1st argument to the readline specific functions
"\eOd": backward-word
"\eOc": forward-word

# for linux console
"\e[1~": beginning-of-line
"\e[4~": end-of-line
"\e[5~": beginning-of-history
"\e[6~": end-of-history
"\e[3~": delete-char
"\e[2~": quoted-insert

# for xterm
"\eOH": beginning-of-line
"\eOF": end-of-line

# for Konsole
"\e[H": beginning-of-line
"\e[F": end-of-line

# End /etc/inputrc
EOF

cat > /etc/shells << "EOF"
# Begin /etc/shells

/bin/sh
/bin/bash

# End /etc/shells
EOF

# change the partition
cat > /etc/fstab << "EOF"
# Begin /etc/fstab

# file system  mount-point  type     options             dump  fsck
#                                                              order

/dev/sda2      /            ext4     defaults            1     1
proc           /proc        proc     nosuid,noexec,nodev 0     0
sysfs          /sys         sysfs    nosuid,noexec,nodev 0     0
devpts         /dev/pts     devpts   gid=5,mode=620      0     0
tmpfs          /run         tmpfs    defaults            0     0
devtmpfs       /dev         devtmpfs mode=0755,nosuid    0     0

# End /etc/fstab
EOF

cd /sources
pushd linux-4.20.12
make mrproper
make defconfig

# uncheck 'device drivers--generic driver option--support for uevent'
# check   'device drivers--generic driver option--maintain a devtmpfs'
# chek for efi 'processor type and features--efi stub support'
# change  'kernel hacking--choose kernel unwinder(frame pointer unwinder)'
make menuconfig
make -j$(nproc)
make modules_install

cp -iv arch/x86/boot/bzImage /boot/vmlinuz-4.20.12-lfs-8.4
cp -iv System.map /boot/System.map-4.20.12
cp -iv .config /boot/config-4.20.12
install -d /usr/share/doc/linux-4.20.12
cp -r Documentation/* /usr/share/doc/linux-4.20.12

popd

echo 8.4 > /etc/lfs-release
cat > /etc/lsb-release << "EOF"
DISTRIB_ID="Linux From Scratch"
DISTRIB_RELEASE="8.4"
DISTRIB_CODENAME="mylfs"
DISTRIB_DESCRIPTION="Linux From Scratch"
EOF

# run in archlinux normal user
sudo os-prober  # output:Linux From Scratch (8.4)
sudo grub-mkconfig -o /boot/grub/grub.cfg # if not find in above command, it will not appear in grub

exit 0
# grub.cfg,generate by os-prober in archlinux, lsblk -fs, find the partition uuid

menuentry 'Linux From Scratch (8.4) (on /dev/sda2)' --class linuxfromscratch --class gnu-linux --class gnu --class os $menuentry_id_option 'osprober-gnulinux-simple-6bca68fb-1855-4135-9a6e-fbe942dc1586' {
        insmod part_msdos
        insmod ext2
        set root='hd0,msdos2'
        if [ x$feature_platform_search_hint = xy ]; then
          search --no-floppy --fs-uuid --set=root --hint-ieee1275='ieee1275//disk@0,msdos2' --hint-bios=hd0,msdos2 --hint-efi=hd0,msdos2 --hint-baremetal=ahci0,msdos2  6bca68fb-1855-4135-9a6e-fbe942dc1586
        else
          search --no-floppy --fs-uuid --set=root 6bca68fb-1855-4135-9a6e-fbe942dc1586
        fi
        linux /boot/vmlinuz-4.20.12-lfs-8.4 root=/dev/sda2
}
submenu 'Advanced options for Linux From Scratch (8.4) (on /dev/sda2)' $menuentry_id_option 'osprober-gnulinux-advanced-6bca68fb-1855-4135-9a6e-fbe942dc1586' {
        menuentry 'Linux From Scratch (8.4) (on /dev/sda2)' --class gnu-linux --class gnu --class os $menuentry_id_option 'osprober-gnulinux-/boot/vmlinuz-4.20.12-lfs-8.4--6bca68fb-1855-4135-9a6e-fbe942dc1586' {
                insmod part_msdos
                insmod ext2
                set root='hd0,msdos2'
                if [ x$feature_platform_search_hint = xy ]; then
                  search --no-floppy --fs-uuid --set=root --hint-ieee1275='ieee1275//disk@0,msdos2' --hint-bios=hd0,msdos2 --hint-efi=hd0,msdos2 --hint-baremetal=ahci0,msdos2  6bca68fb-1855-4135-9a6e-fbe942dc1586
                else
                  search --no-floppy --fs-uuid --set=root 6bca68fb-1855-4135-9a6e-fbe942dc1586
                fi
                linux /boot/vmlinuz-4.20.12-lfs-8.4 root=/dev/sda2
        }
}
