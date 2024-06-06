#!/bin/sh

# Builds a bootable 64 bit image, including the
# kernel elf and bootloader.

# Requires mtools 1:4.0.31-1, later version crash for some reason

BINDIR=./zig-out/bin
PROJECT=gooseOS.img
BOOTEFI=bootx64.efi
KERNEL=kernel.elf

dd if=/dev/zero of=$BINDIR/$PROJECT bs=512 count=93750
mformat -i $BINDIR/$PROJECT -h 32 -t 32 -n 64 -c 1 ::
mmd -i $BINDIR/$PROJECT ::/EFI
mmd -i $BINDIR/$PROJECT ::/EFI/BOOT
mcopy -i $BINDIR/$PROJECT $BINDIR/$BOOTEFI ::/EFI/BOOT
mcopy -i $BINDIR/$PROJECT startup.nsh ::
mcopy -i $BINDIR/$PROJECT $BINDIR/$KERNEL ::
