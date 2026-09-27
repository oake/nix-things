{
  pkgs,
  pname,
}:
pkgs.buildGoModule {
  inherit pname;
  src =
    let
      source = pkgs.fetchFromGitHub {
        owner = "oake";
        repo = "infra";
        rev = "da416a820f6198a10f9aa38f820283ae788937f1";
        hash = "sha256-O398plW0EYaOyaYGitoH2DwdKrWlpyppl1OgPqeFKfQ=";
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
      "sha256-UTkp3qXSpq/hljlAh4CWMhg4T0r7yJwDR/CPWqhtNe4="
    else
      "sha256-g40tA5tuYtd5tQj3k7wOflvxonA74HPpFGiXvgjeZQA=";
  subPackages = [ "cmd/${pname}" ];
  env.CGO_ENABLED = 0;
  ldflags = [
    "-s"
    "-w"
  ];
  meta = {
    homepage = "https://github.com/oake/infra";
    mainProgram = pname;
    platforms = pkgs.lib.platforms.unix;
  };
}
