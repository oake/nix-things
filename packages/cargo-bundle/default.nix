{ pkgs, ... }:
# TODO drop once merged NixOS/nixpkgs#584581
let
  inherit (pkgs) lib;
  upstream = pkgs.callPackage "${pkgs.path}/pkgs/by-name/ca/cargo-bundle/package.nix" { };
in
if lib.elem pkgs.aws-lc upstream.buildInputs then
  lib.warn "nix-things: nixpkgs has fixed cargo-bundle, drop packages/cargo-bundle" upstream
else
  upstream.overrideAttrs (old: {
    nativeBuildInputs =
      old.nativeBuildInputs
      ++ lib.optional (!lib.elem pkgs.pkg-config old.nativeBuildInputs) pkgs.pkg-config;
    buildInputs = old.buildInputs ++ [ pkgs.aws-lc ];
  })
