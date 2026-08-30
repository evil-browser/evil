# Performance

Three levers, in order of how much they actually matter:

1. **The build itself** — LTO, PGO, and instruction-set targeting.
2. **What is compiled out** — every removed service is code that never runs.
3. **Runtime policy** — tab freezing, discarding, and process caps.

Only the first is configuration. The other two are the patch set and the
hardening payload, covered in [PATCHES.md](PATCHES.md) and
[HARDENING.md](HARDENING.md).

## Build profiles

`build/args/performance.gni` is applied on top of `release.gni`:

| Argument | Effect |
| --- | --- |
| `use_thin_lto`, `thin_lto_enable_optimizations` | Cross-module inlining. Costs link time, buys startup and throughput. |
| `chrome_pgo_phase = 2` | Uses upstream's profile data. Worth roughly 10% on real page loads and is free. |
| `optimize_webui` | Bundles and minifies the internal pages. Smaller binary, faster settings UI. |
| `use_text_section_splitting` | Hot/cold code separation. Better instruction locality on startup. |
| `v8_enable_maglev`, `v8_enable_sparkplug` | V8's mid-tier compilers. Faster warm-up on script-heavy pages. |
| `enable_iterator_debugging = false` | Drops libc++ debug checks from release. |
| `extra_cflags = -march=x86-64-v2` | SSE4.2 and POPCNT. Every x86-64 CPU since about 2009. |

### Instruction sets

The default targets **x86-64-v2**, which is safe on anything from Nehalem
onwards. A build targeting **x86-64-v3** (AVX2, BMI2, FMA — Haswell 2013 and
later) is measurably faster on media decode and canvas work, and crashes with
`SIGILL` on anything older.

```sh
cp build/args/performance-avx2.gni build/args/local.gni
make build
```

Ship v3 as a *separate, clearly labelled* artefact if you ship it at all. A user
who downloads the default build and gets an illegal instruction has no way to
diagnose it.

On arm64 both files are ignored; there is no equivalent split worth making.

### What is deliberately not disabled

`is_cfi` stays on. Control Flow Integrity costs a small amount of throughput and
is one of the few mitigations that turns a large class of memory-safety bugs
into a crash instead of an exploit. Forks that disable it for benchmark numbers
are trading your security for a bar chart.

## Measuring

Do not trust a stopwatch. Before and after any change:

```sh
out/release/chrome --user-data-dir=/tmp/bench \
  --enable-benchmarking --enable-net-benchmarking \
  --no-first-run --window-size=1440,900
```

- **Startup:** `chrome://startup` or `--enable-tracing=startup`
- **Memory:** `chrome://memory-internals`, measured after five minutes idle with
  a fixed tab set, not immediately after launch
- **Page load:** Speedometer 3 and JetStream 2, three runs, take the median

Record the numbers in the pull request. A performance change without before and
after figures from the same machine is an opinion.

## Runtime

Tab freezing, discarding and the low-memory path are patch-set work and are
listed in [../patches/PLANNED.md](../patches/PLANNED.md) under features. Until
those land, the build inherits upstream's defaults, which are conservative:
Chromium will happily keep sixty renderer processes alive if you have the RAM.
