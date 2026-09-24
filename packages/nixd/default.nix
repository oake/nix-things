{ inputs, system, ... }:
# nixd with option completions merged across option sets: an option that is
# identical in several sets (e.g. nixos, darwin, home-manager) is listed once,
# with every set in its detail. Built from plain nixpkgs since `pkgs.nixd` here
# is this package.
inputs.nixpkgs.legacyPackages.${system}.nixd.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [ ./merge-option-completions.patch ];
})
