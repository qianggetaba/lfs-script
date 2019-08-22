#!/bin/bash -e


statusFile=status.done


continue(){
read -p "$1 continue?(n for stop):" yn
case $yn in
    [Nn]* ) exit;;
esac
}

dl_book_package(){
    wget http://www.linuxfromscratch.org/lfs/downloads/stable/LFS-BOOK-8.4-NOCHUNKS.html --continue --directory-prefix=book
    wget http://www.linuxfromscratch.org/lfs/downloads/stable/LFS-BOOK-8.4.pdf --continue --directory-prefix=book
    wget http://www.linuxfromscratch.org/lfs/downloads/stable/LFS-BOOK-8.4.tar.bz2 --continue --directory-prefix=book
    wget http://www.linuxfromscratch.org/lfs/downloads/stable/lfs-bootscripts-20180820.tar.bz2 --continue --directory-prefix=book
    wget http://www.linuxfromscratch.org/lfs/downloads/stable/md5sums --continue --directory-prefix=book
    wget http://www.linuxfromscratch.org/lfs/downloads/stable/wget-list --continue --directory-prefix=book
    
    wget --input-file=book/wget-list --continue --directory-prefix=pkg

    pushd pkg
    if md5sum -c ../book/md5sums | grep -v OK; then
        echo "wrong package"
        popd
        exit
    else
        echo "all package passed"
    fi
    popd

    echo 'dl_book_package' >>$statusFile
}

host_version_check(){
    # Simple script to list version numbers of critical development tools
    export LC_ALL=C
    bash --version | head -n1 | cut -d" " -f2-4
    MYSH=$(readlink -f /bin/sh)
    echo "/bin/sh -> $MYSH"
    echo $MYSH | grep -q bash || echo "ERROR: /bin/sh does not point to bash"
    unset MYSH

    echo -n "Binutils: "; ld --version | head -n1 | cut -d" " -f3-
    bison --version | head -n1

    if [ -h /usr/bin/yacc ]; then
    echo "/usr/bin/yacc -> `readlink -f /usr/bin/yacc`";
    elif [ -x /usr/bin/yacc ]; then
    echo yacc is `/usr/bin/yacc --version | head -n1`
    else
    echo "yacc not found" 
    fi

    bzip2 --version 2>&1 < /dev/null | head -n1 | cut -d" " -f1,6-
    echo -n "Coreutils: "; chown --version | head -n1 | cut -d")" -f2
    diff --version | head -n1
    find --version | head -n1
    gawk --version | head -n1

    if [ -h /usr/bin/awk ]; then
    echo "/usr/bin/awk -> `readlink -f /usr/bin/awk`";
    elif [ -x /usr/bin/awk ]; then
    echo awk is `/usr/bin/awk --version | head -n1`
    else 
    echo "awk not found" 
    fi

    gcc --version | head -n1
    g++ --version | head -n1
    ldd --version | head -n1 | cut -d" " -f2-  # glibc version
    grep --version | head -n1
    gzip --version | head -n1
    cat /proc/version
    m4 --version | head -n1
    make --version | head -n1
    patch --version | head -n1
    echo Perl `perl -V:version`
    python3 --version
    sed --version | head -n1
    tar --version | head -n1
    makeinfo --version | head -n1  # texinfo version
    xz --version | head -n1

    echo 'int main(){}' > dummy.c && g++ -o dummy dummy.c
    if [ -x dummy ]
    then echo "g++ compilation OK";
    else echo "g++ compilation failed"; fi
    rm -f dummy.c dummy

    echo 'host_version_check' >>$statusFile
}

partition_prepare(){

    read -p "input lfs partition [such as /dev/sda2]:" dev
    if ls "$dev" ; then
        echo "lfs partition: $dev"
    else
        echo "partition $dev not exist!"
        exit
    fi

    continue "will format and mount partition $dev"
    sudo mkfs -v -t ext4 $dev
    LFS=/mnt/lfs
    sudo mkdir -pv $LFS
    sudo mount -v -t ext4 $dev $LFS
    sudo mkdir -v $LFS/sources
    sudo chmod -v a+wt $LFS/sources
    sudo mkdir -v $LFS/tools
    sudo ln -sv $LFS/tools /

    echo "start copy package"
    cp pkg/* $LFS/sources/

    echo 'partition_prepare' >>$statusFile
}

add_user_lfs(){
    sudo groupadd lfs
    sudo useradd -s /bin/bash -g lfs -m -k /dev/null lfs

    sudo passwd lfs
    sudo chown -v lfs $LFS/tools
    sudo chown -v lfs $LFS/sources

    if sudo ls /home/lfs/.bash_profile; then
        echo 'exist .bash_profile'
    else
cat << "EOF" | sudo tee /home/lfs/.bash_profile
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF
    fi

    if sudo ls /home/lfs/.bashrc; then
        echo 'exist .bashrc'
    else
cat << "EOF" | sudo tee /home/lfs/.bashrc
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/tools/bin:/bin:/usr/bin
export LFS LC_ALL LFS_TGT PATH
EOF
    fi

    echo 'add_user_lfs' >>$statusFile
}

echo 'lfs 8.4 script!'

continue 'start download book and package'
if grep -q dl_book_package "$statusFile"; then
  echo "skip download"
else
  dl_book_package
fi

continue 'version check'
if grep -q host_version_check "$statusFile"; then
  echo "skip version check"
else
  host_version_check
fi

continue 'prepare partition'
if grep -q partition_prepare "$statusFile"; then
  echo "skip partition"
else
  partition_prepare
fi

continue "add user:lfs"
if grep -q add_user_lfs "$statusFile"; then
  echo "skip add_user_lfs"
else
  add_user_lfs
fi

continue 'copy lfs_tools.sh to /home/lfs'
sudo cp lfs_tools.sh /home/lfs/

echo 'run "su - lfs" switch to lfs, run lfs_tools.sh'
