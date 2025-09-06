{
  inputs,
  ...
}:
let
  inherit (inputs.nixpkgs) lib;

  supportedSystems = [
    "x86_64-linux"
    "aarch64-linux"
    "aarch64-darwin"
  ];

  forAllSystems = lib.genAttrs supportedSystems;

  mkPerHostScripts =
    mkScript: nixosConfigurations:
    forAllSystems (
      system:
      let
        pkgs = inputs.nixpkgs.legacyPackages.${system};
      in
      pkgs.lib.mapAttrs' (
        name: config:
        let
          script = mkScript pkgs name config;
        in
        {
          name = script.name;
          value = script;
        }
      ) nixosConfigurations
    );
in
{
  mkBtrfsMount = part: subvol: {
    device = part;
    fsType = "btrfs";
    options = [
      "subvol=${subvol}"
      "compress=zstd"
      "noatime"
    ];
  };

  mkDiskoChecks =
    cfgs:
    let
      withDisko = lib.filterAttrs (_: c: c.config.system.build ? diskoScript) cfgs;
    in
    lib.foldl' (
      acc: name:
      let
        c = withDisko.${name};
        sys = c.pkgs.system;
      in
      lib.recursiveUpdate acc { ${sys}."disko-${name}" = c.config.system.build.diskoScript; }
    ) { } (builtins.attrNames withDisko);

  mkDeployNodes =
    lanDomain: cfgs:
    let
      deployPkgs = forAllSystems (
        system:
        import inputs.nixpkgs {
          inherit system;
          overlays = [
            (self: super: {
              deploy-rs = {
                inherit ((inputs.deploy-rs.overlays.default self super).deploy-rs) lib;
                inherit (super) deploy-rs;
              };
            })
          ];
        }
      );
    in
    lib.mapAttrs (
      name: cfg:
      let
        hostname = (lib.strings.removePrefix "lxc-" name) + "." + lanDomain;
      in
      {
        inherit hostname;
        profiles.system = {
          user = "root";
          path = deployPkgs.${cfg.pkgs.system}.deploy-rs.lib.activate.nixos cfg;
        }
        // (
          if (lib.strings.hasPrefix "lxc-" name) then
            { sshUser = "root"; }
          else
            {
              interactiveSudo = true;
            }
        );
      }
    ) cfgs;

  mkBootstrapScripts = mkPerHostScripts (import ./scripts/bootstrap.nix);
  mkLxcScripts =
    cfgs:
    let
      withLxc = lib.filterAttrs (_: c: c.config ? lxc) cfgs;
    in
    mkPerHostScripts (import ./scripts/install-lxc.nix) withLxc;
}
