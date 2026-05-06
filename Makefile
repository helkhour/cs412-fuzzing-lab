IMAGE=cs412-libpng-fuzz
LIBPNG_DIR=third_party/libpng-1.2.56
PATCH=patches/libpng-nocrc.patch
HARNESS=png_fuzz

SEEDS=seeds
DICT=dictionaries/png.dict
FINDINGS=findings
PLOT_OUTPUT=plot_output

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
		AFL_SKIP_CPUFREQ=1 AFL_AUTORESUME=1 \
		afl-fuzz -i /work/$(SEEDS) \
		-o /work/$(FINDINGS) \
		-x /work/$(DICT) \
		-- /work/$(HARNESS) @@'

plot:
	docker run --rm -v "$$(pwd)":/work $(IMAGE) bash -lc '\
		afl-plot /work/$(FINDINGS)/default /work/$(PLOT_OUTPUT)'

clean:
	docker run --rm -v "$$(pwd)":/work $(IMAGE) bash -lc '\
		rm -rf /work/build /work/findings /work/plot_output && \
		rm -f /work/$(HARNESS) && \
		rm -f /work/third_party/libpng-1.2.56/*.orig && \
		rm -f /work/third_party/libpng-1.2.56/*.rej'


