IMAGE=cs412-libpng-fuzz
LIBPNG_DIR=third_party/libpng-1.2.56
PATCH=patches/libpng-nocrc.patch
HARNESS=png_fuzz

SEEDS=seeds
DICT=dictionaries/png.dict
FINDINGS=findings
PLOT_OUTPUT=plot_output

PATCH_SYNTHETIC=patches/synthetic-bug.patch

.PHONY: build-docker patch-libpng build-libpng build-harness build fuzz plot clean

build-docker:
	docker build -t $(IMAGE) .

patch-libpng:
	docker run --rm -v "$$(pwd)":/work $(IMAGE) bash -lc '\
		cd /work/$(LIBPNG_DIR) && \
		patch --forward -p0 < /work/$(PATCH) || true'

build-libpng:
	docker run --rm -v "$$(pwd)":/work $(IMAGE) bash -lc '\
		cd /work/$(LIBPNG_DIR) && \
		make distclean || true && \
		CC=afl-clang-fast CXX=afl-clang-fast++ \
		CFLAGS="-fsanitize=address -g -O1" \
		LDFLAGS="-fsanitize=address" \
		./configure --disable-shared --prefix=/work/build/install && \
		make -j$$(nproc) && \
		make install'

build-harness:
	docker run --rm -v "$$(pwd)":/work $(IMAGE) bash -lc '\
		afl-clang-fast /work/src/harness.c \
		-I/work/build/install/include \
		-L/work/build/install/lib \
		-lpng12 -lz -lm \
		-fsanitize=address -g -O1 \
		-o /work/$(HARNESS)'


build: build-docker patch-libpng build-libpng build-harness


fuzz:
	docker run --rm -it -v "$$(pwd)":/work $(IMAGE) bash -lc '\
		afl-fuzz -i /work/$(SEEDS) \
		-o /work/$(FINDINGS) \
		-x /work/$(DICT) \
		-- /work/$(HARNESS) @@'

patch-bug:
	docker run --rm -v "$$(pwd)":/work $(IMAGE) bash -lc '\
		cd /work/$(LIBPNG_DIR) && \
		patch --forward -p0 < /work/$(PATCH_SYNTHETIC) || true'

unpatch-bug:
	docker run --rm -v "$$(pwd)":/work $(IMAGE) bash -lc '\
		cd /work/$(LIBPNG_DIR) && \
		patch --reverse -p0 < /work/$(PATCH_SYNTHETIC) || true'

build-bug: build-docker patch-libpng patch-bug build-libpng build-harness


# For QEMU mode, we need a copy of the libng compiled with standard complier (gcc) or plain clang, without asan or afl 
VANILLA_INSTALL=build-qemu/install

build-libpng-vanilla:
	docker run --rm -v "$$(pwd)":/work $(IMAGE) bash -lc '\
		cd /work/$(LIBPNG_DIR) && \
		make distclean || true && \
		CC=gcc CFLAGS="-g -O1" \
		./configure --disable-shared --prefix=/work/$(VANILLA_INSTALL) && \
		make -j$$(nproc) && \
		make install'
#h arness compiled against vanilla library 
HARNESS_QEMU=png_fuzz_qemu

build-harness-qemu:
	docker run --rm -v "$$(pwd)":/work $(IMAGE) bash -lc '\
		gcc /work/src/harness.c \
		-I/work/$(VANILLA_INSTALL)/include \
		-L/work/$(VANILLA_INSTALL)/lib \
		-lpng12 -lz -lm \
		-g -O1 \
		-o /work/$(HARNESS_QEMU)'

# QEMU mode fuzzing 
FINDINGS_QEMU=findings-qemu

fuzz-qemu:
	docker run --rm -it -v "$$(pwd)":/work $(IMAGE) bash -lc '\
		afl-fuzz -Q \
		-i /work/$(SEEDS) \
		-o /work/$(FINDINGS_QEMU) \
		-x /work/$(DICT) \
		-- /work/$(HARNESS_QEMU) @@'