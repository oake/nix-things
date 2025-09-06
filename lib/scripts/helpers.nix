{
  pkgs,
  ...
}:
{
  mkFlakeScript =
    name: runtimeInputs: text:
    let
      inherit (pkgs) coreutils;
    in
    pkgs.writeShellApplication {
      inherit name;
      excludeShellChecks = [
        "SC2034" # <var> appears unused
        "SC2029" # stupid tip not letting me do ssh user@host "$cmd"
      ];
      runtimeInputs = [ pkgs.gitMinimal ] ++ runtimeInputs;
      text = ''
        bold=$(tput bold)
        normal=$(tput sgr0)
        italic=$(tput sitm)
        standout=$(tput smso)

        function die() { echo "[1;31merror:[m $*" >&2; exit 1; }
        function confirm() { read -r -p "$1 [Y/n] " r; case "$r" in [Nn]*) return 1;; *) return 0;; esac; }
        function abort() { echo "Aborted."; exit 0; }

        USER_GIT_TOPLEVEL=$(${coreutils}/bin/realpath -e "$(git rev-parse --show-toplevel 2>/dev/null || pwd)") \
          || die "Could not determine current working directory. Something went very wrong."
        USER_FLAKE_DIR=$(${coreutils}/bin/realpath -e "$(pwd)") \
          || die "Could not determine current working directory. Something went very wrong."

        # Search from $(pwd) upwards to $USER_GIT_TOPLEVEL until we find a flake.nix
        while [[ ! -e "$USER_FLAKE_DIR/flake.nix" ]] && [[ "$USER_FLAKE_DIR" != "$USER_GIT_TOPLEVEL" ]] && [[ "$USER_FLAKE_DIR" != "/" ]]; do
          USER_FLAKE_DIR="$(dirname "$USER_FLAKE_DIR")"
        done

        [[ -e "$USER_FLAKE_DIR/flake.nix" ]] \
          || die "Could not determine location of your project's flake.nix. Please run this at or below your main directory containing the flake.nix."
        cd "$USER_FLAKE_DIR"

        ${text}
      '';
    };
}
