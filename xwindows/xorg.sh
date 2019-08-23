#!/bin/bash -e

continue(){
read -p "$1 continue?(n for stop):" yn
case $yn in
    [Nn]* ) exit;;
esac
}

check_status(){
    if grep -q $1 "$statusFile"; then
        echo "$2"
    else
        time $1
    fi
}

enter_pkg(){
    tarball=$1
    rootfolder=`tar tf  $tarball |head -1|sed -e 's@/.*@@' | uniq`
    rm -rf $rootfolder
    tar xf $tarball
    pushd $rootfolder
}

exit_pkg(){
    unset tarball
    unset rootfolder
    popd

    tail -1 $statusFile
}

cd /sources

mkdir xc
cd xc


export XORG_PREFIX=/usr
export XORG_CONFIG="--prefix=$XORG_PREFIX --sysconfdir=/etc \
    --localstatedir=/var --disable-static"

xorg_prepare(){
cat > /etc/profile.d/xorg.sh << EOF
XORG_PREFIX="$XORG_PREFIX"
XORG_CONFIG="--prefix=\$XORG_PREFIX --sysconfdir=/etc --localstatedir=/var --disable-static"
export XORG_PREFIX XORG_CONFIG
EOF
chmod 644 /etc/profile.d/xorg.sh
}

pkg=prepare
continue $pkg
check_status xorg_$pkg "skip $pkg"

xorg_utilmacros(){
enter_pkg util-macros-1.19.2.tar.bz2

./configure $XORG_CONFIG
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}
pkg=utilmacros
continue $pkg
check_status xorg_$pkg "skip $pkg"

xorg_xorgproto(){
enter_pkg xorgproto-2018.4.tar.bz2

mkdir build &&
cd    build &&

meson --prefix=$XORG_PREFIX .. &&
ninja

ninja install &&

install -vdm 755 $XORG_PREFIX/share/doc/xorgproto-2018.4 &&
install -vm 644 ../[^m]*.txt ../PM_spec $XORG_PREFIX/share/doc/xorgproto-2018.4

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}
pkg=xorgproto
continue $pkg
check_status xorg_$pkg "skip $pkg"

xorg_libxau(){
enter_pkg libXau-1.0.9.tar.bz2

./configure $XORG_CONFIG &&
make -j$(nproc)
make install
exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}
pkg=libxau
continue $pkg
check_status xorg_$pkg "skip $pkg"

xorg_libxdmcp(){
enter_pkg libXdmcp-1.1.2.tar.bz2

./configure $XORG_CONFIG
make -j$(nproc)
make install
exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}
pkg=libxdmcp
continue $pkg
check_status xorg_$pkg "skip $pkg"

xorg_xcbproto(){
enter_pkg xcb-proto-1.13.tar.bz2

./configure $XORG_CONFIG
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}
pkg=xcbproto
continue $pkg
check_status xorg_$pkg "skip $pkg"

xorg_libxcb(){
enter_pkg libxcb-1.13.1.tar.bz2

sed -i "s/pthread-stubs//" configure &&

./configure $XORG_CONFIG      \
            --without-doxygen \
            --docdir='${datadir}'/doc/libxcb-1.13.1 &&
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}
pkg=libxcb
continue $pkg
check_status xorg_$pkg "skip $pkg"

xorg_dl_xlib(){
cat > lib-7.md5 << "EOF"
c5ba432dd1514d858053ffe9f4737dd8  xtrans-1.3.5.tar.bz2
034fdd6cc5393974d88aec6f5bc96162  libX11-1.6.7.tar.bz2
52df7c4c1f0badd9f82ab124fb32eb97  libXext-1.3.3.tar.bz2
d79d9fe2aa55eb0f69b1a4351e1368f7  libFS-1.0.7.tar.bz2
addfb1e897ca8079531669c7c7711726  libICE-1.0.9.tar.bz2
87c7fad1c1813517979184c8ccd76628  libSM-1.2.3.tar.bz2
eeea9d5af3e6c143d0ea1721d27a5e49  libXScrnSaver-1.2.3.tar.bz2
8f5b5576fbabba29a05f3ca2226f74d3  libXt-1.1.5.tar.bz2
41d92ab627dfa06568076043f3e089e4  libXmu-1.1.2.tar.bz2
20f4627672edb2bd06a749f11aa97302  libXpm-3.5.12.tar.bz2
e5e06eb14a608b58746bdd1c0bd7b8e3  libXaw-1.0.13.tar.bz2
07e01e046a0215574f36a3aacb148be0  libXfixes-5.0.3.tar.bz2
f7a218dcbf6f0848599c6c36fc65c51a  libXcomposite-0.4.4.tar.bz2
802179a76bded0b658f4e9ec5e1830a4  libXrender-0.9.10.tar.bz2
58fe3514e1e7135cf364101e714d1a14  libXcursor-1.1.15.tar.bz2
0cf292de2a9fa2e9a939aefde68fd34f  libXdamage-1.1.4.tar.bz2
0920924c3a9ebc1265517bdd2f9fde50  libfontenc-1.1.3.tar.bz2
b7ca87dfafeb5205b28a1e91ac3efe85  libXfont2-2.0.3.tar.bz2
331b3a2a3a1a78b5b44cfbd43f86fcfe  libXft-2.3.2.tar.bz2
1f0f2719c020655a60aee334ddd26d67  libXi-1.7.9.tar.bz2
0d5f826a197dae74da67af4a9ef35885  libXinerama-1.1.4.tar.bz2
28e486f1d491b757173dd85ba34ee884  libXrandr-1.5.1.tar.bz2
5d6d443d1abc8e1f6fc1c57fb27729bb  libXres-1.2.0.tar.bz2
ef8c2c1d16a00bd95b9fdcef63b8a2ca  libXtst-1.2.3.tar.bz2
210b6ef30dda2256d54763136faa37b9  libXv-1.0.11.tar.bz2
4cbe1c1def7a5e1b0ed5fce8e512f4c6  libXvMC-1.0.10.tar.bz2
d7dd9b9df336b7dd4028b6b56542ff2c  libXxf86dga-1.1.4.tar.bz2
298b8fff82df17304dfdb5fe4066fe3a  libXxf86vm-1.1.4.tar.bz2
d2f1f0ec68ac3932dd7f1d9aa0a7a11c  libdmx-1.1.4.tar.bz2
8f436e151d5106a9cfaa71857a066d33  libpciaccess-0.14.tar.bz2
4a4cfeaf24dab1b991903455d6d7d404  libxkbfile-1.0.9.tar.bz2
42dda8016943dc12aff2c03a036e0937  libxshmfence-1.3.tar.bz2
EOF
mkdir lib &&
cd lib &&
grep -v '^#' ../lib-7.md5 | awk '{print $2}' | wget -i- -c \
    -B https://www.x.org/pub/individual/lib/ &&
md5sum -c ../lib-7.md5

echo ${FUNCNAME[0]} >>$statusFile  
}
pkg=dl_xlib
continue $pkg
check_status xorg_$pkg "skip $pkg"

xorg_xlib_install(){
pushd lib

for package in $(grep -v '^#' ../lib-7.md5 | awk '{print $2}')
do
  packagedir=${package%.tar.bz2}
  tar -xf $package
  pushd $packagedir
  case $packagedir in
    libICE* )
      ./configure $XORG_CONFIG ICE_LIBS=-lpthread
    ;;

    libXfont2-[0-9]* )
      ./configure $XORG_CONFIG --disable-devel-docs
    ;;

    libXt-[0-9]* )
      ./configure $XORG_CONFIG \
                  --with-appdefaultdir=/etc/X11/app-defaults
    ;;

    * )
      ./configure $XORG_CONFIG
    ;;
  esac
  make
  #make check 2>&1 | tee ../$packagedir-make_check.log
  make install
  popd
  rm -rf $packagedir
  /sbin/ldconfig
done

popd
echo ${FUNCNAME[0]} >>$statusFile  
}
pkg=xlib_install
continue $pkg
check_status xorg_$pkg "skip $pkg"

xorg_xcb_util(){
enter_pkg xcb-util-0.4.0.tar.bz2

./configure $XORG_CONFIG
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}
pkg=xcb_util
continue $pkg
check_status xorg_$pkg "skip $pkg"

xorg_xcb_util_image(){
enter_pkg xcb-util-image-0.4.0.tar.bz2

./configure $XORG_CONFIG
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}
pkg=xcb_util_image
continue $pkg
check_status xorg_$pkg "skip $pkg"

xorg_xcb_util_keysyms(){
enter_pkg xcb-util-keysyms-0.4.0.tar.bz2

./configure $XORG_CONFIG
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}
pkg=xcb_util_keysyms
continue $pkg
check_status xorg_$pkg "skip $pkg"

xorg_xcb_util_renderutil(){
enter_pkg xcb-util-renderutil-0.3.9.tar.bz2

./configure $XORG_CONFIG
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}
pkg=xcb_util_renderutil
continue $pkg
check_status xorg_$pkg "skip $pkg"

xorg_xcb_util_wm(){
enter_pkg xcb-util-wm-0.4.1.tar.bz2

./configure $XORG_CONFIG
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}
pkg=xcb_util_wm
continue $pkg
check_status xorg_$pkg "skip $pkg"

xorg_xcb_util_cursor(){
enter_pkg xcb-util-cursor-0.1.3.tar.bz2

./configure $XORG_CONFIG
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}
pkg=xcb_util_cursor
continue $pkg
check_status xorg_$pkg "skip $pkg"

xorg_mesa(){
enter_pkg mesa-18.3.3.tar.xz

GLL_DRV="i915,nouveau,radeonsi,svga,swrast"
./configure CFLAGS='-O2' CXXFLAGS='-O2' LDFLAGS=-lLLVM \
            --prefix=$XORG_PREFIX              \
            --sysconfdir=/etc                  \
            --enable-osmesa                    \
            --enable-xa                        \
            --enable-glx-tls                   \
            --with-platforms="drm,x11,wayland" \
            --with-gallium-drivers=$GLL_DRV
unset GLL_DRV
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}
pkg=mesa
continue $pkg
check_status xorg_$pkg "skip $pkg"

xorg_xbitmaps(){
enter_pkg xbitmaps-1.1.2.tar.bz2

./configure $XORG_CONFIG
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}
pkg=xbitmaps
continue $pkg
check_status xorg_$pkg "skip $pkg"

xorg_xorg_app(){
cat > app-7.md5 << "EOF"
3b9b79fa0f9928161f4bad94273de7ae  iceauth-1.0.8.tar.bz2
c4a3664e08e5a47c120ff9263ee2f20c  luit-1.1.1.tar.bz2
18c429148c96c2079edda922a2b67632  mkfontdir-1.0.7.tar.bz2
987c438e79f5ddb84a9c5726a1610819  mkfontscale-1.1.3.tar.bz2
e475167a892b589da23edf8edf8c942d  sessreg-1.1.1.tar.bz2
2c47a1b8e268df73963c4eb2316b1a89  setxkbmap-1.3.1.tar.bz2
3a93d9f0859de5d8b65a68a125d48f6a  smproxy-1.0.6.tar.bz2
f0b24e4d8beb622a419e8431e1c03cd7  x11perf-1.6.0.tar.bz2
f3f76cb10f69b571c43893ea6a634aa4  xauth-1.0.10.tar.bz2
d50cf135af04436b9456a5ab7dcf7971  xbacklight-1.2.2.tar.bz2
9956d751ea3ae4538c3ebd07f70736a0  xcmsdb-1.0.5.tar.bz2
25cc7ca1ce5dcbb61c2b471c55e686b5  xcursorgen-1.0.7.tar.bz2
8809037bd48599af55dad81c508b6b39  xdpyinfo-1.3.2.tar.bz2
480e63cd365f03eb2515a6527d5f4ca6  xdriinfo-1.0.6.tar.bz2
249bdde90f01c0d861af52dc8fec379e  xev-1.2.2.tar.bz2
90b4305157c2b966d5180e2ee61262be  xgamma-1.0.6.tar.bz2
f5d490738b148cb7f2fe760f40f92516  xhost-1.0.7.tar.bz2
6a889412eff2e3c1c6bb19146f6fe84c  xinput-1.6.2.tar.bz2
12610df19df2af3797f2c130ee2bce97  xkbcomp-1.4.2.tar.bz2
c747faf1f78f5a5962419f8bdd066501  xkbevd-1.1.4.tar.bz2
502b14843f610af977dffc6cbf2102d5  xkbutils-1.0.4.tar.bz2
938177e4472c346cf031c1aefd8934fc  xkill-1.0.5.tar.bz2
5dcb6e6c4b28c8d7aeb45257f5a72a7d  xlsatoms-1.1.2.tar.bz2
4fa92377e0ddc137cd226a7a87b6b29a  xlsclients-1.1.4.tar.bz2
e50ffae17eeb3943079620cb78f5ce0b  xmessage-1.0.5.tar.bz2
723f02d3a5f98450554556205f0a9497  xmodmap-1.0.9.tar.bz2
eaac255076ea351fd08d76025788d9f9  xpr-1.0.5.tar.bz2
4becb3ddc4674d741487189e4ce3d0b6  xprop-1.2.3.tar.bz2
ebffac98021b8f1dc71da0c1918e9b57  xrandr-1.5.0.tar.bz2
96f9423eab4d0641c70848d665737d2e  xrdb-1.1.1.tar.bz2
c56fa4adbeed1ee5173f464a4c4a61a6  xrefresh-1.0.6.tar.bz2
70ea7bc7bacf1a124b1692605883f620  xset-1.2.4.tar.bz2
5fe769c8777a6e873ed1305e4ce2c353  xsetroot-1.1.2.tar.bz2
558360176b718dee3c39bc0648c0d10c  xvinfo-1.1.3.tar.bz2
11794a8eba6d295a192a8975287fd947  xwd-1.0.7.tar.bz2
9a505b91ae7160bbdec360968d060c83  xwininfo-1.1.4.tar.bz2
79972093bb0766fcd0223b2bd6d11932  xwud-1.0.5.tar.bz2
EOF
mkdir app &&
cd app &&
grep -v '^#' ../app-7.md5 | awk '{print $2}' | wget -i- -c \
    -B https://www.x.org/pub/individual/app/ &&
md5sum -c ../app-7.md5

for package in $(grep -v '^#' ../app-7.md5 | awk '{print $2}')
do
  packagedir=${package%.tar.bz2}
  tar -xf $package
  pushd $packagedir
     case $packagedir in
       luit-[0-9]* )
         sed -i -e "/D_XOPEN/s/5/6/" configure
       ;;
     esac

     ./configure $XORG_CONFIG
     make
     as_root make install
  popd
  rm -rf $packagedir
done

echo ${FUNCNAME[0]} >>$statusFile  
}
pkg=xorg_app
continue $pkg
check_status xorg_$pkg "skip $pkg"

xorg_xcursor_theme(){
enter_pkg xcursor-themes-1.0.6.tar.bz2

./configure $XORG_CONFIG
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}
pkg=xcursor_theme
continue $pkg
check_status xorg_$pkg "skip $pkg"

xorg_xorg_font(){
cat > font-7.md5 << "EOF"
23756dab809f9ec5011bb27fb2c3c7d6  font-util-1.3.1.tar.bz2
0f2d6546d514c5cc4ecf78a60657a5c1  encodings-1.0.4.tar.bz2
6d25f64796fef34b53b439c2e9efa562  font-alias-1.0.3.tar.bz2
fcf24554c348df3c689b91596d7f9971  font-adobe-utopia-type1-1.0.4.tar.bz2
e8ca58ea0d3726b94fe9f2c17344be60  font-bh-ttf-1.0.3.tar.bz2
53ed9a42388b7ebb689bdfc374f96a22  font-bh-type1-1.0.3.tar.bz2
bfb2593d2102585f45daa960f43cb3c4  font-ibm-type1-1.0.3.tar.bz2
6306c808f7d7e7d660dfb3859f9091d2  font-misc-ethiopic-1.0.3.tar.bz2
3eeb3fb44690b477d510bbd8f86cf5aa  font-xfree86-type1-1.0.4.tar.bz2
EOF
mkdir font &&
cd font &&
grep -v '^#' ../font-7.md5 | awk '{print $2}' | wget -i- -c \
    -B https://www.x.org/pub/individual/font/ &&
md5sum -c ../font-7.md5

for package in $(grep -v '^#' ../font-7.md5 | awk '{print $2}')
do
  packagedir=${package%.tar.bz2}
  tar -xf $package
  pushd $packagedir
    ./configure $XORG_CONFIG
    make
    as_root make install
  popd
  as_root rm -rf $packagedir
done

install -v -d -m755 /usr/share/fonts
ln -svfn $XORG_PREFIX/share/fonts/X11/OTF /usr/share/fonts/X11-OTF
ln -svfn $XORG_PREFIX/share/fonts/X11/TTF /usr/share/fonts/X11-TTF

echo ${FUNCNAME[0]} >>$statusFile  
}
pkg=xorg_font
continue $pkg
check_status xorg_$pkg "skip $pkg"

xorg_xkeyboardconfig(){
enter_pkg xkeyboard-config-2.26.tar.bz2

./configure $XORG_CONFIG --with-xkb-rules-symlink=xorg
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}
pkg=xkeyboardconfig
continue $pkg
check_status xorg_$pkg "skip $pkg"

xorg_xorg_server(){
enter_pkg xorg-server-1.20.3.tar.bz2

./configure $XORG_CONFIG            \
           --enable-glamor          \
           --enable-install-setuid  \
           --enable-suid-wrapper    \
           --disable-systemd-logind \
           --with-xkb-output=/var/lib/xkb
make -j$(nproc)
make install
mkdir -pv /etc/X11/xorg.conf.d
cat >> /etc/sysconfig/createfiles << "EOF"
/tmp/.ICE-unix dir 1777 root root
/tmp/.X11-unix dir 1777 root root
EOF

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}
pkg=xorg_server
continue $pkg
check_status xorg_$pkg "skip $pkg"

xorg_xorg_input(){
enter_pkg libevdev-1.6.0.tar.xz
./configure $XORG_CONFIG
make -j$(nproc)
make install
exit_pkg

enter_pkg xf86-input-evdev-2.10.6.tar.bz2
./configure $XORG_CONFIG
make -j$(nproc)
make install
exit_pkg

enter_pkg libinput-1.12.6.tar.xz
mkdir build &&
cd    build &&

meson --prefix=$XORG_PREFIX \
      -Dudev-dir=/lib/udev  \
      -Ddebug-gui=false     \
      -Dtests=false         \
      -Ddocumentation=false \
      -Dlibwacom=false      \
      ..                    &&
ninja
ninja install
exit_pkg

enter_pkg xf86-input-libinput-0.28.2.tar.bz2
./configure $XORG_CONFIG
make -j$(nproc)
make install
exit_pkg

echo ${FUNCNAME[0]} >>$statusFile  
}
pkg=xorg_input
continue $pkg
check_status xorg_$pkg "skip $pkg"

xorg_xorg_video(){
enter_pkg xf86-video-fbdev-0.5.0.tar.bz2

./configure $XORG_CONFIG
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}
pkg=xorg_video
continue $pkg
check_status xorg_$pkg "skip $pkg"

xorg_twm(){
enter_pkg twm-1.0.10.tar.bz2

sed -i -e '/^rcdir =/s,^\(rcdir = \).*,\1/etc/X11/app-defaults,' src/Makefile.in
./configure $XORG_CONFIG
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}
pkg=twm
continue $pkg
check_status xorg_$pkg "skip $pkg"

xorg_xterm(){
enter_pkg xterm-344.tgz

sed -i '/v0/{n;s/new:/new:kb=^?:/}' termcap
printf '\tkbs=\\177,\n' >> terminfo

TERMINFO=/usr/share/terminfo \
./configure $XORG_CONFIG     \
    --with-app-defaults=/etc/X11/app-defaults
./configure $XORG_CONFIG
make -j$(nproc)
make install
make install-ti

mkdir -pv /usr/share/applications
cp -v *.desktop /usr/share/applications/

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}
pkg=xterm
continue $pkg
check_status xorg_$pkg "skip $pkg"

xorg_xclock(){
enter_pkg xclock-1.0.7.tar.bz2

./configure $XORG_CONFIG
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}
pkg=xclock
continue $pkg
check_status xorg_$pkg "skip $pkg"

xorg_xinit(){
enter_pkg xinit-1.4.0.tar.bz2

sed -e '/$serverargs $vtarg/ s/serverargs/: #&/' \
    -i startx.cpp
./configure $XORG_CONFIG --with-xinitdir=/etc/X11/app-defaults
make -j$(nproc)
make install
ldconfig

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}
pkg=xinit
continue $pkg
check_status xorg_$pkg "skip $pkg"