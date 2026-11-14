{
  pkgs,
  pname,
}:
let
  inherit (pkgs)
    lib
    stdenvNoCC
    fetchFromGitHub
    makeWrapper
    python3
    ;

  python = python3.withPackages (ps: [ ps.cryptography ]);
in
stdenvNoCC.mkDerivation {
  inherit pname;
  version = "0-unstable-2026-11-08";

  src = fetchFromGitHub {
    owner = "EthanArbuckle";
    repo = "fairplay-decrypt";
    rev = "d81d98b13656c9dbb340f04dd0838137278f44a5";
    hash = "sha256-TFFwGpSEyfIst+sxap91dVTlJ+YUrFueyRVTmnZty60=";
  };

  nativeBuildInputs = [ makeWrapper ];

  postPatch = ''
    substituteInPlace decrypt.py \
      --replace-fail 'argparse.ArgumentParser(description=__doc__)' \
        'argparse.ArgumentParser(prog="fairplay-decrypt", description=__doc__)' \
      --replace-fail 'default=ROOT / "credential.bin"' \
        'default=Path("credential.bin")'
  '';

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm644 decrypt.py "$out/libexec/fairplay-decrypt/decrypt.py"
    install -Dm644 core.py "$out/libexec/fairplay-decrypt/core.py"
    makeWrapper ${python}/bin/python "$out/bin/fairplay-decrypt" \
      --add-flags "$out/libexec/fairplay-decrypt/decrypt.py" \
      --set PYTHONNOUSERSITE 1

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    "$out/bin/fairplay-decrypt" --help
    PYTHONPATH="$out/libexec/fairplay-decrypt" ${python}/bin/python -P - <<'PY'
    from core import block_transform

    assert block_transform(bytes(16), bytes(16)).hex() == "66e94bd4ef8a2c3b884cfa59ca342b2e"
    PY

    runHook postInstallCheck
  '';

  passthru.updateScript = pkgs.nix-update-script {
    extraArgs = [
      "--version=branch"
    ];
  };

  meta = {
    description = "Decrypt FairPlay-encrypted IPAs using an account credential";
    homepage = "https://github.com/EthanArbuckle/fairplay-decrypt";
    license = lib.licenses.gpl3Only;
    mainProgram = "fairplay-decrypt";
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
}
