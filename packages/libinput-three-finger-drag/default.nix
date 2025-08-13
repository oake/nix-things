{
  pkgs,
  pname,
}:
let
  inherit (pkgs)
    rustPlatform
    fetchFromGitHub
    makeWrapper
    lib
    xdotool
    ;
in
rustPlatform.buildRustPackage {
  inherit pname;
  version = "0.1-unstable-2024-06-17";

  src = fetchFromGitHub {
    owner = "marsqing";
    repo = "libinput-three-finger-drag";
    rev = "6acd3f84b551b855b5f21b08db55e95dae3305c5";
    hash = "sha256-xmcTb+23d6mMzIfMVjzN6bwV0fWH4p6YhXXqrFmt4TM=";
  };
  cargoHash = "sha256-0a4egvNTGup/HhsF88G7PLTm7BfUKEDLTh3IPsnZ1zY=";

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ xdotool ];

  postFixup = ''
    wrapProgram "$out/bin/libinput-three-finger-drag" \
      --prefix PATH : "${lib.makeBinPath [ pkgs.libinput ]}"
  '';

  meta = {
    description = "Three-finger-drag support for libinput.";
    homepage = "https://github.com/marsqing/libinput-three-finger-drag";
    license = with lib.licenses; [ mit ];
    mainProgram = "libinput-three-finger-drag";
    maintainers = with lib.maintainers; [ ajgon ];
    platforms = lib.platforms.linux;
  };
}
