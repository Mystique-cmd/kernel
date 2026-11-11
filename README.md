# Mystique OS Bootloader and Kernel

This repository is an experimental x86 bootloader plus a minimal protected-mode kernel. It is useful for learning BIOS disk I/O, segment setup, and basic paging, but it is not a complete operating system.

## Prerequisites

- NASM
- QEMU

Install them with your usual package manager.

## Build

```bash
nasm -f bin bootloader.asm -o bootloader.bin
nasm -f bin kernel.asm -o kernel.bin
```

## Create a bootable floppy image

```bash
dd if=/dev/zero of=disk.img bs=1M count=1
dd if=bootloader.bin of=disk.img bs=512 count=1 conv=notrunc
# The kernel starts at LBA 1, immediately after the boot sector.
dd if=kernel.bin of=disk.img bs=512 seek=1 conv=notrunc
```

## Run it

```bash
qemu-system-i386 -fda disk.img
```

This project is intentionally small and is meant to demonstrate the boot sequence rather than a finished OS.

## Current layout and assumptions

- Boot sector: loaded by BIOS at 0x7C00
- Kernel load address: physical 0x10000
- Kernel virtual mapping: 0xC0000000 (higher half)
- Bootloader read strategy: BIOS extended read (`INT 13h`, AH=0x42) with an LBA packet
- Kernel begins at sector 1 on the floppy image, not sector 2
- User-space paging is still experimental and is not used in the default execution path

## Memory map

- 0x00000000-0x003FFFFF: identity-mapped lower memory during setup
- 0x10000: kernel is loaded here by the bootloader
- 0xC0000000: kernel's higher-half virtual base
- 0xC000FFFC: chosen kernel stack top after paging is enabled

## Notes

The current code intentionally demonstrates the transition to protected mode and the higher-half mapping. The paging setup is a working educational step, not a complete user-space scheduler or process loader.

## Bootloader configuration

The bootloader currently reads up to 64 sectors starting at LBA 1:

```asm
KERNEL_SECTORS equ 64
KERNEL_SECTOR_START equ 1
```

This was chosen to cover the assembled kernel image and the page tables that are appended to the end of the kernel binary.
