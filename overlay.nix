final: prev:
let
  mkPackage = name: {
    inherit name;
    value = final.lib.callPackageWith {
      pkgs = final.pkgs;
      pname = name;
    } ./packages/${name} { };
  };
  names = builtins.attrNames (builtins.readDir ./packages);
in
builtins.listToAttrs (map mkPackage names)
