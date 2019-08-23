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

