# ============================================================================
# Resurgam OS - Makefile
# 32-bit GUI Operating System
# ============================================================================

# Compiler settings
CC = i686-elf-gcc
LD = i686-elf-ld
AS = nasm
CFLAGS = -m32 -ffreestanding -O2 -Wall -Wextra -fno-exceptions -fno-rtti          -nostdlib -nostartfiles -nodefaultlibs -I./kernel -I./include
LDFLAGS = -m elf_i386 -T linker.ld
ASFLAGS = -f elf32

# Directories
BOOT_DIR = boot
KERNEL_DIR = kernel
BUILD_DIR = build
ISO_DIR = isodir

# Source files
BOOT_SRCS = $(BOOT_DIR)/boot.asm $(BOOT_DIR)/stage2.asm
KERNEL_ASM = $(KERNEL_DIR)/kernel.asm
KERNEL_CSRCS = $(KERNEL_DIR)/kernel.c                $(KERNEL_DIR)/vga.c                $(KERNEL_DIR)/console.c                $(KERNEL_DIR)/keyboard.c                $(KERNEL_DIR)/mouse.c                $(KERNEL_DIR)/idt.c                $(KERNEL_DIR)/gdt.c                $(KERNEL_DIR)/timer.c                $(KERNEL_DIR)/paging.c                $(KERNEL_DIR)/task.c                $(KERNEL_DIR)/vfs.c                $(KERNEL_DIR)/shell.c                $(KERNEL_DIR)/window.c                $(KERNEL_DIR)/desktop.c

# Object files
BOOT_OBJS = $(BUILD_DIR)/boot.bin $(BUILD_DIR)/stage2.bin
KERNEL_OBJS = $(BUILD_DIR)/kernel_asm.o $(BUILD_DIR)/kernel.o               $(BUILD_DIR)/vga.o $(BUILD_DIR)/console.o               $(BUILD_DIR)/keyboard.o $(BUILD_DIR)/mouse.o               $(BUILD_DIR)/idt.o $(BUILD_DIR)/gdt.o               $(BUILD_DIR)/timer.o $(BUILD_DIR)/paging.o               $(BUILD_DIR)/task.o $(BUILD_DIR)/vfs.o               $(BUILD_DIR)/shell.o $(BUILD_DIR)/window.o               $(BUILD_DIR)/desktop.o

# Targets
all: $(BUILD_DIR)/resurgam.iso

# Create build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Boot sector
$(BUILD_DIR)/boot.bin: $(BOOT_DIR)/boot.asm | $(BUILD_DIR)
	$(AS) -f bin $< -o $@

# Stage2 loader
$(BUILD_DIR)/stage2.bin: $(BOOT_DIR)/stage2.asm | $(BUILD_DIR)
	$(AS) -f bin $< -o $@

# Kernel assembly
$(BUILD_DIR)/kernel_asm.o: $(KERNEL_DIR)/kernel.asm | $(BUILD_DIR)
	$(AS) $(ASFLAGS) $< -o $@

# Kernel C files
$(BUILD_DIR)/kernel.o: $(KERNEL_DIR)/kernel.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/vga.o: $(KERNEL_DIR)/vga.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/console.o: $(KERNEL_DIR)/console.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/keyboard.o: $(KERNEL_DIR)/keyboard.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/mouse.o: $(KERNEL_DIR)/mouse.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/idt.o: $(KERNEL_DIR)/idt.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/gdt.o: $(KERNEL_DIR)/gdt.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/timer.o: $(KERNEL_DIR)/timer.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/paging.o: $(KERNEL_DIR)/paging.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/task.o: $(KERNEL_DIR)/task.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/vfs.o: $(KERNEL_DIR)/vfs.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/shell.o: $(KERNEL_DIR)/shell.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/window.o: $(KERNEL_DIR)/window.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/desktop.o: $(KERNEL_DIR)/desktop.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

# Link kernel
$(BUILD_DIR)/kernel.bin: $(KERNEL_OBJS) linker.ld | $(BUILD_DIR)
	$(LD) $(LDFLAGS) -o $@ $(KERNEL_OBJS)

# Create floppy image
$(BUILD_DIR)/resurgam.img: $(BUILD_DIR)/boot.bin $(BUILD_DIR)/stage2.bin $(BUILD_DIR)/kernel.bin
	dd if=/dev/zero of=$@ bs=512 count=2880
	dd if=$(BUILD_DIR)/boot.bin of=$@ bs=512 count=1 conv=notrunc
	dd if=$(BUILD_DIR)/stage2.bin of=$@ bs=512 seek=1 conv=notrunc
	dd if=$(BUILD_DIR)/kernel.bin of=$@ bs=512 seek=17 conv=notrunc

# Create ISO
$(BUILD_DIR)/resurgam.iso: $(BUILD_DIR)/resurgam.img
	mkdir -p $(ISO_DIR)/boot/grub
	cp $(BUILD_DIR)/resurgam.img $(ISO_DIR)/boot/
	echo "set timeout=0" > $(ISO_DIR)/boot/grub/grub.cfg
	echo "set default=0" >> $(ISO_DIR)/boot/grub/grub.cfg
	echo "" >> $(ISO_DIR)/boot/grub/grub.cfg
	echo "menuentry \"Resurgam OS\" {" >> $(ISO_DIR)/boot/grub/grub.cfg
	echo "    multiboot /boot/resurgam.img" >> $(ISO_DIR)/boot/grub/grub.cfg
	echo "    boot" >> $(ISO_DIR)/boot/grub/grub.cfg
	echo "}" >> $(ISO_DIR)/boot/grub/grub.cfg
	grub-mkrescue -o $@ $(ISO_DIR)

# Run in QEMU
run: $(BUILD_DIR)/resurgam.img
	qemu-system-i386 -fda $(BUILD_DIR)/resurgam.img -m 32M -vga std

# Run with debug
run-debug: $(BUILD_DIR)/resurgam.img
	qemu-system-i386 -fda $(BUILD_DIR)/resurgam.img -m 32M -vga std -d int -no-reboot -no-shutdown

# Run with serial output
run-serial: $(BUILD_DIR)/resurgam.img
	qemu-system-i386 -fda $(BUILD_DIR)/resurgam.img -m 32M -vga std -serial stdio

# Clean
clean:
	rm -rf $(BUILD_DIR) $(ISO_DIR)

# Deep clean
distclean: clean
	rm -f *.o *.bin *.img *.iso

.PHONY: all clean distclean run run-debug run-serial
