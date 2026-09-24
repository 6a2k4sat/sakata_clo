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
NO_MAGISK_CHECK=1

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

VANILLA_IMAGE="$AKHOME/Image-vanilla.gz"
KSU_IMAGE="$AKHOME/Image-ksu.gz"

[ -f "$VANILLA_IMAGE" ] ||
    abort "Image-vanilla.gz not found. Aborting..."

[ -f "$KSU_IMAGE" ] ||
    abort "Image-ksu.gz not found. Aborting..."

command -v getevent >/dev/null 2>&1 ||
    abort "getevent is not available. Aborting..."

ui_print " " "Select kernel variant:" " "
ui_print "Volume UP   : Vanilla"
ui_print "Volume DOWN : KernelSU + SUSFS" " "

key_click=""
while [ -z "$key_click" ]; do
    key_click="$(
        getevent -qlc 1 2>/dev/null |
        awk '{ print $3 }' |
        grep 'KEY_VOLUME'
    )"
    sleep 0.2
done

case "$key_click" in
    KEY_VOLUMEUP)
        variant="Vanilla"
        image="$VANILLA_IMAGE"
        ;;
    KEY_VOLUMEDOWN)
        variant="KernelSU + SUSFS"
        image="$KSU_IMAGE"
        ;;
    *)
        abort "Unknown volume key. Aborting..."
        ;;
esac

ui_print "Selected: $variant"
rm -f "$AKHOME/Image" "$AKHOME/Image.gz"
cp -f "$image" "$AKHOME/Image.gz" ||
    abort "Failed to prepare selected kernel image!"

sync
ui_print "Preparing boot image..."

# boot install
split_boot
flash_boot

