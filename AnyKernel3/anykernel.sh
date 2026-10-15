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
SXT_MODE_FILE="$AKHOME/.sxtools-mode"
rm -f "$SXT_MODE_FILE"
tools/sxtools prepare-kernel || abort "sxtools prepare-kernel failed!"

[ -f "$SXT_MODE_FILE" ] || abort "sxtools did not save the selected mode!"
IFS= read -r SXT_MODE < "$SXT_MODE_FILE" || abort "Invalid sxtools mode file!"
rm -f "$SXT_MODE_FILE"
case "$SXT_MODE" in
    vanilla|lkm|builtin) ;;
    *) abort "Unknown sxtools kernel mode!" ;;
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

process_sxtools_ramdisk() {
    "$AKHOME/tools/sxtools" patch-ramdisk "$SXT_MODE" "$RAMDISK" "$SPLITIMG"
    sxt_status=$?
    case "$sxt_status" in
        0|10) return "$sxt_status" ;;
        *) abort "sxtools ramdisk patch failed!" ;;
    esac
}

if has_init_boot; then
    split_boot
    flash_boot

    rm -f "$AKHOME/Image.gz"
    BLOCK=init_boot
    reset_ak
    dump_boot

    if process_sxtools_ramdisk; then
        write_boot
    fi
else
    dump_boot
    process_sxtools_ramdisk || true
    write_boot
fi
