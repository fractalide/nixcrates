with import <nixpkgs> { };
with stdenv.lib;

let
  allCrates = recurseIntoAttrs (callPackage ../nix-crates-index { });
  normalizeName = builtins.replaceStrings [ "-"] ["_"];
  depsStringCalc = pkgs.lib.fold ( dep: str: "${str} --extern ${normalizeName dep.name}=${dep}/lib${normalizeName dep.name}.rlib") "";
  cratesDeps = pkgs.lib.fold ( recursiveDeps : newCratesDeps: newCratesDeps ++ recursiveDeps.cratesDeps  );
  # symlinkCalc creates a mylibs folder and symlinks all the buildInputs's libraries from there for rustc to link them into the final binary
  symlinkCalc = pkgs.lib.fold ( dep: str: "${str} ln -fs ${dep}/lib${normalizeName dep.name}.rlib mylibs/ \n") "mkdir mylibs\n ";
  rustNightly = rustNightlyBin.rustc;
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
  E0512 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0512
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [
      all__crossbeam.crossbeam_0_1_6 # depends on simple_parallel
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
    ws2_32-sys # very important lib
    gl_generator wayland-scanner
    dbghelp-sys dwmapi-sys xmltree tendril piston-viewport vecmath rpassword jsonrpc-core ethabi ktmw32-sys
    crypt32-sys psapi-sys secur32-sys native-tls ole32-sys flate2 rust_sodium-sys userenv-sys d3d11-sys winmm-sys
    geojson app_dirs dwrite-sys d3dcompiler-sys uuid-sys xinput-sys mpr-sys r2d2_sqlite plist ssdp alpm
    comctl32-sys dxgi-sys 
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
    postgres_array capnp-rpc rs-es ignore rustful
    ];
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
  E0455 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0455
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ core-graphics objc-foundation fsevent-sys coreaudio-sys ];
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
      nat_traversal #affected by not_found_librs experiment with disabling 'exit 1' in nix-crates-index/default.nix ln 116
      simple_logger security-framework json_macros rand_macros nanomsg
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
    buildInputs = with allCrates; [ aster quasi clippy_lints easy-plugin-parsers ];
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
  no_such_file_or_path = stdenv.mkDerivation rec {
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ mime_guess llvm-sys ffmpeg-sys hotspot rl-sys  ];
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
    encoding_index_tests # critical library
    lodepng
    protobuf xdg # patch sent to protobuf, whitequark changed xdg
    all__libc.libc_0_1_12 # dependency of allegro_util allegro_font-sys get_if_addrs allegro bson harfbuzz ctest hprof
    # sound_stream minifb docker allegro_audio-sys request mongodb gpgme-sys allegro_font
    all__sdl2.sdl2_0_27_3 # dependency of sdl2 orbclient
    all__sdl2.sdl2_0_25_0 # dependency of sdl2_ttf sdl2_mixer
    all__sdl2.sdl2_0_15_0 # dependency of sdl2_image
    rustsym gtypes rust-libcore xsv cargo-check pretty gtypes xargo base32
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
    termbox-sys openblas-provider openblas-src1 rustbox vorbis-encoder expectest rust-crypto backtrace-sys
    all__lmdb-sys.lmdb-sys_0_2_1 lmdb-sys # dependency of lmdb-rs
    libgpg-error-sys netlib-provider assert_cli
    libsystemd-sys systemd # also in EnvNotSet due to error message
    liquid debugtrace libgpg-error-sys tcod-sys carboxyl tcod snappy-sys
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
    buildInputs = with allCrates; [ libsodium-sys glib-sys dbus cairo-sys-rs clang-sys  portaudio
      alsa-sys fuse libusb-sys libarchive3-sys
      zmq-sys # also in EnvVarNotSet due to error message
      libusb
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
    buildInputs = with allCrates; [ x11 miniz-sys bzip2-sys expat-sys servo-freetype-sys4 glfw-sys hbs-builder context
      heartbeats-simple-sys ncurses hoedown liblmdb-sys lua52-sys brotli-sys linenoise-rust brotli2 hlua
      libsystemd-sys systemd # also in NotPresent due to error message
      zmq-sys # also in OSDepNotFoundConfig due to error message
      rocksdb assimp-sys secp256k1 onig_sys hdrhistogram
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
    buildInputs = with allCrates; [ mmap ];
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
    buildInputs = with allCrates; [ multipart pbr lz4 ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  crate-name_not_eq_crate_name = stdenv.mkDerivation rec {
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ RustyXML glutin_core_foundation glutin_cocoa rustc-test glutin_core_graphics
    rust-gmp  ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  RetiredAndOldNotUpdatedORExperimentalCrates = stdenv.mkDerivation rec {
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ tenatious scm utils dsound-sys usp10-sys vssapi-sys winspool-sys winhttp-sys
      httpapi-sys bcrypt-sys
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
    all__url.url_0_5_10 #dependency of jsonrpc-http-server
    buildable

    ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  needsPatchShebangs = stdenv.mkDerivation rec {
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ stb_image superlu-sys rocksdb-sys freetype
      superlu threed-ice-sys
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
    buildInputs = with allCrates; [ sodium-sys  ];
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
    buildInputs = with allCrates; [ heapsize_derive synstructure conduit-cookie  ];
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
    buildInputs = with allCrates; [ xxhash free_macros phantom  ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
}
