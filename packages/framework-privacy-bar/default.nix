{
  pkgs,
  pname,
}:
let
  inherit (pkgs)
    lib
    buildGoModule
    fetchFromGitHub
    makeWrapper
    ;
in
buildGoModule (finalAttrs: {
  inherit pname;
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "anna-oake";
    repo = "framework-privacy-bar";
    tag = "v${finalAttrs.version}";
    hash = "sha256-bapI8Eo3TSEE/LfKDapk1McEGz+FZrELB4qbD5sJ4nw=";
  };

  vendorHash = "sha256-ovsHNNXXTn63D5MssZWb8QmLWeTuoR8dVTNdy5osSvU=";

  nativeBuildInputs = [
    makeWrapper
  ];

  postInstall = ''
    mkdir -p $out/share
    cp -r packaging/share/. $out/share/

    wrapProgram $out/bin/framework-privacy-bar \
      --set ICON_THEME_PATH "$out/share/icons"
  '';

  meta = {
    description = "Framework microphone privacy switch tray indicator";
    homepage = "https://github.com/anna-oake/framework-privacy-bar";
    license = lib.licenses.gpl3Only;
    mainProgram = "framework-privacy-bar";
    platforms = lib.platforms.linux;
  };
})
