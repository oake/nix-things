{
  pkgs,
  pname,
}:
let
  inherit (pkgs)
    lib
    stdenv
    fetchFromGitHub
    makeWrapper
    python3
    ;

  python = python3.withPackages (ps: [ ps.cryptography ]);
in
stdenv.mkDerivation {
  inherit pname;
  version = "0-unstable-2026-10-23";

  src = fetchFromGitHub {
    owner = "EthanArbuckle";
    repo = "fairplay-decrypt";
    rev = "1bad106ee1698c6d9c483f67d898183ffa4c6eb3";
    hash = "sha256-V9zR4+wbLkMYdC3OLSEgJFALOi/7lWuzi0OXRV9+I+g=";
  };

  nativeBuildInputs = [ makeWrapper ];

  postPatch = ''
    substituteInPlace decrypt.py \
      --replace-fail 'argparse.ArgumentParser(description=__doc__)' \
        'argparse.ArgumentParser(prog="fairplay-decrypt", description=__doc__)' \
      --replace-fail 'default=ROOT / "credential.bin"' \
        'default=Path("credential.bin")'
  '';

  # The default target also builds credential retrieval on Darwin.
  buildFlags = [ "transform" ];
  makeFlags = [ "CC=${stdenv.cc.targetPrefix}cc" ];

  # Darwin strip mistakes the raw constant table for an object file.
  stripExclude = [ "transform_const_data.bin" ];

  installPhase = ''
    runHook preInstall

    install -Dm644 decrypt.py "$out/libexec/fairplay-decrypt/decrypt.py"
    install -Dm644 core.py "$out/libexec/fairplay-decrypt/core.py"
    install -Dm644 transform_const_data.bin "$out/libexec/fairplay-decrypt/transform_const_data.bin"
    install -Dm755 transform "$out/libexec/fairplay-decrypt/transform"
    makeWrapper ${python}/bin/python "$out/bin/fairplay-decrypt" \
      --add-flags "$out/libexec/fairplay-decrypt/decrypt.py" \
      --set PYTHONNOUSERSITE 1

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    "$out/bin/fairplay-decrypt" --help
    # Exercise Python imports, the native helper, and the installed data together.
    PYTHONPATH="$out/libexec/fairplay-decrypt" ${python}/bin/python -P - <<'PY'
    import os
    from pathlib import Path
    from core import BlockTransform

    root = Path(os.environ["out"]) / "libexec/fairplay-decrypt"
    with BlockTransform(root / "transform", root / "transform_const_data.bin") as transform:
        assert transform(bytes(16), bytes(16)).hex() == "6ed2ad231cd7fd2da88305897d7ccbde"
    PY

    runHook postInstallCheck
  '';

  meta = {
    description = "Decrypt FairPlay-encrypted IPAs using an account credential";
    homepage = "https://github.com/EthanArbuckle/fairplay-decrypt";
    # Upstream does not provide a license.
    license = lib.licenses.unfree;
    mainProgram = "fairplay-decrypt";
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
}
