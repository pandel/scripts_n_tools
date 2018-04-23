#!/bin/sh

WINEXE_REPOSITORY="https://github.com/sogaani/winexe.git"
WINEXE_BRANCH="master"
WINEXE_DIR="$PWD/winexe-waf"
WINEXE_HASH="ce3588cabed68c9d83a74c9e8e7b5c129881d7b6"

SAMBA_REPOSITORY="https://git.samba.org/samba.git"
SAMBA_HASH="f3b650fc75b8edb27a852b88f469e8cd4a317f99"
SAMBA_DIR="$PWD/samba"


#if false; then

# install dependencies
apt-get -y install gcc-mingw-w64 comerr-dev libpopt-dev libbsd-dev zlib1g-dev libc6-dev python-dev libacl1-dev libldap2-dev libgnutls-dev libpam0g-dev git

# get samba and winexe
if [ ! -d ${SAMBA_DIR} ]; then
  mkdir -p ${SAMBA_DIR}
  git clone ${SAMBA_REPOSITORY} ${SAMBA_DIR} || exit 1
fi

if [ ! -d ${WINEXE_DIR} ]; then
  mkdir -p ${WINEXE_DIR}
  git clone ${WINEXE_REPOSITORY} ${WINEXE_DIR} || exit 1
fi

# patch samba
cd ${SAMBA_DIR}
git reset --hard ${SAMBA_HASH}
patch -p1 < ${PWD}/../samba_new.patch

# patch winexe
cd ${WINEXE_DIR}
git reset --hard ${WINEXE_HASH}
patch -p1 < ${PWD}/../winexe.patch

# re-link library
ln -s /lib/x86_64-linux-gnu/libcom_err.so.2 /lib/x86_64-linux-gnu/libcom_err.so

#fi

#if false; then

# build winexe
# winexe
cd ${WINEXE_DIR}/source
./waf --samba-inc-dirs="${SAMBA_DIR}/lib/talloc ${SAMBA_DIR}/lib/tevent ${SAMBA_DIR}/source4 ${SAMBA_DIR} ${SAMBA_DIR}/bin/default ${SAMBA_DIR}/bin/default/source4" --samba-dir=${SAMBA_DIR} configure build

#fi
