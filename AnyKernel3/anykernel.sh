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

IMAGE_VANILLA="$AKHOME/Image-vanilla.gz"
IMAGE_KSU="$AKHOME/Image-ksu.gz"
LKM_MODULE="$AKHOME/lkm/kernelsu.ko"
LKM_INIT="$AKHOME/lkm/ksuinit"

command -v getevent >/dev/null 2>&1 || abort "getevent is not available!"

read_volume_key() {
    local key

    while true; do
        key="$(
            getevent -qlc 1 2>/dev/null |
                awk '
                    /KEY_VOLUMEUP/ && $NF == "DOWN" {
                        print "KEY_VOLUMEUP"
                        exit
                    }
                    /KEY_VOLUMEDOWN/ && $NF == "DOWN" {
                        print "KEY_VOLUMEDOWN"
                        exit
                    }
                '
        )"

        case "$key" in
            KEY_VOLUMEUP|KEY_VOLUMEDOWN)
                printf '%s\n' "$key"
                return 0
                ;;
        esac

        sleep 0.2
    done
}

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

strip_bundled_config() {
    local config option filtered

    [ -f "$RAMDISK/ksu_config" ] || return 0
    config="$(cat "$RAMDISK/ksu_config")"
    filtered=""

    for option in $config; do
        [ "$option" = "bundled=1" ] && continue
        filtered="${filtered:+$filtered }$option"
    done

    if [ -n "$filtered" ]; then
        printf '%s' "$filtered" > "$RAMDISK/ksu_config"
    else
        rm -f "$RAMDISK/ksu_config"
    fi
}

lkm_present() {
    [ -e "$RAMDISK/init.real" ] ||
        [ -e "$RAMDISK/kernelsu.ko" ] ||
        { [ -f "$RAMDISK/ksu_config" ] && grep -qw 'bundled=1' "$RAMDISK/ksu_config"; }
}

install_lkm() {
    [ -f "$LKM_MODULE" ] || abort "kernelsu.ko not found!"
    [ -f "$LKM_INIT" ] || abort "ksuinit not found!"

    magiskboot cpio "$SPLITIMG/ramdisk.cpio" test >/dev/null 2>&1
    [ $? -eq 1 ] && abort "KernelSU LKM cannot patch a Magisk-patched ramdisk!"

    if [ -e "$RAMDISK/kernelsu.ko" ] && [ ! -e "$RAMDISK/init.real" ]; then
        abort "Invalid KernelSU LKM ramdisk state!"
    fi

    if [ ! -e "$RAMDISK/init.real" ]; then
        [ -e "$RAMDISK/init" ] || abort "Ramdisk init not found!"
        mv -f "$RAMDISK/init" "$RAMDISK/init.real" ||
            abort "Failed to preserve original init!"
    fi

    cp -f "$LKM_INIT" "$RAMDISK/init" || abort "Failed to install ksuinit!"
    cp -f "$LKM_MODULE" "$RAMDISK/kernelsu.ko" || abort "Failed to install kernelsu.ko!"

    chmod 0755 "$RAMDISK/init" "$RAMDISK/kernelsu.ko"
    strip_bundled_config
}

remove_lkm() {
    if [ -e "$RAMDISK/init.real" ]; then
        rm -f "$RAMDISK/init"
        mv -f "$RAMDISK/init.real" "$RAMDISK/init" ||
            abort "Failed to restore original init!"
    fi

    rm -f "$RAMDISK/kernelsu.ko"

    if [ -f "$RAMDISK/ksu_config" ] &&
       grep -qw 'bundled=1' "$RAMDISK/ksu_config"; then
        strip_bundled_config
    fi
}

select_ksu_mode() {
    ui_print " " "Select KernelSU-Next mode:" " "
    ui_print "Volume UP   : Mode LKM"
    ui_print "Volume DOWN : Mode Built-in + SUSFS" " "

    case "$(read_volume_key)" in
        KEY_VOLUMEUP)
            MODE=lkm
            VARIANT="KernelSU-Next (LKM)"
            IMAGE="$IMAGE_VANILLA"
            ;;
        KEY_VOLUMEDOWN)
            MODE=builtin
            VARIANT="KernelSU-Next (Built-in + SUSFS)"
            IMAGE="$IMAGE_KSU"
            ;;
    esac
}

select_variant() {
    ui_print " " "Select kernel variant:" " "
    ui_print "Volume UP   : Vanilla"
    ui_print "Volume DOWN : KernelSU-Next" " "

    case "$(read_volume_key)" in
        KEY_VOLUMEUP)
            MODE=vanilla
            VARIANT="Vanilla"
            IMAGE="$IMAGE_VANILLA"
            ;;
        KEY_VOLUMEDOWN)
            sleep 0.5
            select_ksu_mode
            ;;
    esac
}

announce_install() {
    case "$MODE" in
        vanilla)
            ui_print "Installing Vanilla variant..."
            ;;
        lkm)
            ui_print "Installing KernelSU-Next LKM..."
            ;;
        builtin)
            ui_print "Installing KernelSU-Next Built-in..."
            ;;
    esac
}

process_lkm_ramdisk() {
    case "$MODE" in
        lkm)
            install_lkm
            return 0
            ;;
        vanilla|builtin)
            if lkm_present; then
                ui_print "Removing existing KernelSU-Next LKM..."
                remove_lkm
                announce_install
                return 0
            fi

            announce_install
            return 1
            ;;
    esac
    return 1
}

select_variant

[ -f "$IMAGE" ] || abort "Selected kernel image not found!"

ui_print " " "Selected: $VARIANT" " "
[ "$MODE" = lkm ] && announce_install

cp -f "$IMAGE" "$AKHOME/Image.gz" ||
    abort "Failed to prepare kernel image!"

if has_init_boot; then
    split_boot
    flash_boot

    rm -f "$AKHOME/Image.gz"

    BLOCK=init_boot
    reset_ak
    dump_boot

    if process_lkm_ramdisk; then
        write_boot
    fi
else
    dump_boot
    process_lkm_ramdisk || true
    write_boot
fi
