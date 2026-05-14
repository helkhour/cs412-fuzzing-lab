IMAGE=cs412-libpng-fuzz
LIBPNG_DIR=third_party/libpng-1.2.56
LIBPNG_TARBALL=libpng-1.2.56.tar.gz
LIBPNG_URL=https://download.sourceforge.net/libpng/$(LIBPNG_TARBALL)
PATCH=patches/libpng-nocrc.patch
HARNESS=png_fuzz
DOCKER_RUN=docker run --rm -v "$$(pwd)":/work
DOCKER_RUN_TTY=docker run --rm -it -v "$$(pwd)":/work

SEEDS=seeds
DICT=dictionaries/png.dict
FINDINGS=findings
PLOT_OUTPUT=plot_output

PATCH_SYNTHETIC=patches/synthetic-bug.patch

<<<<<<< HEAD
.PHONY: check-docker build-docker setup-libpng patch-libpng build-libpng build-harness build fuzz plot clean setup-qemu build-libpng-vanilla build-harness-qemu smoke-qemu fuzz-qemu fuzz-qemu-resume clean-qemu plot-qemu
=======
.PHONY: check-docker build-docker download-libpng patch-libpng build-libpng build-harness build fuzz plot clean setup-qemu build-libpng-vanilla build-harness-qemu smoke-qemu fuzz-qemu fuzz-qemu-resume clean-qemu plot-qemu
>>>>>>> bc20eb90cc85ff9f2295103ff4f48369146090fa

check-docker:
	@docker info >/dev/null

build-docker: check-docker
	docker build -t $(IMAGE) .

<<<<<<< HEAD
setup-libpng: build-docker
	$(DOCKER_RUN) $(IMAGE) bash -lc '\
		mkdir -p /work/third_party && \
		cd /work/third_party && \
		test -d libpng-1.2.56 || { \
			test -f $(LIBPNG_TARBALL) || wget -O $(LIBPNG_TARBALL) $(LIBPNG_URL); \
			tar xf $(LIBPNG_TARBALL); \
		}'

patch-libpng: setup-libpng
=======
download-libpng:
	mkdir -p third_party && \
	wget -O third_party/libpng-1.2.56.tar.gz \
		https://download.sourceforge.net/libpng/libpng-1.2.56.tar.gz && \
	tar xf third_party/libpng-1.2.56.tar.gz -C third_party/

patch-libpng:
>>>>>>> bc20eb90cc85ff9f2295103ff4f48369146090fa
	$(DOCKER_RUN) $(IMAGE) bash -lc '\
		cd /work/$(LIBPNG_DIR) && \
		patch --forward -p0 < /work/$(PATCH) || \
		patch --reverse --dry-run -p0 < /work/$(PATCH) >/dev/null'

build-libpng:
	$(DOCKER_RUN) $(IMAGE) bash -lc '\
		cd /work/$(LIBPNG_DIR) && \
		make distclean || true && \
		CC=afl-clang-fast CXX=afl-clang-fast++ \
		CFLAGS="-fsanitize=address -g -O1" \
		LDFLAGS="-fsanitize=address" \
		./configure --disable-shared --prefix=/work/build/install && \
		make -j$$(nproc) && \
		make install'

build-harness:
	$(DOCKER_RUN) $(IMAGE) bash -lc '\
		afl-clang-fast /work/src/harness.c \
		-I/work/build/install/include \
		-L/work/build/install/lib \
		-lpng12 -lz -lm \
		-fsanitize=address -g -O1 \
		-o /work/$(HARNESS)'


build: build-docker download-libpng patch-libpng build-libpng build-harness


fuzz:
	$(DOCKER_RUN_TTY) $(IMAGE) bash -lc '\
		AFL_SKIP_CPUFREQ=1 afl-fuzz -i /work/$(SEEDS) \
		-o /work/$(FINDINGS) \
		-x /work/$(DICT) \
		-- /work/$(HARNESS) @@'

patch-bug:
	$(DOCKER_RUN) $(IMAGE) bash -lc '\
		cd /work/$(LIBPNG_DIR) && \
		patch --forward -p0 < /work/$(PATCH_SYNTHETIC) || \
		patch --reverse --dry-run -p0 < /work/$(PATCH_SYNTHETIC) >/dev/null'

unpatch-bug:
	$(DOCKER_RUN) $(IMAGE) bash -lc '\
		cd /work/$(LIBPNG_DIR) && \
		patch --reverse -p0 < /work/$(PATCH_SYNTHETIC) || true'

build-bug: build-docker patch-libpng patch-bug build-libpng build-harness


# For QEMU mode, we need a copy of the libng compiled with standard complier (gcc) or plain clang, without asan or afl 
VANILLA_INSTALL=build-qemu/install
HARNESS_QEMU=png_fuzz_qemu
FINDINGS_QEMU=findings-qemu

build-libpng-vanilla:
	$(DOCKER_RUN) $(IMAGE) bash -lc '\
		cd /work/$(LIBPNG_DIR) && \
		make distclean || true && \
		CC=gcc CFLAGS="-g -O1" \
		./configure --disable-shared --prefix=/work/$(VANILLA_INSTALL) && \
		make -j$$(nproc) && \
		make install'


build-harness-qemu:
	$(DOCKER_RUN) $(IMAGE) bash -lc '\
		gcc /work/src/harness.c \
		-I/work/$(VANILLA_INSTALL)/include \
		-L/work/$(VANILLA_INSTALL)/lib \
		-lpng12 -lz -lm \
		-g -O1 \
		-o /work/$(HARNESS_QEMU)'

setup-qemu: build-docker patch-libpng build-libpng-vanilla build-harness-qemu

smoke-qemu:
	$(DOCKER_RUN) $(IMAGE) bash -lc '\
		file /work/$(HARNESS_QEMU) && \
		/work/$(HARNESS_QEMU) /work/$(SEEDS)/ct1n0g04.png'

fuzz-qemu:
	$(DOCKER_RUN_TTY) $(IMAGE) bash -lc '\
		test ! -e /work/$(FINDINGS_QEMU) || \
		{ echo "Refusing to overwrite /work/$(FINDINGS_QEMU). Run make clean-qemu or make fuzz-qemu-resume."; exit 2; }; \
		AFL_SKIP_CPUFREQ=1 afl-fuzz -Q \
		-i /work/$(SEEDS) \
		-o /work/$(FINDINGS_QEMU) \
		-x /work/$(DICT) \
		-- /work/$(HARNESS_QEMU) @@'

fuzz-qemu-resume:
	$(DOCKER_RUN_TTY) $(IMAGE) bash -lc '\
		AFL_AUTORESUME=1 AFL_SKIP_CPUFREQ=1 afl-fuzz -Q \
		-i /work/$(SEEDS) \
		-o /work/$(FINDINGS_QEMU) \
		-x /work/$(DICT) \
		-- /work/$(HARNESS_QEMU) @@'

clean-qemu:
	rm -rf $(FINDINGS_QEMU) plot_output_qemu
	
plot-qemu:
	$(DOCKER_RUN) $(IMAGE) bash -lc '\
		afl-plot /work/$(FINDINGS_QEMU)/default/ /work/plot_output_qemu/'

clean:
	rm -rf build build-qemu $(HARNESS) $(HARNESS_QEMU) $(FINDINGS) $(FINDINGS_QEMU) plot_output plot_output_qemu
