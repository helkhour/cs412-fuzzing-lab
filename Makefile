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