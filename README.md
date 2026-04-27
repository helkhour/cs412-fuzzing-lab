# CS-412 Fuzzing Lab 
---

## Project Structure
```text
team4-cs412-fuzzing-libpng/
├── Dockerfile
├── Makefile
├── README.md
├── src/ # harness (to be implemented)
├── seeds/ # input seeds
├── dictionaries/ # AFL dictionaries
├── patches/ # libpng patches (CRC removal)
├── third_party/ # libpng source
├── build/ # (later) instrumented build
├── build-qemu/ # (later) vanilla build

```

---

##  Configuration

- Target: **libpng**
- Version: **1.2.56**
- Reason: compatible with AFL++ CRC patch and stable for fuzzing

---

## Docker Setup

### Build the image
```bash
docker build -t cs412-libpng-fuzz .
```
### Run the container
```bash
docker run --rm -it -v "$(pwd)":/work cs412-libpng-fuzz bash
```
### Inside the Container
#### Check AFL++ installation
```bash
which afl-fuzz
which afl-clang-fast
```

### Download libpng
```bash
cd /work/third_party
wget https://download.sourceforge.net/libpng/libpng-1.2.56.tar.gz
tar xf libpng-1.2.56.tar.gz
```


## CRC Patch

We use the AFL++ CRC-removal patch for libpng 1.2.56.

To apply the CRC patch:

```bash
make patch-libpng
```

## Instrumented libpng build

We compile **libpng 1.2.56** with **AFL++ instrumentation** and **AddressSanitizer (ASan)**.

To build the instrumented static library:

```bash
make build-libpng
```


## Harness Build

We compile the fuzzing harness against the instrumented static libpng.

To build the harness:

```bash
make build-harness
```
