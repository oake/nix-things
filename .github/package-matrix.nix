packages:
let
  allPackages = builtins.foldl' (all: pkgs: all // pkgs) { } (builtins.attrValues packages);
in
{
  include = builtins.attrValues (
    builtins.foldl' (
      groups: package:
      let
        pkg = allPackages.${package};
        passthru = pkg.passthru or { };
        name = passthru.updateGroup or package;
      in
      if (passthru ? updateScript && passthru.updateScript == null) || groups ? ${name} then
        groups
      else
        groups
        // {
          ${name} = {
            inherit name;
            attribute = "packages.${pkg.system}.${package}";
          };
        }
    ) { } (builtins.attrNames allPackages)
  );
}
