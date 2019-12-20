let things = rec {
  nixpkgsSrc = fetchTarball https://github.com/NixOS/nixpkgs/archive/6003e2f765a544f28cf77ed8bc43f2ea650f7767.tar.gz;
  mozillaOverlaySrc = fetchTarball https://github.com/kierdavis/nixpkgs-mozilla/archive/b5f2af80f16aa565cef33d059f27623d258fef67.tar.gz;
  nixpkgs = import nixpkgsSrc {
    overlays = [ (import "${mozillaOverlaySrc}/rust-overlay.nix") ];
  };
  lib = nixpkgs.lib;
  rustChannel = nixpkgs.rustChannelOf { date = "2019-12-18"; channel = "nightly"; };
  rustc = rustChannel.rust.override { extensions = [ "rust-src" "llvm-tools-preview" ]; };
  cargo = rustChannel.cargo;
  rustPlatform = nixpkgs.rust.makeRustPlatform { inherit rustc cargo; };
  buildRustPackage = rustPlatform.buildRustPackage;
  cargo-xbuild = nixpkgs.cargo-xbuild.override { inherit rustPlatform; };
  cargo-binutils = buildRustPackage rec {
    pname = "cargo-binutils";
    version = "0.1.6";
    src = nixpkgs.fetchCrate {
      crateName = pname;
      inherit version;
      sha256 = "1rhcl3jyig66am3ggy5ii78b65979f12vi92zm81jlh2ih537s6v";
    };
    cargoPatches = [ ./cargo-binutils-Cargo-lock.patch ];
    cargoSha256 = "1jhyxlarm3pzawx2004w2cw39fk38q2hncsjps21lz4y144ppz2l";
  };
  crossBuildRustPackage = args: let
    args' = {
      cargoUpdateHook = ''
        echo '[dependencies.compiler_builtins]' >> Cargo.toml
        echo 'version = "0.1.21"' >> Cargo.toml;
      '';
    } // args;
    targetJson = if (args ? targetJson) then args.targetJson else "${./x86_64-baremetal.json}";
    deriv = buildRustPackage args';
    deriv' = lib.overrideDerivation deriv (oldAttrs: {
      buildPhase = builtins.replaceStrings
        ["cargo build" "--target ${nixpkgs.stdenv.hostPlatform.config}" "--frozen"]
        ["cargo xbuild" "--target ${targetJson}" ""]
        oldAttrs.buildPhase;
      nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [ cargo-xbuild ];
      doCheck = false;
      releaseDir = "target/${builtins.head (lib.splitString "." (baseNameOf targetJson))}/release";
    });
  in deriv';
  kernel = crossBuildRustPackage {
    pname = "kernel";
    version = "0.1";
    src = nixpkgs.nix-gitignore.gitignoreSource []./crate;
    cargoSha256 = "0ihl5a5ppb3rm4mwzfck23d1hmnnc6wgpmih5f5rqvd115jrys17";
  };
  bootloader = crossBuildRustPackage rec {
    pname = "bootloader";
    version = "0.8.2";
    src = nixpkgs.fetchFromGitHub {
      owner = "rust-osdev";
      repo = "bootloader";
      rev = "v${version}";
      sha256 = "1f6b19w4yb638ds3nk75gv74pf9pv3v2av9bn2libi0hxk72n72b";
    };
    cargoSha256 = "0diyw5cs90j018gl4fkhziq0mv9wrh1hibzc41db1qv37m4q61lf";
    cargoBuildFlags = ["--features" "binary"];
    targetJson = "${src}/x86_64-bootloader.json";
    KERNEL = "${kernel}/bin/kernel";
    KERNEL_MANIFEST = "${kernel.src}/Cargo.toml";
  };
  diskimage = nixpkgs.stdenv.mkDerivation {
    name = "diskimage.bin";
    nativeBuildInputs = [ cargo cargo-binutils rustc nixpkgs.removeReferencesTo ];
    phases = [ "buildPhase" "fixupPhase" ];
    buildPhase = ''
      cargo objcopy -- -I elf64-x86_64 -O binary --binary-architecture=i386:x86_64 ${bootloader}/bin/bootloader $out
    '';
    fixupPhase = ''
      remove-references-to -t ${rustc} $out
    '';
  };
  run-vm = nixpkgs.writeShellScript "run-vm" ''
    disk=$(mktemp)
    trap "rm -f $disk" EXIT QUIT INT HUP
    cp ${diskimage} $disk
    ${nixpkgs.qemu}/bin/qemu-system-x86_64 -drive format=raw,file=$disk
  '';
}; in things.run-vm // things
