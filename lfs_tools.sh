#!/bin/bash -e

if [ "$(whoami)" != "lfs" ]; then
        echo "Script must be run as user: lfs"
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

tools_binutils1(){
    enter_pkg binutils-2.32.tar.xz

time {
    mkdir -v build
    cd build
    ../configure --prefix=/tools            \
                --with-sysroot=$LFS        \
                --with-lib-path=/tools/lib \
                --target=$LFS_TGT          \
                --disable-nls              \
                --disable-werror
    make -j$(nproc)
    case $(uname -m) in
    x86_64) mkdir -v /tools/lib && ln -sv lib /tools/lib64 ;;
    esac
    make install
}
    exit_pkg
    echo 'tools_binutils1' >>$statusFile
}

tools_gcc1(){
    enter_pkg gcc-8.2.0.tar.xz

    tar -xf ../mpfr-4.0.2.tar.xz
    mv -v mpfr-4.0.2 mpfr
    tar -xf ../gmp-6.1.2.tar.xz
    mv -v gmp-6.1.2 gmp
    tar -xf ../mpc-1.1.0.tar.gz
    mv -v mpc-1.1.0 mpc

    for file in gcc/config/{linux,i386/linux{,64}}.h
    do
    cp -uv $file{,.orig}
    sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
        -e 's@/usr@/tools@g' $file.orig > $file
    echo '
    #undef STANDARD_STARTFILE_PREFIX_1
    #undef STANDARD_STARTFILE_PREFIX_2
    #define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
    #define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
    touch $file.orig
    done

    case $(uname -m) in
    x86_64)
        sed -e '/m64=/s/lib64/lib/' \
            -i.orig gcc/config/i386/t-linux64
    ;;
    esac

    mkdir -v build
    cd       build
    ../configure                                       \
        --target=$LFS_TGT                              \
        --prefix=/tools                                \
        --with-glibc-version=2.11                      \
        --with-sysroot=$LFS                            \
        --with-newlib                                  \
        --without-headers                              \
        --with-local-prefix=/tools                     \
        --with-native-system-header-dir=/tools/include \
        --disable-nls                                  \
        --disable-shared                               \
        --disable-multilib                             \
        --disable-decimal-float                        \
        --disable-threads                              \
        --disable-libatomic                            \
        --disable-libgomp                              \
        --disable-libmpx                               \
        --disable-libquadmath                          \
        --disable-libssp                               \
        --disable-libvtv                               \
        --disable-libstdcxx                            \
        --enable-languages=c,c++
    make -j$(nproc)
    make install

    exit_pkg
    echo 'tools_gcc1' >>$statusFile
}

tools_linux_header(){
    enter_pkg linux-4.20.12.tar.xz

    make mrproper
    make INSTALL_HDR_PATH=dest headers_install
    cp -rv dest/include/* /tools/include

    exit_pkg
    echo 'tools_linux_header' >>$statusFile
}

tools_glibc(){
    enter_pkg glibc-2.29.tar.xz

    mkdir -v build
cd       build

../configure                             \
      --prefix=/tools                    \
      --host=$LFS_TGT                    \
      --build=$(../scripts/config.guess) \
      --enable-kernel=3.2                \
      --with-headers=/tools/include
make -j$(nproc)
make install

exit_pkg
    echo 'tools_glibc' >>$statusFile
}

tools_check1(){
    echo 'int main(){}' > dummy.c
$LFS_TGT-gcc dummy.c
readelf -l a.out | grep ': /tools' # output

echo 'should see:[Requesting program interpreter: /tools/lib64/ld-linux-x86-64.so.2]'
echo 'tools_check1' >>$statusFile
}

tools_libstdc(){
    pushd gcc-8.2.0
cd build
rm -rf *

../libstdc++-v3/configure           \
    --host=$LFS_TGT                 \
    --prefix=/tools                 \
    --disable-multilib              \
    --disable-nls                   \
    --disable-libstdcxx-threads     \
    --disable-libstdcxx-pch         \
    --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/8.2.0
make -j$(nproc)
make install

popd
echo 'tools_libstdc' >>$statusFile
}

tools_binutils2(){
    pushd binutils-2.32
cd build
rm -rf *

CC=$LFS_TGT-gcc                \
AR=$LFS_TGT-ar                 \
RANLIB=$LFS_TGT-ranlib         \
../configure                   \
    --prefix=/tools            \
    --disable-nls              \
    --disable-werror           \
    --with-lib-path=/tools/lib \
    --with-sysroot
make -j$(nproc)
make install

make -C ld clean
make -C ld LIB_PATH=/usr/lib:/lib
cp -v ld/ld-new /tools/bin

popd
echo 'tools_binutils2' >>$statusFile
}

tools_gcc2(){
    pushd gcc-8.2.0
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
  `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include-fixed/limits.h
cd build
rm -rf *

CC=$LFS_TGT-gcc                                    \
CXX=$LFS_TGT-g++                                   \
AR=$LFS_TGT-ar                                     \
RANLIB=$LFS_TGT-ranlib                             \
../configure                                       \
    --prefix=/tools                                \
    --with-local-prefix=/tools                     \
    --with-native-system-header-dir=/tools/include \
    --enable-languages=c,c++                       \
    --disable-libstdcxx-pch                        \
    --disable-multilib                             \
    --disable-bootstrap                            \
    --disable-libgomp
make -j$(nproc)
make install
ln -sv gcc /tools/bin/cc

popd
echo 'tools_gcc2' >>$statusFile
}

tools_check2(){
    echo 'int main(){}' > dummy.c
cc dummy.c
readelf -l a.out | grep ': /tools'
echo "should output:[Requesting program interpreter: /tools/lib64/ld-linux-x86-64.so.2]"
echo 'tools_check2' >>$statusFile
}

tools_tcl(){
    enter_pkg tcl8.6.9-src.tar.gz

    cd unix
./configure --prefix=/tools
make -j$(nproc)
TZ=UTC make test
make install
chmod -v u+w /tools/lib/libtcl8.6.so
make install-private-headers
ln -sv tclsh8.6 /tools/bin/tclsh

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile
}

tools_expect(){
    enter_pkg expect5.45.4.tar.gz

    cp -v configure{,.orig}
sed 's:/usr/local/bin:/bin:' configure.orig > configure
./configure --prefix=/tools       \
            --with-tcl=/tools/lib \
            --with-tclinclude=/tools/include
make -j$(nproc)
make test
make SCRIPTS="" install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile
}

tools_dejagnu(){
    enter_pkg dejagnu-1.6.2.tar.gz

    ./configure --prefix=/tools
make install
make check

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile
}

tools_m4(){
    enter_pkg m4-1.4.18.tar.xz

    sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c
echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h
./configure --prefix=/tools
make -j$(nproc)
make check
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile
}

tools_ncurses(){
    enter_pkg ncurses-6.1.tar.gz

    sed -i s/mawk// configure
./configure --prefix=/tools \
            --with-shared   \
            --without-debug \
            --without-ada   \
            --enable-widec  \
            --enable-overwrite
make -j$(nproc)
make install
ln -s libncursesw.so /tools/lib/libncurses.so

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile
}

tools_bash(){
    enter_pkg bash-5.0.tar.gz

    ./configure --prefix=/tools --without-bash-malloc
make -j$(nproc)
# make tests
make install
ln -sv bash /tools/bin/sh

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile
}

tools_bison(){
    enter_pkg bison-3.3.2.tar.xz

    ./configure --prefix=/tools
make -j$(nproc)
# make check
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile
}

tools_bzip2(){
    enter_pkg bzip2-1.0.6.tar.gz

    make -j$(nproc)
make PREFIX=/tools install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile
}

tools_coreutils(){
    enter_pkg coreutils-8.30.tar.xz

    ./configure --prefix=/tools --enable-install-program=hostname
make -j$(nproc)
# make RUN_EXPENSIVE_TESTS=yes check
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile
}

tools_diffutils(){
    enter_pkg diffutils-3.7.tar.xz

    ./configure --prefix=/tools
make -j$(nproc)
# make check
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile
}

tools_file(){
    enter_pkg file-5.36.tar.gz

    ./configure --prefix=/tools
make -j$(nproc)
# make check
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile
}

tools_findutils(){
    enter_pkg findutils-4.6.0.tar.gz

    sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' gl/lib/*.c
sed -i '/unistd/a #include <sys/sysmacros.h>' gl/lib/mountlist.c
echo "#define _IO_IN_BACKUP 0x100" >> gl/lib/stdio-impl.h
./configure --prefix=/tools

make -j$(nproc)
# make check
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile
}

tools_gawk(){
    enter_pkg gawk-4.2.1.tar.xz

    ./configure --prefix=/tools
make -j$(nproc)
# make check
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile
}

tools_gettext(){
    enter_pkg gettext-0.19.8.1.tar.xz

    cd gettext-tools
EMACS="no" ./configure --prefix=/tools --disable-shared

make -C gnulib-lib
make -C intl pluralx.c
make -C src msgfmt
make -C src msgmerge
make -C src xgettext

cp -v src/{msgfmt,msgmerge,xgettext} /tools/bin

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile
}

tools_grep(){
    enter_pkg grep-3.3.tar.xz

    ./configure --prefix=/tools
make -j$(nproc)
# make check
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile
}

tools_gzip(){
    enter_pkg gzip-1.10.tar.xz

    ./configure --prefix=/tools
make -j$(nproc)
# make check
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile
}

tools_make(){
    enter_pkg make-4.2.1.tar.bz2

    sed -i '211,217 d; 219,229 d; 232 d' glob/glob.c
./configure --prefix=/tools --without-guile
make -j$(nproc)
# make check
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile
}

tools_patch(){
    enter_pkg patch-2.7.6.tar.xz

    ./configure --prefix=/tools
make -j$(nproc)
# make check
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile
}

tools_perl(){
    enter_pkg perl-5.28.1.tar.xz

    sh Configure -des -Dprefix=/tools -Dlibs=-lm -Uloclibpth -Ulocincpth
make -j$(nproc)
cp -v perl cpan/podlators/scripts/pod2man /tools/bin
mkdir -pv /tools/lib/perl5/5.28.1
cp -Rv lib/* /tools/lib/perl5/5.28.1

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile
}

tools_python(){
    enter_pkg Python-3.7.2.tar.xz

    sed -i '/def add_multiarch_paths/a \        return' setup.py
./configure --prefix=/tools --without-ensurepip
make -j$(nproc)
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile
}

tools_sed(){
    enter_pkg sed-4.7.tar.xz

    ./configure --prefix=/tools
make -j$(nproc)
# make check
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile
}

tools_tar(){
    enter_pkg tar-1.31.tar.xz

    ./configure --prefix=/tools
make -j$(nproc)
# make check
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile
}

tools_textinfo(){
    enter_pkg texinfo-6.5.tar.xz

    ./configure --prefix=/tools
make -j$(nproc)
# make check
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile
}

tools_xz(){
    enter_pkg xz-5.2.4.tar.xz

    ./configure --prefix=/tools
make -j$(nproc)
# make check
make install

exit_pkg
echo ${FUNCNAME[0]} >>$statusFile
}


echo 'wecome to make lfs tools'

continue 'start make tools'

echo "check LFS variable:$LFS"
continue 'compile'

cd $LFS/sources

continue 'binutils1'
check_status tools_binutils1 'skip tools_binutils1'

continue 'gcc1'
check_status tools_gcc1 'skip tools_gcc1'

continue 'linux-header'
check_status tools_linux_header 'skip linux-header'

continue 'glibc'
check_status tools_glibc 'skip glibc'

continue 'check1'
check_status tools_check1 'skip check1'

continue 'libstdc++'
check_status tools_libstdc 'skip libstdc'

continue 'binutils2'
check_status tools_binutils2 'skip tools_binutils2'

continue 'gcc2'
check_status tools_gcc2 'skip tools_gcc2'

continue 'check2'
check_status tools_check2 'skip check2'

pkg=tcl
continue $pkg
check_status tools_$pkg "skip $pkg"

pkg=expect
continue $pkg
check_status tools_$pkg "skip $pkg"

pkg=dejagnu
continue $pkg
check_status tools_$pkg "skip $pkg"

pkg=m4
continue $pkg
check_status tools_$pkg "skip $pkg"

pkg=ncurses
continue $pkg
check_status tools_$pkg "skip $pkg"

pkg=bash
continue $pkg
check_status tools_$pkg "skip $pkg"

pkg=bison
continue $pkg
check_status tools_$pkg "skip $pkg"

pkg=bzip2
continue $pkg
check_status tools_$pkg "skip $pkg"

pkg=coreutils
continue $pkg
check_status tools_$pkg "skip $pkg"

pkg=diffutils
continue $pkg
check_status tools_$pkg "skip $pkg"

pkg=file
continue $pkg
check_status tools_$pkg "skip $pkg"

pkg=findutils
continue $pkg
check_status tools_$pkg "skip $pkg"

pkg=grep
continue $pkg
check_status tools_$pkg "skip $pkg"

pkg=gettext
continue $pkg
check_status tools_$pkg "skip $pkg"

pkg=gzip
continue $pkg
check_status tools_$pkg "skip $pkg"

pkg=make
continue $pkg
check_status tools_$pkg "skip $pkg"

pkg=patch
continue $pkg
check_status tools_$pkg "skip $pkg"

pkg=perl
continue $pkg
check_status tools_$pkg "skip $pkg"

pkg=python
continue $pkg
check_status tools_$pkg "skip $pkg"

pkg=sed
continue $pkg
check_status tools_$pkg "skip $pkg"

pkg=tar
continue $pkg
check_status tools_$pkg "skip $pkg"

pkg=textinfo
continue $pkg
check_status tools_$pkg "skip $pkg"

pkg=xz
continue $pkg
check_status tools_$pkg "skip $pkg"

echo 'tools install complete!'