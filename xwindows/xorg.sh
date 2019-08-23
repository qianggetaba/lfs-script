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