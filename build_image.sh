#!/bin/sh

# Builds a bootable 64 bit image, including the
# kernel elf and bootloader.

BINDIR=bin
PROJECT=gooseOS.img
BOOTEFI=bootx64.efi
KERNEL=kernel.elf

dd if=/dev/zero of=$BINDIR/$PROJECT bs=512 count=93750
mformat -i $BINDIR/$PROJECT -f 1440 ::
mmd -i $BINDIR/$PROJECT ::/EFI
mmd -i $BINDIR/$PROJECT ::/EFI/BOOT
mcopy -i $BINDIR/$PROJECT $BINDIR/$BOOTEFI ::/EFI/BOOT
mcopy -i $BINDIR/$PROJECT startup.nsh ::
mcopy -i $BINDIR/$PROJECT $BINDIR/$KERNEL ::
