For reference purpose, keep this for use on morning of 17 June 2025

```zsh
dev@ubuntu:~$ cargo --version
cargo 1.87.0 (99624be96 2025-05-06)
dev@ubuntu:~$ git clone https://github.com/vatsalkeshav/runwasi-wasmedge-demo.git
Cloning into 'runwasi-wasmedge-demo'...
remote: Enumerating objects: 18, done.
remote: Counting objects: 100% (18/18), done.
remote: Compressing objects: 100% (11/11), done.
remote: Total 18 (delta 3), reused 17 (delta 2), pack-reused 0 (from 0)
Receiving objects: 100% (18/18), 6.40 KiB | 6.40 MiB/s, done.
Resolving deltas: 100% (3/3), done.
dev@ubuntu:~$ cd runwasi-wasmedge-demo/
dev@ubuntu:~/runwasi-wasmedge-demo$ git submodule update --init --recursive
Submodule 'apps/llamaedge' (https://github.com/LlamaEdge/LlamaEdge.git) registered for path 'apps/llamaedge'
Cloning into '/home/dev/runwasi-wasmedge-demo/apps/llamaedge'...
Submodule path 'apps/llamaedge': checked out '05f3349ab66ecdf67bdf3ba6ead516b4e6fd66d7'
dev@ubuntu:~/runwasi-wasmedge-demo$ git -C apps/llamaedge apply $PWD/disable_wasi_logging.patch
dev@ubuntu:~/runwasi-wasmedge-demo$ git -C apps/llamaedge apply $PWD/disable_wasi_logging.patch
          OPT_PROFILE=release RUSTFLAGS="--cfg wasmedge --cfg tokio_unstable" make apps/llamaedge/llama-api-server
error: patch failed: llama-api-server/src/main.rs:536
error: llama-api-server/src/main.rs: patch does not apply
Build WASM from apps/llamaedge/llama-api-server
    Updating git repository `https://github.com/second-state/wasi_hyper.git`
    Updating git repository `https://github.com/second-state/wasi_reqwest.git`
    Updating git repository `https://github.com/second-state/socket2.git`
    Updating git repository `https://github.com/second-state/wasi_tokio.git`
    Updating crates.io index
    Updating git repository `https://github.com/second-state/wasi_mio.git`
     Locking 429 packages to latest compatible versions
      Adding image v0.25.0 (available: v0.25.6)
      Adding text-splitter v0.7.0 (available: v0.27.0)
      Adding thiserror v1.0.69 (available: v2.0.12)
      Adding tiktoken-rs v0.5.9 (available: v0.7.0)
      Adding wasi v0.10.0+wasi-snapshot-preview1 (available: v0.10.2+wasi-snapshot-preview1)
  Downloaded aligned-vec v0.6.4
  Downloaded arg_enum_proc_macro v0.3.4
  Downloaded byteorder v1.5.0
  Downloaded anstyle-parse v0.2.7
  Downloaded bit-vec v0.6.3
  Downloaded anyhow v1.0.98
  Downloaded autocfg v0.1.8
  Downloaded chrono-tz-build v0.3.0
  Downloaded anstyle v1.0.11
  Downloaded bit-set v0.5.3
  Downloaded block-buffer v0.10.4
  Downloaded equivalent v1.0.2
  Downloaded color_quant v1.1.0
  Downloaded equator-macro v0.4.2
  Downloaded bit_field v0.10.2
  Downloaded derive_utils v0.15.0
  Downloaded http-body v0.4.6
  Downloaded crypto-common v0.1.6
  Downloaded safemem v0.3.3
  Downloaded anstyle-query v1.1.3
  Downloaded futures-sink v0.3.31
  Downloaded generic-array v0.14.7
  Downloaded heck v0.5.0
  Downloaded autocfg v1.4.0
  Downloaded globwalk v0.9.1
  Downloaded avif-serialize v0.8.3
  Downloaded form_urlencoded v1.2.1
  Downloaded byteorder-lite v0.1.0
  Downloaded futures-task v0.3.31
  Downloaded futures-macro v0.3.31
  Downloaded sync_wrapper v0.1.2
  Downloaded fastrand v2.3.0
  Downloaded slug v0.1.6
  Downloaded rand_os v0.1.3
  Downloaded gif v0.13.1
  Downloaded arrayvec v0.7.6
  Downloaded fdeflate v0.3.7
  Downloaded ravif v0.11.12
  Downloaded built v0.7.7
  Downloaded phf_codegen v0.11.3
  Downloaded cfg-if v1.0.1
  Downloaded tower-service v0.3.3
  Downloaded clap_derive v4.5.40
  Downloaded serde_urlencoded v0.7.1
  Downloaded bitflags v1.3.2
  Downloaded getrandom v0.2.16
  Downloaded hyper-rustls v0.24.2
  Downloaded pin-utils v0.1.0
  Downloaded iana-time-zone v0.1.63
  Downloaded bitflags v2.9.1
  Downloaded enum_dispatch v0.3.13
  Downloaded displaydoc v0.2.5
  Downloaded futures-channel v0.3.31
  Downloaded crc32fast v1.4.2
  Downloaded anstream v0.6.19
  Downloaded erased-serde v0.4.6
  Downloaded av1-grain v0.2.4
  Downloaded httpdate v1.0.3
  Downloaded heck v0.4.1
  Downloaded clap_lex v0.7.5
  Downloaded buf_redux v0.8.4
  Downloaded simd_helpers v0.1.0
  Downloaded humansize v2.1.3
  Downloaded dns-parser v0.8.0
  Downloaded futures-io v0.3.31
  Downloaded futures-core v0.3.31
  Downloaded fnv v1.0.7
  Downloaded errno v0.3.12
  Downloaded either v1.15.0
  Downloaded cpufeatures v0.2.17
  Downloaded equator v0.4.2
  Downloaded digest v0.10.7
  Downloaded colorchoice v1.0.4
  Downloaded adler2 v2.0.1
  Downloaded crossbeam-deque v0.8.6
  Downloaded rand_chacha v0.1.1
  Downloaded clap v4.5.40
  Downloaded bitstream-io v2.6.0
  Downloaded auto_enums v0.8.7
  Downloaded getrandom v0.3.3
  Downloaded bytemuck v1.23.1
  Downloaded ppv-lite86 v0.2.21
  Downloaded httparse v1.10.1
  Downloaded half v2.6.0
  Downloaded globset v0.4.16
  Downloaded futures v0.3.31
  Downloaded crossbeam-utils v0.8.21
  Downloaded crossbeam-epoch v0.9.18
  Downloaded rand_core v0.4.2
  Downloaded want v0.3.1
  Downloaded quote v1.0.40
  Downloaded rand_jitter v0.1.4
  Downloaded rand_isaac v0.1.1
  Downloaded flate2 v1.1.2
  Downloaded bytes v1.10.1
  Downloaded bumpalo v3.18.1
  Downloaded base64 v0.22.1
  Downloaded base64 v0.21.7
  Downloaded http v0.2.12
  Downloaded zune-core v0.4.12
  Downloaded wit-bindgen-core v0.24.0
  Downloaded cc v1.2.27
  Downloaded wasm-bindgen-shared v0.2.100
  Downloaded wasm-bindgen v0.2.100
  Downloaded hashbrown v0.15.4
  Downloaded zune-inflate v0.2.54
  Downloaded itoa v1.0.15
  Downloaded h2 v0.3.26
  Downloaded is_terminal_polyfill v1.70.1
  Downloaded clap_builder v4.5.40
  Downloaded futures-util v0.3.31
  Downloaded aho-corasick v1.1.3
  Downloaded deunicode v1.6.2
  Downloaded ignore v0.4.23
  Downloaded exr v1.73.0
  Downloaded chrono v0.4.41
  Downloaded chrono-tz v0.9.0
  Downloaded bstr v1.12.0
  Downloaded scopeguard v1.2.0
  Downloaded rustls-pemfile v1.0.4
  Downloaded regex-syntax v0.8.5
  Downloaded rand_chacha v0.3.1
  Downloaded matches v0.1.10
  Downloaded same-file v1.0.6
  Downloaded rustc-hash v1.1.0
  Downloaded rgb v0.8.50
  Downloaded rand_chacha v0.9.0
  Downloaded tinyvec_macros v0.1.1
  Downloaded try-lock v0.2.5
  Downloaded rand_core v0.3.1
  Downloaded pest_generator v2.8.1
  Downloaded mime v0.3.17
  Downloaded traitobject v0.1.1
  Downloaded typemap v0.3.3
  Downloaded unsafe-any v0.4.2
  Downloaded unic-common v0.9.0
  Downloaded unic-char-range v0.9.0
  Downloaded unic-ucd-version v0.9.0
  Downloaded pulldown-cmark v0.10.3
  Downloaded value-bag-sval2 v1.11.1
  Downloaded unicode-xid v0.2.6
  Downloaded unic-char-property v0.9.0
  Downloaded uuid-macro-internal v1.17.0
  Downloaded pest_derive v2.8.1
  Downloaded mime_guess v2.0.5
  Downloaded serde_fmt v1.0.3
  Downloaded shlex v1.3.0
  Downloaded simd-adler32 v0.3.7
  Downloaded strsim v0.11.1
  Downloaded stable_deref_trait v1.2.0
  Downloaded rustversion v1.0.21
  Downloaded slab v0.4.10
  Downloaded siphasher v1.0.1
  Downloaded zerofrom v0.1.6
  Downloaded thiserror-impl v2.0.12
  Downloaded thiserror v1.0.69
  Downloaded sval_json v2.14.1
  Downloaded sval_dynamic v2.14.1
  Downloaded sval_buffer v2.14.1
  Downloaded siphasher v0.2.3
  Downloaded sval_serde v2.14.1
  Downloaded sval_nested v2.14.1
  Downloaded thiserror-impl v1.0.69
  Downloaded untrusted v0.9.0
  Downloaded regex-automata v0.4.9
  Downloaded value-bag-serde1 v1.11.1
  Downloaded synstructure v0.13.2
  Downloaded version_check v0.9.5
  Downloaded typeid v1.0.3
  Downloaded wasm-bindgen-backend v0.2.100
  Downloaded v_frame v0.3.9
  Downloaded utf8parse v0.2.2
  Downloaded utf8_iter v1.0.4
  Downloaded twoway v0.1.8
  Downloaded time v0.1.45
  Downloaded walkdir v2.5.0
  Downloaded sval_ref v2.14.1
  Downloaded semver v1.0.26
  Downloaded sha2 v0.10.9
  Downloaded sct v0.7.1
  Downloaded potential_utf v0.1.2
  Downloaded thiserror v2.0.12
  Downloaded lock_api v0.4.13
  Downloaded tokio-rustls v0.24.1
  Downloaded tinystr v0.8.1
  Downloaded lazy_static v1.5.0
  Downloaded unicase v1.4.2
  Downloaded typeable v0.1.2
  Downloaded version_check v0.1.5
  Downloaded new_debug_unreachable v1.0.6
  Downloaded sval_fmt v2.14.1
  Downloaded unicase v2.8.1
  Downloaded unic-ucd-segment v0.9.0
  Downloaded unic-segment v0.9.0
  Downloaded wasm-bindgen-macro v0.2.100
  Downloaded ryu v1.0.20
  Downloaded smallvec v1.15.1
  Downloaded leb128 v0.2.5
  Downloaded lebe v0.5.2
  Downloaded serde_derive v1.0.219
  Downloaded zerofrom-derive v0.1.6
  Downloaded rand_core v0.6.4
  Downloaded sval v2.14.1
  Downloaded log v0.3.9
  Downloaded tempfile v3.20.0
  Downloaded writeable v0.6.1
  Downloaded wasm-bindgen-macro-support v0.2.100
  Downloaded ucd-trie v0.1.7
  Downloaded tinyvec v1.9.0
  Downloaded noop_proc_macro v0.3.0
  Downloaded unicode-ident v1.0.18
  Downloaded phf_generator v0.7.24
  Downloaded quick-error v1.2.3
  Downloaded quick-error v2.0.1
  Downloaded value-bag v1.11.1
  Downloaded phf_shared v0.7.24
  Downloaded serde_yaml v0.9.34+deprecated
  Downloaded num_cpus v1.17.0
  Downloaded tracing-core v0.1.34
  Downloaded phf_generator v0.11.3
  Downloaded serde v1.0.219
  Downloaded profiling v1.0.16
  Downloaded litemap v0.8.0
  Downloaded num-rational v0.4.2
  Downloaded num-traits v0.2.19
  Downloaded encoding_rs v0.8.35
  Downloaded paste v1.0.15
  Downloaded url v1.7.2
  Downloaded ipnet v2.11.0
  Downloaded uuid v1.17.0
  Downloaded unsafe-libyaml v0.2.11
  Downloaded pest_meta v2.8.1
  Downloaded icu_provider v2.0.0
  Downloaded unicode-bidi v0.3.18
  Downloaded text-splitter v0.7.0
  Downloaded phf_codegen v0.7.24
  Downloaded log v0.4.27
  Downloaded proc-macro2 v1.0.95
  Downloaded weezl v0.1.10
  Downloaded tiny_http v0.6.4
  Downloaded num-derive v0.4.2
  Downloaded tracing v0.1.41
  Downloaded typenum v1.18.0
  Downloaded id-arena v2.2.1
  Downloaded idna_adapter v1.2.1
  Downloaded phf v0.11.3
  Downloaded icu_collections v2.0.0
  Downloaded pin-project-lite v0.2.16
  Downloaded wit-bindgen-rust-macro v0.24.0
  Downloaded mime v0.2.6
  Downloaded wasmedge_stable_diffusion v0.3.2
  Downloaded url v2.5.4
  Downloaded tera v1.20.0
  Downloaded icu_normalizer v2.0.0
  Downloaded image-webp v0.1.3
  Downloaded wasmedge_wasi_socket v0.5.5
  Downloaded wasi v0.10.0+wasi-snapshot-preview1
  Downloaded icu_properties v2.0.1
  Downloaded unicode-segmentation v1.12.0
  Downloaded yoke-derive v0.8.0
  Downloaded tokio-util v0.7.15
  Downloaded wasi v0.11.1+wasi-snapshot-preview1
  Downloaded yoke v0.8.0
  Downloaded serde_json v1.0.140
  Downloaded png v0.17.16
  Downloaded unicode-normalization v0.1.24
  Downloaded icu_locale_core v2.0.0
  Downloaded rustls-webpki v0.101.7
  Downloaded parking_lot_core v0.9.11
  Downloaded phf v0.7.24
  Downloaded percent-encoding v2.3.1
  Downloaded phf_shared v0.11.3
  Downloaded itertools v0.12.1
  Downloaded rand_pcg v0.1.2
  Downloaded rand_hc v0.1.0
  Downloaded rand_core v0.9.3
  Downloaded wit-bindgen v0.24.0
  Downloaded zerovec-derive v0.11.1
  Downloaded zune-jpeg v0.4.17
  Downloaded jobserver v0.1.33
  Downloaded percent-encoding v1.0.1
  Downloaded loop9 v0.1.5
  Downloaded maybe-rayon v0.1.1
  Downloaded wasmparser v0.202.0
  Downloaded rustls v0.21.12
  Downloaded miniz_oxide v0.8.9
  Downloaded libm v0.2.15
  Downloaded language-tags v0.2.2
  Downloaded syn v2.0.103
  Downloaded profiling-procmacros v1.0.16
  Downloaded base64 v0.9.3
  Downloaded rand v0.8.5
  Downloaded rand v0.9.1
  Downloaded minimal-lexical v0.2.1
  Downloaded parking_lot v0.12.4
  Downloaded chunked_transfer v0.3.1
  Downloaded rand_xorshift v0.1.1
  Downloaded rustix v1.0.7
  Downloaded groupable v0.2.0
  Downloaded once_cell v1.21.3
  Downloaded wit-bindgen-rt v0.24.0
  Downloaded num-integer v0.1.46
  Downloaded wasm-encoder v0.202.0
  Downloaded wasm-metadata v0.202.0
  Downloaded plugin v0.2.6
  Downloaded wasi-logger v0.1.2
  Downloaded modifier v0.1.0
  Downloaded ascii v0.8.7
  Downloaded indexmap v2.9.0
  Downloaded wit-bindgen-rust v0.24.0
  Downloaded mime_guess v1.8.8
  Downloaded zerovec v0.11.2
  Downloaded mustache v0.9.0
  Downloaded imgref v1.11.0
  Downloaded zerotrie v0.2.2
  Downloaded wit-parser v0.202.0
  Downloaded idna v0.1.5
  Downloaded wasmedge-wasi-nn v0.8.0
  Downloaded pest v2.8.1
  Downloaded iron v0.6.1
  Downloaded icu_normalizer_data v2.0.0
  Downloaded num-bigint v0.4.6
  Downloaded icu_properties_data v2.0.1
  Downloaded nom v7.1.3
  Downloaded idna v1.0.3
  Downloaded spdx v0.10.8
  Downloaded tiff v0.9.1
  Downloaded rav1e v0.7.1
  Downloaded ring v0.17.14
  Downloaded zerocopy v0.8.25
  Downloaded webpki-roots v0.25.4
  Downloaded tiktoken-rs v0.5.9
  Downloaded libc v0.2.173
  Downloaded memchr v2.7.5
  Downloaded rayon-core v1.12.1
  Downloaded rand v0.6.5
  Downloaded qoi v0.4.1
  Downloaded fancy-regex v0.12.0
  Downloaded parse-zoneinfo v0.3.1
  Downloaded hyper v0.10.16
  Downloaded regex v1.11.1
  Downloaded multipart-2021 v0.19.0
  Downloaded rayon v1.10.0
  Downloaded nickel v0.11.0
  Downloaded wit-component v0.202.0
  Downloaded jpeg-decoder v0.3.1
  Downloaded linux-raw-sys v0.9.4
  Downloaded image v0.25.0
  Downloaded 348 crates (38.1MiB) in 8.97s (largest was `image` at 8.8MiB)
   Compiling proc-macro2 v1.0.95
   Compiling unicode-ident v1.0.18
   Compiling cfg-if v1.0.1
   Compiling autocfg v1.4.0
   Compiling serde v1.0.219
   Compiling libc v0.2.173
   Compiling memchr v2.7.5
   Compiling typeid v1.0.3
error[E0463]: can't find crate for `core`
  |
  = note: the `wasm32-wasip1` target may not be installed
  = help: consider downloading the target with `rustup target add wasm32-wasip1`

For more information about this error, try `rustc --explain E0463`.
error: could not compile `cfg-if` (lib) due to 1 previous error
warning: build failed, waiting for other jobs to finish...
error: could not compile `memchr` (lib) due to 1 previous error
make: *** [Makefile:33: apps/llamaedge/llama-api-server/target/wasm32-wasip1/release/*.wasm] Error 101
dev@ubuntu:~/runwasi-wasmedge-demo$ cd ..
dev@ubuntu:~$ rm -fr runwasi-wasmedge-demo/
dev@ubuntu:~$ git clone https://github.com/vatsalkeshav/runwasi-wasmedge-demo.git
Cloning into 'runwasi-wasmedge-demo'...
remote: Enumerating objects: 18, done.
remote: Counting objects: 100% (18/18), done.
remote: Compressing objects: 100% (11/11), done.
remote: Total 18 (delta 3), reused 17 (delta 2), pack-reused 0 (from 0)
Receiving objects: 100% (18/18), 6.40 KiB | 6.40 MiB/s, done.
Resolving deltas: 100% (3/3), done.
dev@ubuntu:~$ cd runwasi-wasmedge-demo/
dev@ubuntu:~/runwasi-wasmedge-demo$ git -C apps/llamaedge apply $PWD/disable_wasi_logging.patch
OPT_PROFILE=release RUSTFLAGS="--cfg wasmedge --cfg tokio_unstable" make apps/llamaedge/llama-api-server
Build WASM from apps/llamaedge/llama-api-server
/bin/sh: 3: cd: can't cd to apps/llamaedge/llama-api-server
make: *** [Makefile:33: apps/llamaedge/llama-api-server/target/wasm32-wasip1/release/*.wasm] Error 2
dev@ubuntu:~/runwasi-wasmedge-demo$ git submodule update --init --recursive
Submodule 'apps/llamaedge' (https://github.com/LlamaEdge/LlamaEdge.git) registered for path 'apps/llamaedge'
Cloning into '/home/dev/runwasi-wasmedge-demo/apps/llamaedge'...
Submodule path 'apps/llamaedge': checked out '05f3349ab66ecdf67bdf3ba6ead516b4e6fd66d7'
dev@ubuntu:~/runwasi-wasmedge-demo$ cd ..
dev@ubuntu:~$ curl -sSf https://raw.githubusercontent.com/WasmEdge/WasmEdge/master/utils/install_v2.sh | bash
Info: Detected Linux-aarch64

Info: WasmEdge Installation at /home/dev/.wasmedge

Info: Fetching WasmEdge-0.14.1

/tmp/wasmedge.6216 ~
######################################################################## 100.0%
~
Info: Fetching WasmEdge-GGML-Plugin

Info: Detected CUDA version from nvcc:

Info: CUDA version is not detected from nvcc: Use the CPU version.

Info: If you want to install cuda-11 or cuda-12 version manually, you can specify the following options:

Info: Use options '-c 11' (a.k.a. '--ggmlcuda=11') or '-c 12' (a.k.a. '--ggmlcuda=12')

Info: Please refer to the document for more information: https://wasmedge.org/docs/contribute/installer_v2/

Info: Use default GGML plugin

/tmp/wasmedge.6216 ~
######################################################################## 100.0%
~
Info: Installation of wasmedge-0.14.1 successful

source /home/dev/.wasmedge/env to use wasmedge binaries
dev@ubuntu:~$ source /home/dev/.wasmedge/env
dev@ubuntu:~$ wasmedge --version
wasmedge version 0.14.1
 (plugin "wasi_logging") version 0.1.0.0
/home/dev/.wasmedge/lib/../plugin/libwasmedgePluginWasiNN.so (plugin "wasi_nn") version 0.1.26.0
dev@ubuntu:~$ curl -LO https://huggingface.co/second-state/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q5_K_M.gguf
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  1150  100  1150    0     0   2284      0 --:--:-- --:--:-- --:--:--  2281
100  869M  100  869M    0     0  4771k      0  0:03:06  0:03:06 --:--:-- 4777k
dev@ubuntu:~$ k3s
-bash: k3s: command not found
dev@ubuntu:~$ exi
-bash: exi: command not found
dev@ubuntu:~$ exit
logout

```