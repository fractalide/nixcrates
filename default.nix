{
  pkgs ? (
let
  pkgs = import <nixpkgs>;
  pkgs_ = (pkgs {});
  rustOverlay = (pkgs_.fetchFromGitHub {
    owner = "mozilla";
    repo = "nixpkgs-mozilla";
    rev = "4779fb7776c3d38d78b5ebcee62165e6d1350f74";
    sha256 = "04q6pwlz82qsm81pp7kk7i6ngrslq193v5wchdsrdifbn8cdqgbs";
  });
in (pkgs {
  overlays = [
    (import (builtins.toPath "${rustOverlay}/rust-overlay.nix"))
    (self: super: {
      rust = {
        rustc = super.rustChannels.nightly.rust;
        cargo = super.rustChannels.nightly.cargo;
      };
      rustPlatform = super.recurseIntoAttrs (super.makeRustPlatform {
        rustc = super.rustChannels.nightly.rust;
        cargo = super.rustChannels.nightly.cargo;
      });
    })
  ];
}))
}:
with pkgs;

with stdenv.lib;

let
  allCrates = recurseIntoAttrs (callPackage ../nix-crates-index { });
  normalizeName = builtins.replaceStrings [ "-"] ["_"];
  depsStringCalc = pkgs.lib.fold ( dep: str: "${str} --extern ${normalizeName dep.name}=${dep}/lib${normalizeName dep.name}.rlib") "";
  cratesDeps = pkgs.lib.fold ( recursiveDeps : newCratesDeps: newCratesDeps ++ recursiveDeps.cratesDeps  );
  # symlinkCalc creates a mylibs folder and symlinks all the buildInputs's libraries from there for rustc to link them into the final binary
  symlinkCalc = pkgs.lib.fold ( dep: str: "${str} ln -fs ${dep}/lib${normalizeName dep.name}.rlib mylibs/ \n") "mkdir mylibs\n ";
  rustNightly = rust.rustc;
in

rec {
  nixcrates = stdenv.mkDerivation rec {
    name = "nixcrates";
    src = ./src;

    deps = [ allCrates.walkdir allCrates.rustc-serialize allCrates.rustache ];
    crates = depsStringCalc deps;
    crateDeps = cratesDeps [] deps;
    buildInputs = with allCrates; crateDeps ++ deps;
    buildPhase = ''
      ${symlinkCalc buildInputs}
#       du -a
      ${rustNightly}/bin/rustc $src/main.rs --crate-type "bin" --emit=dep-info,link --crate-name nixcrates -L dependency=mylibs ${depsStringCalc deps}
    '';
    installPhase = ''
      mkdir -p $out/bin
      cp nixcrates $out/bin
    '';
  };

  getopts-example = stdenv.mkDerivation rec {
    name = "getopts-example";
    src = ./example/src;

    depsString = depsStringCalc buildInputs;
    buildInputs = with allCrates; [ getopts ];

    buildPhase = ''
      ${rustNightly}/bin/rustc $src/main.rs ${depsString}
      ./main

    '';
    installPhase=''
      mkdir $out
    '';
  };

  # flate2 example uses native c code (not using nipxkgs's packages but brings its own bundled c-code instead)
  # FIXME still fails to build
  flate2-example = stdenv.mkDerivation rec {
    name = "flate2-example";
    src = ./example/src2;
    depsString = depsStringCalc buildInputs;
    buildInputs = with allCrates; [ flate2 libc miniz-sys gcc ];

    buildPhase = ''
      ${symlinkCalc buildInputs}
#       du -a mylibs
#       ls -lathr mylibs
#       echo ${depsString}
# [pid 14162] execve("/nix/store/fff3jbf9vbqhmf6qjrmzhliq516x7yrf-rustc-1.11.0/bin/rustc", ["rustc", "src/main.rs", "--crate-name", "hello_flate2", "--crate-type", "bin", "-g", "--out-dir", "/home/joachim/Desktop/projects/fractalide/fetchUrl/hello_flate2/target/debug", "--emit=dep-info,link", "-L", "dependency=/home/joachim/Desktop/projects/fractalide/fetchUrl/hello_flate2/target/debug", "-L", "dependency=/home/joachim/Desktop/projects/fractalide/fetchUrl/hello_flate2/target/debug/deps", "--extern", "flate2=/home/joachim/Desktop/projects/fractalide/fetchUrl/hello_flate2/target/debug/deps/libflate2-d719035eaa7c6a88.rlib", "-L", "native=/home/joachim/Desktop/projects/fractalide/fetchUrl/hello_flate2/target/debug/build/miniz-sys-60c8d67696f63a43/out"], [/* 105 vars */]) = 0

      ${rustNightly}/bin/rustc $src/main.rs --crate-type "bin" --emit=dep-info,link --crate-name main -L dependency=mylibs ${depsString} -L native= #flate2=${allCrates.flate2_0_2_14}/libflate2.rlib
      ./main
      exit 1
    '';
  };

  tar-example = stdenv.mkDerivation rec {
    name = "tar-example";
    src = ./example/src3;
    buildInputs = with allCrates; [ tar filetime libc xattr ];
    buildPhase = ''
      ${symlinkCalc buildInputs}

      echo "hu" > file1.txt
      echo "bar" > file2.txt
      echo "batz" > file3.txt

      ${rustNightly}/bin/rustc $src/main.rs --crate-type "bin" --emit=dep-info,link --crate-name main -L dependency=mylibs --extern tar=${allCrates.tar}/libtar.rlib
#       du -a
#       /run/current-system/sw/bin/ldd ./main
      ./main
#       du -a
      if [ -f foo.tar ]; then
        echo -e "---------\nSUCCESS: tar-example was executed successfully!   \n--------"
      else
        echo "FAIL: not working!"
      fi
    '';
    installPhase=''
      mkdir $out
    '';
  };
  # with this you can do: nix-build -A allCrates.getopts to compile single dependencies
  inherit allCrates;

  allTargets = stdenv.mkDerivation rec {
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ nixcrates nom capnp regex json tiny_http tar-example getopts-example rustfbp rusqlite ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  E0557 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0557
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [
      soa stack_dst
    ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
    mkdir $out
    '';
  };
  E0519 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0519
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [
      juju
    ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
    mkdir $out
    '';
  };
  E0518 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0518
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [
    unicode_names ao
    ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
    mkdir $out
    '';
  };
  E0512 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0512
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [
      all__crossbeam.crossbeam_0_1_6 # dependency of simple_parallel
    ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
    mkdir $out
    '';
  };
  E0463 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0463
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ kernel32-sys gdi32-sys advapi32-sys user32-sys
    ws2_32-sys gl_generator wayland-scanner  # very important libs
    dbghelp-sys dwmapi-sys xmltree tendril piston-viewport vecmath rpassword jsonrpc-core ethabi ktmw32-sys
    crypt32-sys psapi-sys secur32-sys native-tls ole32-sys flate2 rust_sodium-sys userenv-sys d3d11-sys winmm-sys
    geojson app_dirs dwrite-sys d3dcompiler-sys uuid-sys xinput-sys mpr-sys r2d2_sqlite plist ssdp alpm
    comctl32-sys dxgi-sys oleaut32-sys comdlg32-sys json_io rusoto_codegen simple_gaussian aligned_alloc
    netapi32-sys serde-hjson named_pipe hid-sys rustlex_codegen gtk-rs-lgpl-docs d3d12-sys
    all__rusqlite.rusqlite_0_6_0 # dependency of ostn02_phf lonlat_bng
    all__rusqlite.rusqlite_0_7_3 # dependency of nickel_sqlite
    runtimeobject-sys rquery native-tls probor os_pipe piston-texture codespawn millefeuille
    serde_codegen xmlJSON clippy
    ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
    mkdir $out
    '';
  };
  E0460 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0460
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [
    regex # important to fix
    iron # important to fix
    gfx_core nickel slog-term lalrpop-snap hyper_serde
    postgres_array capnp-rpc rs-es ignore rustful inth-oauth2 elastic_hyper
    rocket
    all__regex_dfa.regex_dfa_0_4_0 # dependency of cfg-regex
    vulkano ease theban_db_server phant linea modbus googl
    ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
    mkdir $out
    '';
  };
  E0457 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0457
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ easy-plugin-plugins oil_shared worldgen
    punkt

    ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
    mkdir $out
    '';
  };
  E0455 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0455
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ core-graphics objc-foundation fsevent-sys coreaudio-sys

    ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
    mkdir $out
    '';
  };
  E0433 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0433
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ html5ever_macros
    all__syntex_syntax.syntex_syntax_0_24_0 # dependency of rusty-cheddar
    collenchyma-blas ion intrusive-containers intovec trie hotspot

    ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
    mkdir $out
    '';
  };
  E0432 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0432
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ tokio-core pnacl-build-helper heapsize_plugin serde_yaml ipc-channel string_cache_plugin
    all__quasi.quasi_0_11_0 futures-cpupool serde_item rust-base58 rblas mod_path bio phf_mac simplelog rustfft
    fractal-dto shoggoth_macros
    all__image.image_0_6_1 #dependency of glyph_packer
    external_mixin_umbrella connected_socket beanstalkd error_def
    all__qcollect-traits.qcollect-traits_0_4_1 #dependency of qindex_multi
    phloem mudpie uil_shared yaml gc_plugin rosalind unreliable-message
    all__bincode.bincode_0_3_0 #dependency of font-atlas-image
    all__leveldb.leveldb_0_6_1 #dependency of drossel-journal
    duktape_sys gfx_macros zip-longest
    all__image.image_0_6_1 #dependency of jamkit
    lazy resources_package
    all__fern.fern_0_1_12 #dependency of fern_macros
    maybe_utf8 power-assert dsl_macros compile_msg nock currency trace uil_parsers screenshot
    soundchange bytekey forkjoin kwarg_macros brainfuck_macros raw webplatform_concat_bytes
    plugger-macros algs4 rust-netmap sdr draw_state fractran_macros crdt cli storage leveldb-sys
    static_assert parse-generics-poc sfunc serial-win export_cstr membuf sha cef-sys hyperdex
    unify fourcc
    all__image.image_0_7_2 # dependency of cuticula

    ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  E0425 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0425
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [
      env_logger # critical library
      serde_codegen_internals log4rs post-expansion fern syslog
      nat_traversal #caused by no lib.rs file
      simple_logger security-framework json_macros rand_macros nanomsg libsodium-sys
      spaceapi libmultilog rustspec_assertions libimagstore stderrlog libimagstore kernlog
      postgres-derive-codegen ocl-core mowl geoip diesel_codegen_syntex
      confsolve replace-map

    ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  E0412 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0412
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ aster quasi clippy_lints easy-plugin-parsers svd
      all__blas.blas_0_9_1 #dependency for numeric
      cursive ber bitfield bson-rs netio hyphenation_commons redis
     ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  E0405 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0405
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ quack bits  ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  E0369 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0369
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [  gazetta-render-ext gazetta-render-ext ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
    mkdir $out
    '';
  };
  E0308 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0308
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ eventfd   ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
    mkdir $out
    '';
  };
  E0282 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0282
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ ears   ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
    mkdir $out
    '';
  };
  E0271 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0271
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ qcollect-traits  ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
    mkdir $out
    '';
  };
  E0259 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0259
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ quickersort ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
    mkdir $out
    '';
  };
  E0244 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0244
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ ncollide_entities ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  E0277 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0277
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ seax_svm temperature mm_image fiz-math
      mm_video acacia cortex pool
    ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  E0112 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0112
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ ioc  ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  E0107 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0107
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ syntaxext_lint   ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  E0061 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0061
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ linenoise-sys  ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  E0050 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0244
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ ncollide_geometry];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  E0046 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0246
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ extprim  ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  issue27783 = stdenv.mkDerivation rec { # https://github.com/rust-lang/rust/issues/27783
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ term_size gl_common clock_ticks ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  no_such_file_or_directory = stdenv.mkDerivation rec {
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ mime_guess llvm-sys ffmpeg-sys hotspot rl-sys
    all__typenum.typenum_1_2_0 # dependency of static-buffer
    all__typenum.typenum_1_1_0 # dependency of dimensioned
    libtar-sys tar-sys mcpat-sys repl cargo-clippy crc24 octavo-digest
    pdf mavlink ntru
    ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  not_found_librs = stdenv.mkDerivation rec { # uncomment ln 116 of nix-crates-index/default.nix then test these
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ c_vec compiletest_rs untrusted
    encoding_index_tests # critical library... insanely critical
    lodepng
    protobuf xdg # patch sent to protobuf, whitequark changed xdg
    all__libc.libc_0_1_12 # dependency of allegro_util allegro_font-sys get_if_addrs allegro bson harfbuzz ctest hprof
    # sound_stream minifb docker allegro_audio-sys request mongodb gpgme-sys allegro_font
    all__sdl2.sdl2_0_27_3 # dependency of sdl2 orbclient
    all__sdl2.sdl2_0_25_0 # dependency of sdl2_ttf sdl2_mixer
    all__sdl2.sdl2_0_15_0 # dependency of sdl2_image
    rustsym gtypes rust-libcore xsv cargo-check pretty gtypes xargo base32 rusty-tags
    sysinfo maxminddb cargo-outdated jit_macros bencode partial bloomfilter gcollections
    cereal_macros cargo-graph nickel_macros c_str anybar_rs cargo-count scgi reminisce
    cargo-local-pkgs cow
    all__cargo-multi.cargo-multi_0_5_0 # dependency of cargo-multi
    cargo-do hyperloglog ncurses vobject sufdb dining_philosophers cargo-apk
    wheel_timer coinaddress rustbook cargo-expand pwrs
    ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  panicOnNotPresent = stdenv.mkDerivation rec {
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ openssl-sys html5ever-atoms
    libz-sys # critical library
    harfbuzz-sys ring # (ring depends on "untrusted" that seems to be why it fails)
    termbox-sys openblas-provider openblas-src rustbox vorbis-encoder expectest rust-crypto backtrace-sys
    all__lmdb-sys.lmdb-sys_0_2_1 lmdb-sys # dependency of lmdb
    libgpg-error-sys netlib-provider assert_cli
    libsystemd-sys systemd # also in EnvNotSet due to error message
    liquid debugtrace tcod-sys carboxyl tcod snappy-sys xcb chomp rust-htslib
    hdf5-sys i2cdev cld2-sys cld2 cronparse gmp-sys zlib-src-sys nix-test freeimage-sys neovim-rs parsell
    parasail-sys arrayfire po netlib-blas-provider hdf5-sys nanny-sys skia-sys xcb


    ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  OSDepNotFoundConfig = stdenv.mkDerivation rec {
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ glib-sys dbus cairo-sys-rs clang-sys  portaudio
      alsa-sys fuse libusb-sys libarchive3-sys
      zmq-sys
      libudev-sys pico-sys wren-sys notify-rust c-ares-sys rust-lzma ruby-sys
      netlib-src neon-sys gexiv2-sys ruster_unsafe python3-sys python27-sys
      mcpat-sys erlang_nif-sys dns-sd
      all__bindgen.bindgen_0_16_0 # dependency of bindgen_plugin
      fontconfig-sys gexiv2-sys rustler opusfile-sys
      libfa-sys gphoto2-sys libraw-sys silverknife-fontconfig-sys pocketsphinx-sys
      opencv wiringpi libudt4-sys blip_buf-sys qmlrs ejdb-sys gnutls-sys tinysnark
      va_list-test

      ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  EnvVarNotSet = stdenv.mkDerivation rec {
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ x11 miniz-sys bzip2-sys expat-sys servo-freetype-sys glfw-sys hbs-builder context
      heartbeats-simple-sys hoedown liblmdb-sys lua52-sys brotli-sys linenoise-rust brotli2 hlua
      libsystemd-sys systemd # also in NotPresent due to error message
      rocksdb assimp-sys secp256k1 onig_sys hdrhistogram stemmer sys-info lzma-sys sass-sys
      http-muncher imgui-sys pdcurses-sys decimal file-lock afl-plugin objc_exception magic
      td_clua chipmunk-sys mrusty objc_test_utils nanovg afl-sys blip_buf-sys chip8_vm
      td_clua libudt4-sys chemfiles-sys chamkho unqlite-sys tweetnacl-sys xxhash-sys
      libxm oxipng ntrumls va_list-helper
       ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  UnstableLibraryFeature = stdenv.mkDerivation rec {
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ mmap sorted-collections fn_box  ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  MismatchSHA256 = stdenv.mkDerivation rec {
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ multipart pbr lz4-sys uchardet-sys slog-serde
    uchardet google-gmail1 water lcov-parser google-groupsmigration1 google-calendar3 google-identitytoolkit3
    google-storage1 google-cloudmonitoring2_beta2 google-youtubeanalytics1 google-plusdomains1
    google-groupssettings1 google-spectrum1_explorer google-youtube3 google-mirror1
    google-prediction1d6 google-translate2 google-pagespeedonline2 google-replicapoolupdater1_beta1 google-sqladmin1_beta4
    google-doubleclicksearch2 google-siteverification1 ffmpeg google-appstate1 google-taskqueue1_beta2
    google-admin1_reports google-manager1_beta2 google-bigquery2 google-licensing1 google-qpxexpress1
    google-gamesmanagement1_management google-tasks1 google-admin1_directory google-tagmanager1 google-drive2 google-analytics3
    google-adsense1d4 google-androidenterprise1 google-customsearch1 google-androidpublisher2 google-webmasters3
    google-adsensehost4d1 google-urlshortener1 google-fitness1 google-games1 google-adexchangeseller2 google-content2
    google-webfonts1 google-adexchangebuyer1d3 google-appsactivity1 google-gamesconfiguration1_configuration
    google-resourceviews1_beta2 google-coordinate1 google-replicapool1_beta2 google-autoscaler1_beta2
    google-reseller1_sandbox google-blogger3 google-fusiontables2 google-plus1 google-civicinfo2
    google-oauth2_v2 google-doubleclickbidmanager1 google-gan1_beta1 google-pubsub1_beta2 google-freebase1
    google-cloudlatencytest2 google-compute1 google-discovery1 google-datastore1_beta2 google-dns1
    google-dfareporting2d1 google-logging1_beta3 dns google-genomics1 google-cloudresourcemanager1_beta1
    google-deploymentmanager2_beta2 http ql2 fastcgi
    ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  not_eq = stdenv.mkDerivation rec {
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ RustyXML glutin_core_foundation glutin_cocoa rustc-test glutin_core_graphics
    rust-gmp gstreamer rust-sqlite basic-hll rust-tcl ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  retired_experimental_deprecated = stdenv.mkDerivation rec {
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ tenacious scm utils dsound-sys usp10-sys vssapi-sys winspool-sys winhttp-sys
      httpapi-sys bcrypt-sys d2d1-sys credui-sys setupapi-sys winscard-sys wevtapi-sys odbc32-sys shlwapi-sys
      posix-ipc fromxml utmp pdh-sys xdg-rs winusb-sys bitflags
    ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  WTF = stdenv.mkDerivation rec {
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ valico # rustless uses it
    ncollide_geometry diesel_codegen
    all__url.url_0_5_10 #dependency of jsonrpc-http-server and many many others
    buildable doapi ramp

    ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  shebangs = stdenv.mkDerivation rec {
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ stb_image superlu-sys rocksdb-sys freetype
      superlu threed-ice-sys postgres_macros sel4-sys imagequant sel4-sys
    ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  panicOnNoneOption = stdenv.mkDerivation rec {
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ sodium-sys barnacl_sys lua barnacl_sys
    nanny-sys ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  noMethodNamed = stdenv.mkDerivation rec {
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ heapsize_derive synstructure conduit-cookie
    sha1-hasher discotech_zookeeper netopt changecase asexp cowrc rctree

     ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  syntaxError = stdenv.mkDerivation rec {
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ xxhash free_macros phantom epsilonz_algebra metafactory
      grabbag_macros interval monad_macros expression event simple-signal crc32 tojson_macros
      gluster fftw3-sys
      all__rustc-serialize.rustc-serialize_0_2_15 # dependency of cson
      i3 mdbm-sys kissfft hexfloat core-nightly cppStream grabbag_macros
      incrust num link-config metafactory derive-new doc_file openssl2-sys
    ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  shouldBeRunWithCargo = stdenv.mkDerivation rec {
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ libjit-sys  ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  unknownCompilerVersion = stdenv.mkDerivation rec {
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ core_collections ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  linkingError = stdenv.mkDerivation rec {
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ libhdf5-sys  ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  missingNixDep = stdenv.mkDerivation rec {
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ slog-json slog-envlogger   ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  mustHave = stdenv.mkDerivation rec {
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ github capnp-futures bio skeletal_animation tokio-http2 tokio-graphql nanomsg  ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };


}
