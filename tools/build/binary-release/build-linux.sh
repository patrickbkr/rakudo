#!/usr/bin/env sh

# This script should be allowed to run sudo in a CentOS 6 installation (a
# container will do just fine).
# For some strange reason the environment variables are lost when running this
# script with `sudo` in azure pipelines. So we just do sudo ourselves for the
# dependency install part.

set -o errexit
set -o pipefail

echo "========= Starting build"

echo "========= Updating CentOS 6"
sudo yum -y update
sudo yum clean all

echo "========= Downloading dependencies"
sudo yum -y install curl git perl perl-core gcc make

echo "========= Downloading release"
curl -o rakudo.tgz $RELEASE_URL

echo "========= Extracting release"
tar -xzf rakudo.tgz
cd rakudo-*

echo "========= Configuring Rakudo (includes building MoarVM and NQP)"
perl Configure.pl --gen-moar --gen-nqp --backends=moar --moar-option='--toolchain=gnu' --relocatable

echo "========= Building Rakudo"
make

echo "========= Installing Rakudo"
make install

echo "========= Testing Rakudo"
#make test

echo "========= Cloning Zef"
git clone https://github.com/ugexe/zef.git

echo "========= Installing Zef"
pushd zef
../install/bin/raku -I. bin/zef install .
popd

echo "========= Copying auxiliary files"
cp -r tools/build/binary-release/Linux/* install
cp LICENSE install

echo "========= Preparing archive"
mv install rakudo-$VERSION
tar -zcv --owner=0 --group=0 --numeric-owner -f ../rakudo-linux.tar.gz rakudo-$VERSION

