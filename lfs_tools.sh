#!/bin/bash -e

if [ "$(whoami)" != "lfs" ]; then
        echo "Script must be run as user: lfs"
        exit -1
fi

continue(){
read -p "$1 continue?(n for stop):" yn
case $yn in
    [Nn]* ) exit;;
esac
}

test(){
    echo 'test function'
}

check_status(){
    if grep -q $1 "$statusFile"; then
        echo "$2"
    else
        $1
    fi
}

tools_binutils1(){
    tarball=binutils-2.32.tar.xz
    rootfolder=`tar tf  $tarball |head -1|sed -e 's@/.*@@' | uniq`
    rm -rf $rootfolder
    tar xf $tarball
    pushd $rootfolder

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

    unset tarball
    unset rootfolder
    popd

    echo 'tools_binutils1' >>$statusFile
}

echo 'wecome to make lfs tools'

continue 'start make tools'

echo "check LFS variable:$LFS"
continue 'compile'

statusFile=status.done
cd $LFS/sources

continue 'binutils1'
