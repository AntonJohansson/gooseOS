#!/bin/sh

BINDIR=bin
PROJECT=gooseOS.img
#OVMFDIR=external/ovmf
OVMFDIR=../../PonchoOS/OVMFbin

qemu-system-x86_64 -drive format=raw,file=$BINDIR/$PROJECT -m 256M -cpu qemu64 -drive if=pflash,format=raw,unit=0,file="$OVMFDIR/OVMF_CODE-pure-efi.fd",readonly=on -drive if=pflash,format=raw,unit=1,file="$OVMFDIR/OVMF_VARS-pure-efi.fd" -net none -no-reboot
