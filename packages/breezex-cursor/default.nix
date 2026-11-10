{
  pkgs,
  pname,
}:
let
  inherit (pkgs)
    stdenvNoCC
    fetchFromGitHub
    nix-update-script
    lib
    python3Minimal
    ;
  version = "2.0.1";
in
stdenvNoCC.mkDerivation {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "ful1e5";
    repo = "BreezeX_Cursor";
    rev = "refs/tags/v${version}";
    hash = "sha256-P9LgQb3msq6YydK5RIk5yykUd9SL2GQbC4aH4F8LUF0=";
  };

  strictDeps = true;

  nativeBuildInputs = [ python3Minimal ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -dm 0755 "$out/share/icons"
    python3 ${./scalable.py} "$src" "$out/share/icons/BreezeX-Black"

    runHook postInstall
  '';

  disallowedReferences = [ python3Minimal ];

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "BreezeX black cursor theme as GNOME SVG cursors";
    homepage = "https://github.com/ful1e5/BreezeX_Cursor";
    license = lib.licenses.gpl3;
    maintainers = with lib.maintainers; [ pagedMov ];
    platforms = lib.platforms.unix;
  };
}
