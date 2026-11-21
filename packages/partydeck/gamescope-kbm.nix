{ pkgs }:
let
  inherit (pkgs) lib;
in
(pkgs.gamescope.override { enableWsi = true; }).overrideAttrs (previousAttrs: {
  pname = "gamescope-kbm";
  version = "0-unstable-2026-09-20";

  src = pkgs.fetchFromGitHub {
    owner = "partydeck";
    repo = "gamescope";
    rev = "55626e9554b1aa88aa90ff9d9a761a2aeb931ab6";
    fetchSubmodules = true;
    hash = "sha256-5lkTu8cFSEuK5FuPj0QPz51K3qpJo0FIMa/yBQJpfKQ=";
  };

  mesonFlags = previousAttrs.mesonFlags ++ [
    (lib.mesonOption "benchmark" "disabled")
    (lib.mesonBool "enable_tests" false)
  ];

  postInstall = previousAttrs.postInstall + ''
    mv "$out/bin/gamescope" "$out/bin/gamescope-kbm"
  '';

  meta = previousAttrs.meta // {
    mainProgram = "gamescope-kbm";
  };
})
