#!/bin/sh
# Compile un fichier NASM et depose l'executable dans rootfs/ pour Qiling.
if [ $# -lt 1 ]
then
  echo "Usage $0 in_file"
  exit 0
fi
f=$(basename -s .asm $1)
mkdir -p rootfs/obj
rm -f rootfs/$f rootfs/obj/$f.o
nasm -f elf64 $1 -o rootfs/obj/$f.o || exit 1
ld rootfs/obj/$f.o -o rootfs/$f || exit 1
echo "OK : rootfs/$f"
