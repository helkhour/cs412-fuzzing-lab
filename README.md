# CS-412 Fuzzing Lab - libpng

## Prerequisites

- [Docker](https://www.docker.com/) installed and running

---

## Project Structure

```text
team4-cs412-fuzzing-libpng/
├── Dockerfile
├── Makefile
├── README.md
├── src/                  # fuzzing harness source
├── seeds/                # input seed corpus
├── dictionaries/         # AFL++ PNG dictionary
├── patches/              # CRC removal patch + synthetic bug patch
├── third_party/          # libpng 1.2.56 source (downloaded, not committed)
├── build/                # instrumented build output (generated)
├── build-qemu/           # vanilla build output for QEMU mode (generated)
├── findings/             # AFL++ output — white-box campaign (generated)
├── findings-qemu/        # AFL++ output — QEMU campaign (generated)
├── plot_output/          # afl-plot graphs — white-box (generated)
└── plot_output_qemu/     # afl-plot graphs — QEMU (generated)
```

---

## Configuration

- **Target:** libpng
- **Version:** 1.2.56
- **Reason:** compatible with the AFL++ CRC-removal patch and contains known CVEs (e.g. CVE-2016-10087)

---

## Step 1 — Build the Docker Image

```bash
make build-docker
```

This builds the Docker image containing AFL++, all required compilers, and dependencies.

---

## Step 2 — Download libpng 1.2.56

```bash
make download-libpng
```

This downloads and extracts libpng 1.2.56 into `third_party/`. This only needs to be run once.

---

## Step 3 — Apply the CRC Patch

```bash
make patch-libpng
```

This applies the AFL++ CRC-removal patch to libpng 1.2.56. Without this patch, the fuzzer cannot explore deep code paths because every mutation fails the CRC check immediately. This only needs to be run once.

---

## Step 4 — Build Instrumented libpng (White-box)

```bash
make build-libpng
```

Compiles libpng 1.2.56 as a static library with:
- AFL++ instrumentation (`afl-clang-fast`)
- AddressSanitizer (`-fsanitize=address`)
- Debug symbols (`-g -O1`)

---

## Step 5 — Build the Fuzzing Harness (White-box)

```bash
make build-harness
```

Compiles the fuzzing harness (`src/harness.c`) against the instrumented static libpng, also with ASan enabled.

---

## Step 6 — Run the White-box Fuzzing Campaign

> **Important:** The `findings/` directory must not exist before running. If it does, delete it first:
> ```bash
> rm -rf findings/
> ```

```bash
make fuzz
```

Starts AFL++ with:
- Seeds from `seeds/`
- Dictionary from `dictionaries/png.dict`
- Output to `findings/`

Let it run for **at least 30 minutes**. Stop with `Ctrl+C`.

---

## Step 7 — Generate White-box Plots

```bash
docker run --rm -v "$(pwd)":/work cs412-libpng-fuzz bash -lc \
  'apt-get update -qq && apt-get install -y gnuplot-nox -qq && \
   afl-plot /work/findings/default /work/plot_output'
```

Plots are saved to `plot_output/`.

---

## Step 8 — Build Vanilla libpng (QEMU / Black-box)

```bash
make build-libpng-vanilla
```

Compiles a second copy of libpng 1.2.56 with plain `gcc`, no AFL++ instrumentation and no ASan. This simulates a closed-source binary.

---

## Step 9 — Build the QEMU Harness

```bash
make build-harness-qemu
```

Compiles the fuzzing harness against the vanilla (uninstrumented) libpng using plain `gcc`.

---

## Step 10 — Smoke Test the QEMU Harness

```bash
make smoke-qemu
```

Runs the QEMU harness against a valid seed to confirm it works before fuzzing.

---

## Step 11 — Run the QEMU Fuzzing Campaign

> **Important:** The `findings-qemu/` directory must not exist before running. If it does, either delete it or use `make fuzz-qemu-resume` to continue from where you left off:
> ```bash
> rm -rf findings-qemu/   # start fresh
> # OR
> make fuzz-qemu-resume   # continue previous campaign
> ```

```bash
make fuzz-qemu
```

Starts AFL++ in QEMU mode (`-Q`) with:
- Seeds from `seeds/`
- Dictionary from `dictionaries/png.dict`
- Output to `findings-qemu/`

Let it run for **at least 30 minutes**. Stop with `Ctrl+C`.

---

## Step 12 — Generate QEMU Plots

```bash
make plot-qemu
```

Plots are saved to `plot_output_qemu/`.

---

## Synthetic Bug (Q5 — only if no crashes were found)

If your campaign finds no crashes, you must inject a synthetic bug to prove your setup works, then remove it afterwards.

Apply the synthetic bug patch and rebuild:

```bash
make patch-bug
make build-libpng
make build-harness
```

Run the fuzzer for at least 60 seconds and confirm AFL++ detects the crash:

```bash
make fuzz
```

Remove the synthetic bug patch and rebuild cleanly:

```bash
make unpatch-bug
make build-libpng
make build-harness
```

---

## Cleanup

Remove all build artifacts, findings, and plots:

```bash
make clean
```

Remove only QEMU findings and plots:

```bash
make clean-qemu
```
