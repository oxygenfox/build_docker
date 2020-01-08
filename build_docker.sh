#!/usr/bin/env bash

# TELEGRAM START
git clone --depth=1 https://github.com/fabianonline/telegram.sh telegram

TELEGRAM=telegram/telegram

pushKernel() {
	curl -F document=@$(echo $ZIP_DIR/*.zip)  "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" \
			-F chat_id="$CHANNEL_ID"
}

tg_channelcast() {
    "${TELEGRAM}" -c ${CHANNEL_ID} -H \
        "$(
            for POST in "${@}"; do
                echo "${POST}"
            done
        )"
}

tg_sendphoto() {
    if [[ $DEVICE =~ "lavender" ]]; then
    NAME="Redmi Note 7/7S"
elif [[ $DEVICE =~ "ginkgo" ]]; then
    NAME="Redmi Note 8"
elif [[ $DEVICE =~ "vince" ]]; then
    NAME="Redmi 5 Plus"
else
    NAME="Redmi Note 6 Pro"
fi

if ! [[ $BRANCH =~ "10" ]]; then
    ANDROID="9 (Pie)"
else
    ANDROID="10 (Q)"
fi
    KERNEL=$(cat out/.config | grep Linux/arm64 | cut -d " " -f3)
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendPhoto" \
        -d photo="AgADBQADW6kxG8m2kFRAqZq_y-Ckszo6GzMABAEAAwIAA3gAA_BqAgABFgQ" \
        -d chat_id="$CHANNEL_ID" \
        -d parse_mode="HTML" \
        -d caption="<b>Oxygen Tech Kernel || Rebuild 2 || Upstream || New build Realease!</b>
        
📱 <b>Device</b> : <code>$NAME</code>
🤖 <b>Android version</b> : <code>$ANDROID</code>
💻 <b>Linux version</b> : <code>$KERNEL</code>
🔧 <b>Toolchain</b> : <code>${KBUILD_COMPILER_STRING}</code>
🖇️ <b>Branch</b> : <code>${BRANCH}</code>
📝 <b>Commit Point</b> : <code>$(git log --pretty=format:'"%h : %s"' -1)</code>

📥 <b>Download</b> : Here

🧔 <b>Mainteners</b> @FvckinD
🐞 <b>Bug Report</b> @oxygentech_bot"
}
# TELEGRAM END

# Main environtment
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
KERNEL_DIR=$(pwd)
PARENT_DIR="$(dirname "$KERNEL_DIR")"
KERN_IMG=$KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb
CONFIG_PATH=$KERNEL_DIR/arch/arm64/configs/$CONFIG
PATH="${PARENT_DIR}/toolchain/clang/bin:${PARENT_DIR}/toolchain/gcc-arm64/bin:${PARENT_DIR}/toolchain/gcc-arm/bin:${PATH}"

if ! [[ $BRANCH =~ "10" ]]; then
    git clone --depth=1 https://github.com/crDroidMod/android_prebuilts_clang_host_linux-x86_clang-5900059 ../toolchain/clang
else
    git clone --depth=1 https://github.com/crDroidMod/android_prebuilts_clang_host_linux-x86_clang-6032204 ../toolchain/clang
fi

git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 -b android-9.0.0_r50 ../toolchain/gcc-arm
git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 -b android-9.0.0_r50 ../toolchain/gcc-arm64
git clone https://github.com/oxygentech/AnyKernel3 -b $DEVICE

# Build kernel
export KBUILD_COMPILER_STRING="$(${PARENT_DIR}/toolchain/clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g')"
export KBUILD_BUILD_USER="AI"
export TZ=":Asia/Jakarta"

build_gcc () {
    make -j$(nproc --all) O=out \
                          ARCH=arm64 \
                          CROSS_COMPILE=aarch64-linux-android- \
                          CROSS_COMPILE_ARM32=arm-linux-androideabi-
}

build_clang () {
    make -j$(nproc --all) O=out \
                          ARCH=arm64 \
                          CC=clang \
                          CLANG_TRIPLE=aarch64-linux-gnu- \
                          CROSS_COMPILE=aarch64-linux-android- \
                          CROSS_COMPILE_ARM32=arm-linux-androideabi-
}

make O=out ARCH=arm64 $CONFIG

build_clang
if ! [ -a $KERN_IMG ]; then
    tg_channelcast "<b>BuildCI report status:</b> There are build running but its error, please fix and remove this message!"
    exit 1
fi

# Make zip installer

# ENV
ZIP_DIR=$KERNEL_DIR/AnyKernel3
VENDOR_MODULEDIR="$ZIP_DIR/modules/vendor/lib/modules"
STRIP="aarch64-linux-android-strip"

# Functions
wifi_modules () {
    # credit @adekmaulana
    for MODULES in $(find "$KERNEL_DIR/out" -name '*.ko'); do
        "${STRIP}" --strip-unneeded --strip-debug "${MODULES}"
        "$KERNEL_DIR/out/scripts/sign-file" sha512 \
                "$KERNEL_DIR/out/certs/signing_key.pem" \
                "$KERNEL_DIR/out/certs/signing_key.x509" \
                "${MODULES}"
        case ${MODULES} in
                */wlan.ko)
            cp "${MODULES}" "${VENDOR_MODULEDIR}/qca_cld3_wlan.ko" ;;
        esac
    done
    echo -e "(i) Done moving wifi modules"
}

# Make zip
make -C $ZIP_DIR clean
if ! [[ $BRANCH =~ "10" ]]; then
wifi_modules
sed -i 's/WLAN=m/WLAN=y/g' $CONFIG_PATH
make O=out ARCH=arm64 $CONFIG
build_clang
fi
cp $KERN_IMG $ZIP_DIR
make -C $ZIP_DIR normal

# Post TELEGRAM
tg_sendphoto
pushKernel