{ pkgs, ... }:
# TODO drop once merged NixOS/nixpkgs#584699
let
  inherit (pkgs) lib;
  upstream = pkgs.callPackage "${pkgs.path}/pkgs/by-name/tu/turbo-unwrapped/package.nix" { };
in
if lib.elem pkgs.zstd (upstream.buildInputs or [ ]) then
  lib.warn "nix-things: nixpkgs has fixed turbo-unwrapped, drop packages/turbo-unwrapped" upstream
else
  upstream.overrideAttrs (old: {
    nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.pkg-config ];
    buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.zstd ];
  })
