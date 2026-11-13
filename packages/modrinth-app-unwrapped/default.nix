{ pkgs, ... }:
# TODO drop once merged NixOS/nixpkgs#584442
let
  inherit (pkgs) lib stdenv;
  upstream =
    (pkgs.callPackage "${pkgs.path}/pkgs/by-name/mo/modrinth-app-unwrapped/package.nix" { })
    .overrideAttrs
      (old: {
        passthru = (old.passthru or { }) // {
          updateScript = null;
        };
      });
in
if lib.elem pkgs.sqlite upstream.buildInputs then
  lib.warn "nix-things: nixpkgs has fixed modrinth-app-unwrapped, drop packages/modrinth-app-unwrapped" upstream
else
  upstream.overrideAttrs (old: {
    buildInputs =
      old.buildInputs ++ [ pkgs.sqlite ] ++ lib.optional stdenv.hostPlatform.isDarwin pkgs.zstd;
    # Upstream marks it broken everywhere but x86_64 and Darwin.
    meta = old.meta // {
      platforms = lib.intersectLists old.meta.platforms (lib.platforms.x86_64 ++ lib.platforms.darwin);
    };
  })
