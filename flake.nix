{
  outputs = inputs: {
    overlays.default = import ./pkgs/overlay.nix;
  };
}
