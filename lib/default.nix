{
  inputs,
  ...
}:
let
  inherit (inputs.nixpkgs) lib;
  mkPerHostScripts =
    mkScript: nixosConfigurations:
    lib.genAttrs
      [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ]
      (
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

  mkDeployChecks = (
    builtins.mapAttrs (system: packages: { inherit (packages) deploy-rs; }) inputs.deploy-rs.packages
  );

  mkDeployNodes =
    lanDomain: cfgs:
    lib.mapAttrs (
      name: cfg:
      let
        hostname = (lib.strings.removePrefix "lxc-" name) + "." + lanDomain;
      in
      {
        inherit hostname;
        profiles.system = {
          user = "root";
          path = inputs.deploy-rs.lib.${cfg.pkgs.system}.activate.nixos cfg;
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
