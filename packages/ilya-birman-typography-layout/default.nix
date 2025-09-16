{
  pkgs,
  pname,
}:
let
  inherit (pkgs)
    stdenvNoCC
    fetchzip
    lib
    ;
  version = "3.9";
in
stdenvNoCC.mkDerivation {
  inherit pname version;

  src = fetchzip {
    url = "https://ilyabirman.ru/typography-layout/download/ilya-birman-typolayout-${version}-mac.zip";
    hash = "sha256-pJx5BG/ASVPZjo9lfxdYpyfz8qZsZmlLF9Bt2LTSt/U=";
    stripRoot = false;
  };

  patches = [
    ./trim-names.patch
    ./fix-backtick.patch
  ];

  installPhase = ''
    mkdir -p "$out/Library/Keyboard Layouts"
    cp -r "Ilya Birman Typography Layout.bundle" "$out/Library/Keyboard Layouts/"
  '';

  passthru.layouts = [
    {
      id = -9876;
      name = "English";
    }
    {
      id = -31553;
      name = "Russian";
    }
  ];

  meta = {
    description = "Ilya Birman Typography Layout for macOS";
    platforms = lib.platforms.darwin;
  };
}
