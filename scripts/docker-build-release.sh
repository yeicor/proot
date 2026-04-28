#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT}/dist"
ANDROID_CACHE_DIR="${ANDROID_CACHE_DIR:-/tmp/proot-android-cache}"
ANDROID_NDK_VERSION="${ANDROID_NDK_VERSION:-r29}"
ANDROID_NDK_ZIP="${ANDROID_NDK_ZIP:-android-ndk-r29-linux.zip}"
ANDROID_NDK_URL="${ANDROID_NDK_URL:-https://dl.google.com/android/repository/android-ndk-r29-linux.zip}"
TALLOC_VERSION="${TALLOC_VERSION:-2.4.3}"
TALLOC_URL="${TALLOC_URL:-https://download.samba.org/pub/talloc/talloc-${TALLOC_VERSION}.tar.gz}"

mkdir -p "${DIST_DIR}" "${ANDROID_CACHE_DIR}"

run_linux_build() {
	local platform="$1"
	local arch="$2"

	docker run --rm --platform "${platform}" \
		-v "${ROOT}:/work" \
		-w /work \
		alpine:3.22 \
		sh -lc "
			set -e
			apk add --no-cache build-base clang20 lld llvm20 talloc-dev talloc-static linux-headers make git file libbsd-dev >/dev/null
			make -C src clean >/dev/null 2>&1 || true
			make -C src \
				PROOT_DISABLE_LOADER_32BIT=1 \
				CC=clang-20 \
				LD=clang-20 \
				STRIP=llvm-strip \
				OBJCOPY=llvm-objcopy \
				OBJDUMP=llvm-objdump \
				LDFLAGS='-static -s -Wl,-z,noexecstack' \
				proot
			mkdir -p /work/dist/linux-${arch}
			cp src/proot /work/dist/linux-${arch}/proot
			file /work/dist/linux-${arch}/proot
		"
}

run_android_build() {
	local arch="$1"
	local triple="$2"
	local api="$3"
	local termux_arch="$4"
	local uname_machine="$5"

	docker run --rm --platform linux/amd64 \
		-v "${ROOT}:/work" \
		-v "${ANDROID_CACHE_DIR}:/cache" \
		-w /work \
		debian:bookworm-slim \
		sh -lc "
			set -e
			apt-get update >/dev/null
			apt-get install -y --no-install-recommends ca-certificates curl unzip xz-utils build-essential file git make binutils >/dev/null

			mkdir -p /opt /cache
			if [ ! -d /opt/android-ndk-${ANDROID_NDK_VERSION} ]; then
				if [ ! -f /cache/${ANDROID_NDK_ZIP} ]; then
					curl -fsSL -o /cache/${ANDROID_NDK_ZIP} ${ANDROID_NDK_URL}
				fi
				unzip -q /cache/${ANDROID_NDK_ZIP} -d /opt
			fi

			if [ ! -f /cache/talloc-${TALLOC_VERSION}.tar.gz ]; then
				curl -fsSL -o /cache/talloc-${TALLOC_VERSION}.tar.gz ${TALLOC_URL}
			fi

			rm -rf /tmp/talloc-${TALLOC_VERSION} /tmp/android-talloc
			mkdir -p /tmp/android-talloc/pkg
			tar -xf /cache/talloc-${TALLOC_VERSION}.tar.gz -C /tmp

			cd /tmp/android-talloc
			curl -fsSL -o libtalloc-static.deb https://packages.termux.dev/apt/termux-main/pool/main/libt/libtalloc-static/libtalloc-static_${TALLOC_VERSION}_${termux_arch}.deb
			ar x libtalloc-static.deb
			cd pkg
			tar -xf ../data.tar.xz

			NDK=/opt/android-ndk-${ANDROID_NDK_VERSION}
			CC=\"\$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/${triple}${api}-clang\"
			STRIP=\"\$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip\"
			OBJCOPY=\"\$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-objcopy\"
			OBJDUMP=\"\$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-objdump\"

			cd /work
			make -C src clean >/dev/null 2>&1 || true
			make -C src \
				PROOT_DISABLE_LOADER_32BIT=1 \
				CC=\"\$CC\" \
				LD=\"\$CC\" \
				STRIP=\"\$STRIP\" \
				OBJCOPY=\"\$OBJCOPY\" \
				OBJDUMP=\"\$OBJDUMP\" \
				CPPFLAGS='-D_FILE_OFFSET_BITS=64 -D_GNU_SOURCE -I. -I./ -I/tmp/talloc-${TALLOC_VERSION}' \
				TALLOC_LIBS='/tmp/android-talloc/pkg/data/data/com.termux/files/usr/lib/libtalloc.a' \
				LDFLAGS='-static-pie -Wl,-z,noexecstack' \
				proot
			mkdir -p /work/dist/android-${arch}
			cp src/proot /work/dist/android-${arch}/proot
			file /work/dist/android-${arch}/proot
		"
}

run_linux_build linux/amd64 x86_64
run_linux_build linux/386 x86
run_linux_build linux/arm64 arm64
run_linux_build linux/arm/v7 arm

run_android_build x86_64 x86_64-linux-android 21 x86_64 x86_64
run_android_build x86 i686-linux-android 16 i686 i686
run_android_build arm64 aarch64-linux-android 21 aarch64 aarch64
run_android_build arm armv7a-linux-androideabi 16 arm armv7l
