{
  lib,
  stdenv,
  libarchive,
  gnused,
  coreutils,
  patchelf,
  symlinkJoin,
  nvidia-libs,
  tools ? [
    "nvidia-cuda-mps-control"
    "nvidia-cuda-mps-server"
    "nvidia-debugdump"
    "nvidia-powerd"
    "nvidia-smi"
  ],
}:
let
  version = nvidia-libs.version;
  runfile = nvidia-libs.src;

  nvidia-tools = stdenv.mkDerivation {
    pname = "nvidia-userspace-tools";
    inherit version;
    src = runfile;

    nativeBuildInputs = [
      libarchive
      gnused
      coreutils
      patchelf
    ];

    dontConfigure = true;
    dontBuild = true;
    dontPatchELF = true;
    dontStrip = true;

    unpackPhase = ''
      set -euo pipefail

      unpackManually() {
        skip="$(sed 's/^skip=//; t; d' "$src")"
        tail -n +"$skip" "$src" | bsdtar xvf - >/dev/null
        sourceRoot="."
      }

      sh $src -x || unpackManually
    '';

    installPhase = ''
      set -euo pipefail
      mkdir -p "$out/bin" "$out/origBin"

      dyn_linker="$(cat "$NIX_CC/nix-support/dynamic-linker")"
      rpath="${nvidia-libs}/lib:${nvidia-libs.libPath}"

      for p in ${lib.escapeShellArgs tools}; do
        if [ ! -e "$p" ]; then
          echo "warning: $p not present in payload" >&2
          continue
        fi

        install -Dm755 "$p" "$out/bin/$p"
        patchelf \
          --interpreter "$dyn_linker" \
          --set-rpath "$rpath" \
          "$out/bin/$p"

        # unpatched for containers
        install -Dm755 "$p" "$out/origBin/$p"
      done
    '';
  };
in
symlinkJoin {
  name = "nvidia-userspace-${version}";
  paths = [
    nvidia-libs
    nvidia-tools
  ];
}
