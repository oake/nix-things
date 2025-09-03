{
  inputs,
  ...
}:
let
  inherit (inputs.nixpkgs) lib;
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

  mkLxcChecks =
    cfgs:
    let
      withLxc = lib.filterAttrs (_: c: c.config ? lxc) cfgs;
    in
    lib.foldl' (
      acc: name:
      let
        c = withLxc.${name};
        sys = c.pkgs.system;
      in
      lib.recursiveUpdate acc { ${sys}."lxc-tarball-${name}" = c.config.system.build.tarball; }
    ) { } (builtins.attrNames withLxc);

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
          sshUser = "root";
          path = inputs.deploy-rs.lib.${cfg.pkgs.system}.activate.nixos cfg;
        };
      }
    ) cfgs;
}
