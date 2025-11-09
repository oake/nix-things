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
    let
      builderSystem = "x86_64-linux";
      builderPkgs = inputs.nixpkgs.legacyPackages.${builderSystem};

      apps = forAllSystems (
        system:
        let
          pkgs = inputs.nixpkgs.legacyPackages.${system};
        in
        pkgs.lib.mapAttrs' (
          name: cfg:
          let
            drv = mkScript pkgs pkgs name cfg;
          in
          {
            name = drv.name;
            value = {
              type = "app";
              program = "${drv}/bin/${drv.name}";
            };
          }
        ) nixosConfigurations
      );

      checks.${builderSystem} = builderPkgs.lib.mapAttrs' (
        name: cfg:
        let
          perTarget = forAllSystems (
            system:
            let
              targetPkgs = inputs.nixpkgs.legacyPackages.${system};
            in
            mkScript builderPkgs targetPkgs name cfg
          );
          scriptName = perTarget.${builderSystem}.name;
          checkDrv = builderPkgs.linkFarm scriptName (
            lib.mapAttrsToList (system: drv: {
              name = "bin/${drv.name}-${system}";
              path = "${drv}/bin/${drv.name}";
            }) perTarget
          );
        in
        {
          name = scriptName;
          value = checkDrv;
        }
      ) nixosConfigurations;
    in
    {
      inherit apps checks;
    };
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
        sys = c.pkgs.stdenv.hostPlatform.system;
      in
      lib.recursiveUpdate acc { ${sys}."disko-${name}" = c.config.system.build.diskoScript; }
    ) { } (builtins.attrNames withDisko);

  mkDeployNodes =
    cfgs:
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
      deployCfgs = lib.filterAttrs (_: c: c.config.deploy.enable) cfgs;
      mkActivate =
        cfg:
        let
          system = cfg.pkgs.stdenv.hostPlatform.system;
        in
        deployPkgs.${system}.deploy-rs.lib.activate.nixos cfg;
      nodes = lib.mapAttrs (_: cfg: {
        hostname = cfg.config.deploy.fqdn;
        profiles.system = {
          sshUser = "deploy";
          user = "root";
          path = mkActivate cfg;
        };
      }) deployCfgs;
      checks = lib.foldl' lib.recursiveUpdate { } (
        lib.mapAttrsToList (name: cfg: {
          ${cfg.pkgs.stdenv.hostPlatform.system} = {
            "deploy-${name}" = mkActivate cfg;
          };
        }) deployCfgs
      );
    in
    {
      inherit nodes checks;
    };

  mkBootstrapScripts = mkPerHostScripts (import ./scripts/bootstrap.nix);
  mkLxcScripts =
    cfgs:
    let
      withLxc = lib.filterAttrs (_: c: c.config.lxc.enable) cfgs;
    in
    mkPerHostScripts (import ./scripts/install-lxc.nix) withLxc;
}
