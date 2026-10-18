### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers

### AnyKernel setup
# global properties
properties() { '
kernel.string=Linux version 6.6.143
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=onyx
device.name2=
device.name3=
device.name4=
device.name5=
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties

# boot shell variables
BLOCK=boot
IS_SLOT_DEVICE=auto
RAMDISK_COMPRESSION=auto
PATCH_VBMETA_FLAG=auto
NO_BLOCK_DISPLAY=1
NO_MAGISK_CHECK=1

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

export AKHOME OUTFD
SXT="$AKHOME/tools/sxtools"
MODE_FILE="$AKHOME/.sxtools-mode"

rm -f "$MODE_FILE"
"$SXT" prepare-kernel || abort "Failed to prepare kernel!"

[ -f "$MODE_FILE" ] || abort "Kernel mode not found!"
IFS= read -r SXT_MODE < "$MODE_FILE" || abort "Failed to read kernel mode!"
rm -f "$MODE_FILE"

case "$SXT_MODE" in
    vanilla|lkm|builtin) ;;
    *) abort "Invalid kernel mode!" ;;
esac

has_init_boot() {
    local part
    for part in \
        /dev/block/by-name/init_boot${SLOT} \
        /dev/block/bootdevice/by-name/init_boot${SLOT} \
        /dev/block/platform/*/by-name/init_boot${SLOT} \
        /dev/block/platform/*/*/by-name/init_boot${SLOT} \
        /dev/init_boot${SLOT}
    do
        [ -e "$part" ] && return 0
    done
    return 1
}

patch_kernel_ramdisk() {
    local status
    "$SXT" patch-ramdisk "$SXT_MODE" "$RAMDISK" "$SPLITIMG"
    status=$?
    case "$status" in
        0|10) return "$status" ;;
        *) abort "Failed to patch ramdisk!" ;;
    esac
}

if has_init_boot; then
    # Flash the selected kernel to boot
    split_boot
    flash_boot

    # Patch init_boot only if the ramdisk requires changes
    rm -f "$AKHOME/Image.gz"
    BLOCK=init_boot
    reset_ak
    dump_boot

    if patch_kernel_ramdisk; then
        write_boot
    fi
else
    dump_boot
    patch_kernel_ramdisk || true
    write_boot
fi

if [ "$SXT_MODE" = lkm ]; then
    "$SXT" sync-susfs lkm \
        "$AKHOME/lkm/susfs_guard_lkm.ko" \
        "$AKHOME/tools/susfs_insmod" \
        "$AKHOME/tools/susfs-loader.sh" \
        || abort "Kernel flashed, but SUSFS loader installation failed!"
else
    "$SXT" sync-susfs "$SXT_MODE" - - - \
        || abort "Kernel flashed, but SUSFS loader cleanup failed!"
fi
