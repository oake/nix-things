{ pkgs, ... }:
# TODO drop once merged NixOS/nixpkgs#584667
let
  inherit (pkgs) lib;
  upstream = pkgs.callPackage "${pkgs.path}/pkgs/by-name/co/codex/package.nix" { };
in
if lib.elem pkgs.aws-lc upstream.buildInputs then
  lib.warn "nix-things: nixpkgs has fixed codex, drop packages/codex" upstream
else
  upstream.overrideAttrs (old: {
    buildInputs = old.buildInputs ++ [
      pkgs.aws-lc
      pkgs.oniguruma
      pkgs.sqlite
      pkgs.zstd
    ];
  })
