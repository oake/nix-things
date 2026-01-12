{
  pkgs,
  pname,
}:
let
  inherit (pkgs)
    lib
    buildGoModule
    fetchFromGitHub
    ;
in
buildGoModule rec {
  inherit pname;
  version = "0.1.7";

  src = fetchFromGitHub {
    owner = "vvoland";
    repo = "linkwinbt";
    tag = "v${version}";
    hash = "sha256-WmPYoOc4+Nf0RksFjaxUtjOc5orYMRQ6X6X6rzkDCy0=";
  };

  vendorHash = "sha256-Ws8E9EYVLpp1Q/5c1kdfMbDgmsxoLvbhiLUiGel65kA=";

  postPatch =
    let
      regedPath = lib.getExe' pkgs.chntpw "reged";
    in
    ''
      substituteInPlace winreg/winreg.go \
        --replace-fail 'exec.LookPath("reged")' 'exec.LookPath("${regedPath}")' \
        --replace-fail 'exec.Command("reged",' 'exec.Command("${regedPath}",'
    '';

  ldflags = [
    "-s"
    "-w"
  ];

  env.CGO_ENABLED = 0;

  subPackages = [ "cmd/linkwinbt" ];

  meta = {
    homepage = "https://github.com/vvoland/linkwinbt";
    changelog = "https://github.com/vvoland/linkwinbt/releases/tag/v${version}";
    description = "Use the same Bluetooth pairing key on Linux/Windows dual-boot system";
    longDescription = ''
      A utility that extracts the Bluetooth pairing from the Windows registry and applies it to your Linux Bluetooth configuration.
      It allows to have the same Bluetooth device paired on both Linux and Windows.
    '';
    license = with lib.licenses; [ bsd3 ];
    platforms = lib.platforms.linux;
    mainProgram = "linkwinbt";
  };
}
