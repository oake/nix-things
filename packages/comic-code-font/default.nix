{
  pkgs,
  pname,
}:
let
  inherit (pkgs)
    stdenvNoCC
    lib
    ;
in
stdenvNoCC.mkDerivation {
  inherit pname;
  version = "1.0";

  src = ./fonts;

  installPhase = ''
    mkdir -p $out/share/fonts/opentype
    cp -r $src $out/share/fonts/opentype/${pname}.otf
  '';

  meta = with lib; {
    description = "Comic Code font by Toshi Omagari";
    homepage = "https://tosche.net/fonts/comic-code";
    license = licenses.unfree;
    # THIS IS NOT A FREE FONT.
    # YOU CAN NOT JUST USE THIS PACKAGE.
    # YOU CAN NOT JUST TAKE THE OTF FILES AND USE THEM.
    #
    # GO HERE AND PURCHASE THE LICENCE: https://tosche.net/fonts/comic-code
    #
    # IF YOU USE THIS PACKAGE OR THE INCLUDED OTF FILES WITHOUT OBTAINING THE LICENCE,
    # YOU WILL DIE A SLOW HORRIBLE DEATH, AND THEY WON'T EVEN INVITE CLOWNS TO YOUR HOSPICE ROOM.
  };
}
