#!/bin/bash -e

if [ "$(whoami)" != "root" ]; then
        echo "Script must be run as user: root"
        exit -1
fi

statusFile=status.done


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

inchroot_prepare(){
touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664  /var/log/lastlog
chmod -v 600  /var/log/btmp

echo ${FUNCNAME[0]} >>$statusFile
}

inchroot_header(){
    pushd linux-4.20.12

make mrproper
make INSTALL_HDR_PATH=dest headers_install
find dest/include \( -name .install -o -name ..install.cmd \) -delete
cp -rv dest/include/* /usr/include

popd

echo ${FUNCNAME[0]} >>$statusFile
}

inchroot_man_pages(){
    enter_pkg man-pages-4.16.tar.xz

    make install

    exit_pkg
echo ${FUNCNAME[0]} >>$statusFile
}

inchroot_glibc(){
    enter_pkg glibc-2.29.tar.xz

patch -Np1 -i ../glibc-2.29-fhs-1.patch
ln -sfv /tools/lib/gcc /usr/lib

case $(uname -m) in
    i?86)    GCC_INCDIR=/usr/lib/gcc/$(uname -m)-pc-linux-gnu/8.2.0/include
            ln -sfv ld-linux.so.2 /lib/ld-lsb.so.3
    ;;
    x86_64) GCC_INCDIR=/usr/lib/gcc/x86_64-pc-linux-gnu/8.2.0/include
            ln -sfv ../lib/ld-linux-x86-64.so.2 /lib64
            ln -sfv ../lib/ld-linux-x86-64.so.2 /lib64/ld-lsb-x86-64.so.3
    ;;
esac

rm -f /usr/include/limits.h

mkdir -v build
cd       build

CC="gcc -isystem $GCC_INCDIR -isystem /usr/include" \
../configure --prefix=/usr                          \
             --disable-werror                       \
             --enable-kernel=3.2                    \
             --enable-stack-protector=strong        \
             libc_cv_slibdir=/lib
unset GCC_INCDIR
make -j$(nproc)

case $(uname -m) in
  i?86)   ln -sfnv $PWD/elf/ld-linux.so.2        /lib ;;
  x86_64) ln -sfnv $PWD/elf/ld-linux-x86-64.so.2 /lib ;;
esac

# make check

touch /etc/ld.so.conf
sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
make install
cp -v ../nscd/nscd.conf /etc/nscd.conf
mkdir -pv /var/cache/nscd

mkdir -pv /usr/lib/locale
localedef -i POSIX -f UTF-8 C.UTF-8 2> /dev/null || true
localedef -i en_US -f UTF-8 en_US.UTF-8
localedef -i zh_CN -f GB18030 zh_CN.GB18030

make localedata/install-locales

cat > /etc/nsswitch.conf << "EOF"
# Begin /etc/nsswitch.conf

passwd: files
group: files
shadow: files

hosts: files dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOF

tar -xf ../../tzdata2018i.tar.gz

ZONEINFO=/usr/share/zoneinfo
mkdir -pv $ZONEINFO/{posix,right}

for tz in etcetera southamerica northamerica europe africa antarctica  \
          asia australasia backward pacificnew systemv; do
    zic -L /dev/null   -d $ZONEINFO       ${tz}
    zic -L /dev/null   -d $ZONEINFO/posix ${tz}
    zic -L leapseconds -d $ZONEINFO/right ${tz}
done

cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
zic -d $ZONEINFO -p America/New_York
unset ZONEINFO

cp -v /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib

EOF

cat >> /etc/ld.so.conf << "EOF"
# Add an include directory
include /etc/ld.so.conf.d/*.conf

EOF
mkdir -pv /etc/ld.so.conf.d

    exit_pkg
echo ${FUNCNAME[0]} >>$statusFile
}

inchroot_adjust(){
    mv -v /tools/bin/{ld,ld-old}
mv -v /tools/$(uname -m)-pc-linux-gnu/bin/{ld,ld-old}
mv -v /tools/bin/{ld-new,ld}
ln -sv /tools/bin/ld /tools/$(uname -m)-pc-linux-gnu/bin/ld

gcc -dumpspecs |head -1|sed -e 's@/tools@@g'                   \
    -e '/\*startfile_prefix_spec:/{n;s@.*@/usr/lib/ @}' \
    -e '/\*cpp:/{n;s@$@ -isystem /usr/include@}' >      \
    `dirname $(gcc --print-libgcc-file-name)`/specs

# output:[Requesting program interpreter: /lib64/ld-linux-x86-64.so.2]
echo 'int main(){}' > dummy.c
cc dummy.c -v -Wl,--verbose &> dummy.log
readelf -l a.out | grep ': /lib'

grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log
echo 'should output:/usr/lib/../lib/crt1.o succeeded'
continue 'check output'

grep -B1 '^ /usr/include' dummy.log
echo 'should output:/usr/include'
continue 'check output'

grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'
echo 'should output:SEARCH_DIR("/usr/lib")'
continue 'check output'

grep "/lib.*/libc.so.6 " dummy.log
echo 'should output:attempt to open /lib/libc.so.6 succeeded'
continue 'check output'

grep found dummy.log
echo 'should output:found ld-linux-x86-64.so.2 at /lib/ld-linux-x86-64.so.2'
continue 'check output'

rm -v dummy.c a.out dummy.log

echo ${FUNCNAME[0]} >>$statusFile
}

inchroot_zlib(){
    enter_pkg zlib-1.2.11.tar.xz

./configure --prefix=/usr
make -j$(nproc)
make check
make install

mv -v /usr/lib/libz.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libz.so) /usr/lib/libz.so


    exit_pkg
echo ${FUNCNAME[0]} >>$statusFile
}

inchroot_file(){
    enter_pkg file-5.36.tar.gz

./configure --prefix=/usr
make -j$(nproc)
make check
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

inchroot_readline(){
    enter_pkg readline-8.0.tar.gz

sed -i '/MV.*old/d' Makefile.in
sed -i '/{OLDSUFF}/c:' support/shlib-install
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/readline-8.0
make SHLIB_LIBS="-L/tools/lib -lncursesw"
make SHLIB_LIBS="-L/tools/lib -lncursesw" install

mv -v /usr/lib/lib{readline,history}.so.* /lib
chmod -v u+w /lib/lib{readline,history}.so.*
ln -sfv ../../lib/$(readlink /usr/lib/libreadline.so) /usr/lib/libreadline.so
ln -sfv ../../lib/$(readlink /usr/lib/libhistory.so ) /usr/lib/libhistory.so

install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/readline-8.0

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

inchroot_m4(){
    enter_pkg m4-1.4.18.tar.xz

sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c
echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h
./configure --prefix=/usr
make -j$(nproc)
make check
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

inchroot_bc(){
    enter_pkg bc-1.07.1.tar.gz

cat > bc/fix-libmath_h << "EOF"
#! /bin/bash
sed -e '1   s/^/{"/' \
    -e     's/$/",/' \
    -e '2,$ s/^/"/'  \
    -e   '$ d'       \
    -i libmath.h

sed -e '$ s/$/0}/' \
    -i libmath.h
EOF

ln -sv /tools/lib/libncursesw.so.6 /usr/lib/libncursesw.so.6
ln -sfv libncursesw.so.6 /usr/lib/libncurses.so

sed -i -e '/flex/s/as_fn_error/: ;; # &/' configure

./configure --prefix=/usr           \
            --with-readline         \
            --mandir=/usr/share/man \
            --infodir=/usr/share/info
make -j$(nproc)
echo "quit" | ./bc/bc -l Test/checklib.b
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

inchroot_binutils(){
    expect -c "spawn ls"
    echo 'output:spawn ls'
    continue 'check output'

    enter_pkg binutils-2.32.tar.xz

mkdir -v build
cd       build
../configure --prefix=/usr       \
             --enable-gold       \
             --enable-ld=default \
             --enable-plugins    \
             --enable-shared     \
             --disable-werror    \
             --enable-64-bit-bfd \
             --with-system-zlib
make -j$(nproc) tooldir=/usr
make -k check
make tooldir=/usr install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

inchroot_gmp(){
    enter_pkg gmp-6.1.2.tar.xz

./configure --prefix=/usr    \
            --enable-cxx     \
            --disable-static \
            --docdir=/usr/share/doc/gmp-6.1.2
make -j$(nproc)
make html
make check 2>&1 | tee gmp-check-log
awk '/# PASS:/{total+=$3} ; END{print total}' gmp-check-log
make install
make install-html

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

inchroot_mpfr(){
    enter_pkg mpfr-4.0.2.tar.xz

./configure --prefix=/usr        \
            --disable-static     \
            --enable-thread-safe \
            --docdir=/usr/share/doc/mpfr-4.0.2
make -j$(nproc)
make html
make check
make install
make install-html

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

inchroot_mpc(){
    enter_pkg mpc-1.1.0.tar.gz

./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/mpc-1.1.0
make -j$(nproc)
make html
make check
make install
make install-html

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

inchroot_shadow(){
    enter_pkg shadow-4.6.tar.xz

sed -i 's/groups$(EXEEXT) //' src/Makefile.in
find man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \;
find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;

sed -i -e 's@#ENCRYPT_METHOD DES@ENCRYPT_METHOD SHA512@' \
       -e 's@/var/spool/mail@/var/mail@' etc/login.defs
sed -i 's/1000/999/' etc/useradd
./configure --sysconfdir=/etc --with-group-name-max-length=32
make -j$(nproc)
make install
mv -v /usr/bin/passwd /bin

pwconv
grpconv
passwd root

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

inchroot_gcc(){
    enter_pkg gcc-8.2.0.tar.xz

case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
  ;;
esac

rm -f /usr/lib/gcc

mkdir -v build
cd       build
SED=sed                               \
../configure --prefix=/usr            \
             --enable-languages=c,c++ \
             --disable-multilib       \
             --disable-bootstrap      \
             --disable-libmpx         \
             --with-system-zlib
make -j$(nproc)
ulimit -s 32768
rm ../gcc/testsuite/g++.dg/pr83239.C
chown -Rv nobody . 
su nobody -s /bin/bash -c "PATH=$PATH make -k check"
../contrib/test_summary
make install
ln -sv ../usr/bin/cpp /lib
ln -sv gcc /usr/bin/cc
install -v -dm755 /usr/lib/bfd-plugins
ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/8.2.0/liblto_plugin.so \
        /usr/lib/bfd-plugins/

echo 'int main(){}' > dummy.c
cc dummy.c -v -Wl,--verbose &> dummy.log
readelf -l a.out | grep ': /lib'
echo 'output:[Requesting program interpreter: /lib64/ld-linux-x86-64.so.2]'
continue 'check output'

grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log
grep -B4 '^ /usr/include' dummy.log
grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'
grep "/lib.*/libc.so.6 " dummy.log
grep found dummy.log
continue 'check output'
rm -v dummy.c a.out dummy.log

mkdir -pv /usr/share/gdb/auto-load/usr/lib
mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

cd /sources

pkg=prepare
continue $pkg
check_status inchroot_$pkg "skip $pkg"

pkg=header
continue $pkg
check_status inchroot_$pkg "skip $pkg"

pkg=man_pages
continue $pkg
check_status inchroot_$pkg "skip $pkg"

pkg=glibc
continue $pkg
check_status inchroot_$pkg "skip $pkg"

pkg=adjust
continue $pkg
check_status inchroot_$pkg "skip $pkg"

pkg=zlib
continue $pkg
check_status inchroot_$pkg "skip $pkg"

pkg=file
continue $pkg
check_status inchroot_$pkg "skip $pkg"

pkg=readline
continue $pkg
check_status inchroot_$pkg "skip $pkg"

pkg=m4
continue $pkg
check_status inchroot_$pkg "skip $pkg"

pkg=bc
continue $pkg
check_status inchroot_$pkg "skip $pkg"

pkg=binutils
continue $pkg
check_status inchroot_$pkg "skip $pkg"

pkg=gmp
continue $pkg
check_status inchroot_$pkg "skip $pkg"

pkg=mpfr
continue $pkg
check_status inchroot_$pkg "skip $pkg"

pkg=mpc
continue $pkg
check_status inchroot_$pkg "skip $pkg"

pkg=shadow
continue $pkg
check_status inchroot_$pkg "skip $pkg"

pkg=gcc
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_bzip2(){
    enter_pkg bzip2-1.0.6.tar.gz

patch -Np1 -i ../bzip2-1.0.6-install_docs-1.patch
sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
make -f Makefile-libbz2_so
make clean
make -j$(nproc)
make PREFIX=/usr install

cp -v bzip2-shared /bin/bzip2
cp -av libbz2.so* /lib
ln -sv ../../lib/libbz2.so.1.0 /usr/lib/libbz2.so
rm -v /usr/bin/{bunzip2,bzcat,bzip2}
ln -sv bzip2 /bin/bunzip2
ln -sv bzip2 /bin/bzcat

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=bzip2
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_pkgconfig(){
    enter_pkg pkg-config-0.29.2.tar.gz

./configure --prefix=/usr              \
            --with-internal-glib       \
            --disable-host-tool        \
            --docdir=/usr/share/doc/pkg-config-0.29.2
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=pkgconfig
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_ncurses(){
    enter_pkg ncurses-6.1.tar.gz

sed -i '/LIBTOOL_INSTALL/d' c++/Makefile.in
./configure --prefix=/usr           \
            --mandir=/usr/share/man \
            --with-shared           \
            --without-debug         \
            --without-normal        \
            --enable-pc-files       \
            --enable-widec
make -j$(nproc)
make install

mv -v /usr/lib/libncursesw.so.6* /lib

ln -sfv ../../lib/$(readlink /usr/lib/libncursesw.so) /usr/lib/libncursesw.so

for lib in ncurses form panel menu ; do
    rm -vf                    /usr/lib/lib${lib}.so
    echo "INPUT(-l${lib}w)" > /usr/lib/lib${lib}.so
    ln -sfv ${lib}w.pc        /usr/lib/pkgconfig/${lib}.pc
done

rm -vf                     /usr/lib/libcursesw.so
echo "INPUT(-lncursesw)" > /usr/lib/libcursesw.so
ln -sfv libncurses.so      /usr/lib/libcurses.so

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=ncurses
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_attr(){
    enter_pkg attr-2.4.48.tar.gz
./configure --prefix=/usr     \
            --bindir=/bin     \
            --disable-static  \
            --sysconfdir=/etc \
            --docdir=/usr/share/doc/attr-2.4.48
make -j$(nproc)
make install

mv -v /usr/lib/libattr.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libattr.so) /usr/lib/libattr.so

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=attr
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_acl(){
    enter_pkg acl-2.2.53.tar.gz
./configure --prefix=/usr         \
            --bindir=/bin         \
            --disable-static      \
            --libexecdir=/usr/lib \
            --docdir=/usr/share/doc/acl-2.2.53
make -j$(nproc)
make install

mv -v /usr/lib/libacl.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libacl.so) /usr/lib/libacl.so

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=acl
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_libcap(){
    enter_pkg libcap-2.26.tar.xz
sed -i '/install.*STALIBNAME/d' libcap/Makefile
make -j$(nproc)
make RAISE_SETFCAP=no lib=lib prefix=/usr install
chmod -v 755 /usr/lib/libcap.so.2.26

mv -v /usr/lib/libcap.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libcap.so) /usr/lib/libcap.so

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=libcap
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_sed(){
    enter_pkg sed-4.7.tar.xz
sed -i 's/usr/tools/'                 build-aux/help2man
sed -i 's/testsuite.panic-tests.sh//' Makefile.in
./configure --prefix=/usr --bindir=/bin
make -j$(nproc)
make html
make install
install -d -m755           /usr/share/doc/sed-4.7
install -m644 doc/sed.html /usr/share/doc/sed-4.7

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=sed
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_psmisc(){
    enter_pkg psmisc-23.2.tar.xz
./configure --prefix=/usr
make -j$(nproc)
make install

mv -v /usr/bin/fuser   /bin
mv -v /usr/bin/killall /bin

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=psmisc
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_iana(){
    enter_pkg iana-etc-2.30.tar.bz2

make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=iana
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_bison(){
    enter_pkg bison-3.3.2.tar.xz
./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.3.2
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=bison
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_flex(){
    enter_pkg flex-2.6.4.tar.gz
sed -i "/math.h/a #include <malloc.h>" src/flexdef.h
HELP2MAN=/tools/bin/true \
./configure --prefix=/usr --docdir=/usr/share/doc/flex-2.6.4
make -j$(nproc)
make install
ln -sv flex /usr/bin/lex
exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=flex
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_grep(){
    enter_pkg grep-3.3.tar.xz
./configure --prefix=/usr --bindir=/bin
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=grep
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_bash(){
    enter_pkg bash-5.0.tar.gz
./configure --prefix=/usr                    \
            --docdir=/usr/share/doc/bash-5.0 \
            --without-bash-malloc            \
            --with-installed-readline
make -j$(nproc)
make install
mv -vf /usr/bin/bash /bin
exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=bash
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_libtool(){
    enter_pkg libtool-2.4.6.tar.xz
./configure --prefix=/usr
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=libtool
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_gdbm(){
    enter_pkg gdbm-1.18.1.tar.gz
./configure --prefix=/usr    \
            --disable-static \
            --enable-libgdbm-compat
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=gdbm
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_gperf(){
    enter_pkg gperf-3.1.tar.gz
./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.1
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=gperf
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_expat(){
    enter_pkg expat-2.2.6.tar.bz2
sed -i 's|usr/bin/env |bin/|' run.sh.in
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/expat-2.2.6
make -j$(nproc)
make install
install -v -m644 doc/*.{html,png,css} /usr/share/doc/expat-2.2.6
exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=expat
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_inetutils(){
    enter_pkg inetutils-1.9.4.tar.xz
./configure --prefix=/usr        \
            --localstatedir=/var \
            --disable-logger     \
            --disable-whois      \
            --disable-rcp        \
            --disable-rexec      \
            --disable-rlogin     \
            --disable-rsh        \
            --disable-servers
make -j$(nproc)
make install
mv -v /usr/bin/{hostname,ping,ping6,traceroute} /bin
mv -v /usr/bin/ifconfig /sbin
exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=inetutils
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_perl(){
    enter_pkg perl-5.28.1.tar.xz
echo "127.0.0.1 localhost $(hostname)" > /etc/hosts
export BUILD_ZLIB=False
export BUILD_BZIP2=0
sh Configure -des -Dprefix=/usr                 \
                  -Dvendorprefix=/usr           \
                  -Dman1dir=/usr/share/man/man1 \
                  -Dman3dir=/usr/share/man/man3 \
                  -Dpager="/usr/bin/less -isR"  \
                  -Duseshrplib                  \
                  -Dusethreads
make -j$(nproc)
make install
unset BUILD_ZLIB BUILD_BZIP2
exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=perl
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_xmlparser(){
    enter_pkg XML-Parser-2.44.tar.gz
perl Makefile.PL
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=xmlparser
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_inetltool(){
    enter_pkg intltool-0.51.0.tar.gz
sed -i 's:\\\${:\\\$\\{:' intltool-update.in
./configure --prefix=/usr
make -j$(nproc)
make install
install -v -Dm644 doc/I18N-HOWTO /usr/share/doc/intltool-0.51.0/I18N-HOWTO
exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=inetltool
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_autoconf(){
    enter_pkg autoconf-2.69.tar.xz
sed '361 s/{/\\{/' -i bin/autoscan.in
./configure --prefix=/usr
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=autoconf
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_automake(){
    enter_pkg automake-1.16.1.tar.xz
./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.16.1
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=automake
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_xz(){
    enter_pkg xz-5.2.4.tar.xz
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/xz-5.2.4
make -j$(nproc)
make install
mv -v   /usr/bin/{lzma,unlzma,lzcat,xz,unxz,xzcat} /bin
mv -v /usr/lib/liblzma.so.* /lib
ln -svf ../../lib/$(readlink /usr/lib/liblzma.so) /usr/lib/liblzma.so
exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=xz
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_kmod(){
    enter_pkg kmod-26.tar.xz
./configure --prefix=/usr          \
            --bindir=/bin          \
            --sysconfdir=/etc      \
            --with-rootlibdir=/lib \
            --with-xz              \
            --with-zlib
make -j$(nproc)
make install
for target in depmod insmod lsmod modinfo modprobe rmmod; do
  ln -sfv ../bin/kmod /sbin/$target
done

ln -sfv kmod /bin/lsmod
exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=kmod
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_gettext(){
    enter_pkg gettext-0.19.8.1.tar.xz
sed -i '/^TESTS =/d' gettext-runtime/tests/Makefile.in &&
sed -i 's/test-lock..EXEEXT.//' gettext-tools/gnulib-tests/Makefile.in
sed -e '/AppData/{N;N;p;s/\.appdata\./.metainfo./}' \
    -i gettext-tools/its/appdata.loc
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/gettext-0.19.8.1
make -j$(nproc)
make install
chmod -v 0755 /usr/lib/preloadable_libintl.so
exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=gettext
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_libelf(){
    enter_pkg elfutils-0.176.tar.bz2
./configure --prefix=/usr
make -j$(nproc)
make install
install -vm644 config/libelf.pc /usr/lib/pkgconfig
exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=libelf
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_libffi(){
    enter_pkg libffi-3.2.1.tar.gz
sed -e '/^includesdir/ s/$(libdir).*$/$(includedir)/' \
    -i include/Makefile.in

sed -e '/^includedir/ s/=.*$/=@includedir@/' \
    -e 's/^Cflags: -I${includedir}/Cflags:/' \
    -i libffi.pc.in
./configure --prefix=/usr --disable-static --with-gcc-arch=native
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=libffi
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_openssl(){
    enter_pkg openssl-1.1.1a.tar.gz
./config --prefix=/usr         \
         --openssldir=/etc/ssl \
         --libdir=lib          \
         shared                \
         zlib-dynamic
make -j$(nproc)
sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
make MANSUFFIX=ssl install
mv -v /usr/share/doc/openssl /usr/share/doc/openssl-1.1.1a
cp -vfr doc/* /usr/share/doc/openssl-1.1.1a

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=openssl
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_python(){
    enter_pkg Python-3.7.2.tar.xz
./configure --prefix=/usr       \
            --enable-shared     \
            --with-system-expat \
            --with-system-ffi   \
            --with-ensurepip=yes
make -j$(nproc)
make install
chmod -v 755 /usr/lib/libpython3.7m.so
chmod -v 755 /usr/lib/libpython3.so

install -v -dm755 /usr/share/doc/python-3.7.2/html 

tar --strip-components=1  \
    --no-same-owner       \
    --no-same-permissions \
    -C /usr/share/doc/python-3.7.2/html \
    -xvf ../python-3.7.2-docs-html.tar.bz2

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=python
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_ninja(){
    enter_pkg ninja-1.9.0.tar.gz
export NINJAJOBS=4
sed -i '/int Guess/a \
  int   j = 0;\
  char* jobs = getenv( "NINJAJOBS" );\
  if ( jobs != NULL ) j = atoi( jobs );\
  if ( j > 0 ) return j;\
' src/ninja.cc
python3 configure.py --bootstrap
install -vm755 ninja /usr/bin/
install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
install -vDm644 misc/zsh-completion  /usr/share/zsh/site-functions/_ninja

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=ninja
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_meson(){
    enter_pkg meson-0.49.2.tar.gz
python3 setup.py build
python3 setup.py install --root=dest
cp -rv dest/* /

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=meson
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_coreutils(){
    enter_pkg coreutils-8.30.tar.xz
patch -Np1 -i ../coreutils-8.30-i18n-1.patch
sed -i '/test.lock/s/^/#/' gnulib-tests/gnulib.mk
autoreconf -fiv
FORCE_UNSAFE_CONFIGURE=1 ./configure \
            --prefix=/usr            \
            --enable-no-install-program=kill,uptime

FORCE_UNSAFE_CONFIGURE=1 make -j$(nproc)
make install

mv -v /usr/bin/{cat,chgrp,chmod,chown,cp,date,dd,df,echo} /bin
mv -v /usr/bin/{false,ln,ls,mkdir,mknod,mv,pwd,rm} /bin
mv -v /usr/bin/{rmdir,stty,sync,true,uname} /bin
mv -v /usr/bin/chroot /usr/sbin
mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
sed -i s/\"1\"/\"8\"/1 /usr/share/man/man8/chroot.8

mv -v /usr/bin/{head,nice,sleep,touch} /bin

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=coreutils
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_check(){
    enter_pkg check-0.12.0.tar.gz
./configure --prefix=/usr
make -j$(nproc)
make install
sed -i '1 s/tools/usr/' /usr/bin/checkmk

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=check
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_diffutils(){
    enter_pkg diffutils-3.7.tar.xz
./configure --prefix=/usr
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=diffutils
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_gawk(){
    enter_pkg gawk-4.2.1.tar.xz
sed -i 's/extras//' Makefile.in
./configure --prefix=/usr
make -j$(nproc)
make install
mkdir -v /usr/share/doc/gawk-4.2.1
cp    -v doc/{awkforai.txt,*.{eps,pdf,jpg}} /usr/share/doc/gawk-4.2.1

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=gawk
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_findutils(){
    enter_pkg findutils-4.6.0.tar.gz
sed -i 's/test-lock..EXEEXT.//' tests/Makefile.in

sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' gl/lib/*.c
sed -i '/unistd/a #include <sys/sysmacros.h>' gl/lib/mountlist.c
echo "#define _IO_IN_BACKUP 0x100" >> gl/lib/stdio-impl.h

./configure --prefix=/usr --localstatedir=/var/lib/locate
make -j$(nproc)
make install

mv -v /usr/bin/find /bin
sed -i 's|find:=${BINDIR}|find:=/bin|' /usr/bin/updatedb

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=findutils
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_groff(){
    enter_pkg groff-1.22.4.tar.gz
PAGE=<paper_size> ./configure --prefix=/usr
make -j1
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=groff
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_grub(){
    enter_pkg grub-2.02.tar.xz
./configure --prefix=/usr          \
            --sbindir=/sbin        \
            --sysconfdir=/etc      \
            --disable-efiemu       \
            --disable-werror
make -j$(nproc)
make install
mv -v /etc/bash_completion.d/grub /usr/share/bash-completion/completions
exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=grub
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_less(){
    enter_pkg less-530.tar.gz
./configure --prefix=/usr --sysconfdir=/etc
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=less
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_gzip(){
    enter_pkg gzip-1.10.tar.xz
./configure --prefix=/usr
make -j$(nproc)
make install
mv -v /usr/bin/gzip /bin
exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=gzip
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_iproute2(){
    enter_pkg iproute2-4.20.0.tar.xz
sed -i /ARPD/d Makefile
rm -fv man/man8/arpd.8
sed -i 's/.m_ipt.o//' tc/Makefile
make -j$(nproc)
make DOCDIR=/usr/share/doc/iproute2-4.20.0 install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=iproute2
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_kbd(){
    enter_pkg kbd-2.0.4.tar.xz
patch -Np1 -i ../kbd-2.0.4-backspace-1.patch
sed -i 's/\(RESIZECONS_PROGS=\)yes/\1no/g' configure
sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in
PKG_CONFIG_PATH=/tools/lib/pkgconfig ./configure --prefix=/usr --disable-vlock
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=kbd
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_libpipeline(){
    enter_pkg libpipeline-1.5.1.tar.gz
./configure --prefix=/usr
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=libpipeline
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_make(){
    enter_pkg make-4.2.1.tar.bz2
sed -i '211,217 d; 219,229 d; 232 d' glob/glob.c
./configure --prefix=/usr
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=make
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_patch(){
    enter_pkg patch-2.7.6.tar.xz
./configure --prefix=/usr
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=patch
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_mandb(){
    enter_pkg 
./configure --prefix=/usr                        \
            --docdir=/usr/share/doc/man-db-2.8.5 \
            --sysconfdir=/etc                    \
            --disable-setuid                     \
            --enable-cache-owner=bin             \
            --with-browser=/usr/bin/lynx         \
            --with-vgrind=/usr/bin/vgrind        \
            --with-grap=/usr/bin/grap            \
            --with-systemdtmpfilesdir=           \
            --with-systemdsystemunitdir=
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=mandb
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_tar(){
    enter_pkg tar-1.31.tar.xz
sed -i 's/abort.*/FALLTHROUGH;/' src/extract.c
FORCE_UNSAFE_CONFIGURE=1  \
./configure --prefix=/usr \
            --bindir=/bin
make -j$(nproc)
make install
make -C doc install-html docdir=/usr/share/doc/tar-1.31
exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=tar
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_textinfo(){
    enter_pkg texinfo-6.5.tar.xz
sed -i '5481,5485 s/({/(\\{/' tp/Texinfo/Parser.pm
./configure --prefix=/usr --disable-static
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=textinfo
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_vim(){
    enter_pkg vim-8.1.tar.bz2
echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
./configure --prefix=/usr
make -j$(nproc)
make install

ln -sv vim /usr/bin/vi
for L in  /usr/share/man/{,*/}man1/vim.1; do
    ln -sv vim.1 $(dirname $L)/vi.1
done

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=vim
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_procpsng(){
    enter_pkg procps-ng-3.3.15.tar.xz
./configure --prefix=/usr                            \
            --exec-prefix=                           \
            --libdir=/usr/lib                        \
            --docdir=/usr/share/doc/procps-ng-3.3.15 \
            --disable-static                         \
            --disable-kill
make -j$(nproc)
make install

mv -v /usr/lib/libprocps.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libprocps.so) /usr/lib/libprocps.so

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=procpsng
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_util_linux(){
    enter_pkg util-linux-2.33.1.tar.xz
mkdir -pv /var/lib/hwclock
rm -vf /usr/include/{blkid,libmount,uuid}
./configure ADJTIME_PATH=/var/lib/hwclock/adjtime   \
            --docdir=/usr/share/doc/util-linux-2.33.1 \
            --disable-chfn-chsh  \
            --disable-login      \
            --disable-nologin    \
            --disable-su         \
            --disable-setpriv    \
            --disable-runuser    \
            --disable-pylibmount \
            --disable-static     \
            --without-python     \
            --without-systemd    \
            --without-systemdsystemunitdir
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=util_linux
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_e2fsprogs(){
    enter_pkg e2fsprogs-1.44.5.tar.gz
mkdir -v build
cd build
../configure --prefix=/usr           \
             --bindir=/bin           \
             --with-root-prefix=""   \
             --enable-elf-shlibs     \
             --disable-libblkid      \
             --disable-libuuid       \
             --disable-uuidd         \
             --disable-fsck
make -j$(nproc)
make install
make install-libs
chmod -v u+w /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
gunzip -v /usr/share/info/libext2fs.info.gz
install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=e2fsprogs
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_sysklogd(){
    enter_pkg sysklogd-1.5.1.tar.gz
sed -i '/Error loading kernel symbols/{n;n;d}' ksym_mod.c
sed -i 's/union wait/int/' syslogd.c
make -j$(nproc)
make BINDIR=/sbin install
cat > /etc/syslog.conf << "EOF"
# Begin /etc/syslog.conf

auth,authpriv.* -/var/log/auth.log
*.*;auth,authpriv.none -/var/log/sys.log
daemon.* -/var/log/daemon.log
kern.* -/var/log/kern.log
mail.* -/var/log/mail.log
user.* -/var/log/user.log
*.emerg *

# End /etc/syslog.conf
EOF
exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=sysklogd
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_sysvinit(){
    enter_pkg sysvinit-2.93.tar.xz
patch -Np1 -i ../sysvinit-2.93-consolidated-1.patch
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=sysvinit
continue $pkg
check_status inchroot_$pkg "skip $pkg"

inchroot_udev(){
    enter_pkg udev-lfs-20171102.tar.bz2
cat > config.cache << "EOF"
HAVE_BLKID=1
BLKID_LIBS="-lblkid"
BLKID_CFLAGS="-I/tools/include"
EOF
./configure --prefix=/usr           \
            --bindir=/sbin          \
            --sbindir=/sbin         \
            --libdir=/usr/lib       \
            --sysconfdir=/etc       \
            --libexecdir=/lib       \
            --with-rootprefix=      \
            --with-rootlibdir=/lib  \
            --enable-manpages       \
            --disable-static        \
            --config-cache
LIBRARY_PATH=/tools/lib make -j$(nproc)
mkdir -pv /lib/udev/rules.d
mkdir -pv /etc/udev/rules.d
make LD_LIBRARY_PATH=/tools/lib install

tar -xvf ../udev-lfs-20171102.tar.bz2
make -f udev-lfs-20171102/Makefile.lfs install

LD_LIBRARY_PATH=/tools/lib udevadm hwdb --update

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile  
}

pkg=udev
continue $pkg
check_status inchroot_$pkg "skip $pkg"