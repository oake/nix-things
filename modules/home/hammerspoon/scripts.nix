{ lib, ... }:

let
  dir = ./scripts;

  base = lib.mapAttrs' (
    file: _: lib.nameValuePair (lib.removeSuffix ".lua" file) { source = dir + "/${file}"; }
  ) (lib.filterAttrs (name: _: lib.hasSuffix ".lua" name) (builtins.readDir dir));
in
{
  programs.hammerspoon.scripts = lib.recursiveUpdate base {
    auto-reload-config.enable = lib.mkDefault true;
  };
}
