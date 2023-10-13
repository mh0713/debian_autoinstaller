#!/bin/bash

set -o errexit

# 変数定義
CUR_DIR=$(cd $(dirname $0); pwd)
SRC_DIR="${CUR_DIR}"/src
ORIG_ISO="${CUR_DIR}"/base_iso/debian-12.2.0-amd64-netinst.iso
NEW_FILES="${CUR_DIR}"/tmp/
VER=$(git tag | sort | tail -n 1)

while getopts v: OPT
do
  case $OPT in
     v) VER=${OPTARG} ;;
  esac
done

NEW_ISO="${NEW_FILES}"/installer-12.2-${VER}.iso
MBR_TEMPLATE=isohdpfx.bin


cd "${CUR_DIR}"

# 作業ディレクトリのクリーンアップ＆作成
sudo rm -rf ${NEW_FILES}
mkdir -p ${NEW_FILES}

# 必要なツールのインストール
sudo apt update
sudo apt -y install cpio syslinux isolinux xorriso mkisofs syslinux-utils pigz

#Extracting the Initrd from an ISO Image
xorriso -osirrox on -indev "$ORIG_ISO" -extract / "$NEW_FILES"

#Adding a Preseed File to the Initrd
chmod +w -R "${NEW_FILES}"/install.amd/

sudo cp "${SRC_DIR}"/grub.cfg "${NEW_FILES}"/boot/grub/
sudo cp "${SRC_DIR}"/preseed.cfg "${NEW_FILES}"
sudo cp "${SRC_DIR}"/blacklist.conf "${NEW_FILES}"

#Regenerating md5sum.txt
cd "${NEW_FILES}"
chmod +w md5sum.txt

find -follow -type f ! -name md5sum.txt -print0 | xargs -0 md5sum > md5sum.txt
chmod -w md5sum.txt
cd "${CUR_DIR}"

dd if="${ORIG_ISO}" bs=1 count=432 of="${MBR_TEMPLATE}"

#ブータブルISOの作成
sudo xorriso -as mkisofs \
   -r -V 'debian 12.2 installer n' \
   -o "${NEW_ISO}" \
   -J -J -joliet-long -cache-inodes \
   -isohybrid-mbr "${MBR_TEMPLATE}" \
   -b isolinux/isolinux.bin \
   -c isolinux/boot.cat \
   -boot-load-size 4 -boot-info-table -no-emul-boot \
   -eltorito-alt-boot \
   -e boot/grub/efi.img \
   -no-emul-boot -isohybrid-gpt-basdat -isohybrid-apm-hfsplus \
   "${NEW_FILES}"
