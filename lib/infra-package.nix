{
  pkgs,
  pname,
}:
pkgs.buildGoModule {
  inherit pname;
  src =
    let
      # Filtering reads the tree during evaluation. Use an evaluator fetcher so
      # this never needs to build a fetch derivation for the target platform.
      source = builtins.fetchTree {
        type = "github";
        owner = "oake";
        repo = "infra";
        rev = "ee167e59d1de039b4f68ee8be7282bac9f18c9ba";
        narHash = "sha256-rYZZRHXice9FXpBtXuMup/16m25PiapgxiXi79qJUXk=";
      };
      component = pkgs.lib.removePrefix "infra-" pname;
    in
    pkgs.lib.cleanSourceWith {
      src = source;
      name = "${pname}-source";
      filter =
        path: type:
        let
          relative = pkgs.lib.removePrefix "${toString source}/" (toString path);
          directories = [
            "cmd/${pname}"
            "internal/${component}"
            "internal/api"
          ]
          ++ pkgs.lib.optional (component == "hub") "web";
        in
        builtins.elem relative [
          "go.mod"
          "go.sum"
        ]
        || (
          type == "directory"
          && builtins.elem relative [
            "cmd"
            "internal"
          ]
        )
        || builtins.any (
          directory: relative == directory || pkgs.lib.hasPrefix "${directory}/" relative
        ) directories;
    };
  # Keep the name stable: the filtered source content identifies each build.
  version = "unstable";
  vendorHash =
    if pname == "infra-hub" then
      "sha256-kSzSLfG+92M95p38vxqfMKk+BzBh072558y29GPD6Ok="
    else
      "sha256-QCfEzTW8y37TyB+V1C5bpYBSXirkC15eYvAVa5zefIQ=";
  subPackages = [ "cmd/${pname}" ];
  env.CGO_ENABLED = 0;
  ldflags = [
    "-s"
    "-w"
  ];
  passthru = {
    updateGroup = "infra";
    updateScript = [
      ./infra/update.sh
      ./infra-package.nix
    ];
  };

  meta = {
    homepage = "https://github.com/oake/infra";
    mainProgram = pname;
    platforms = pkgs.lib.platforms.unix;
  };
}
