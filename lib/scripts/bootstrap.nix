pkgs: targetPkgs: hostName: nixosConfig:
let
  inherit ((import ./helpers.nix) { inherit pkgs targetPkgs; }) mkFlakeScript;
  config = nixosConfig.config;
  isLxc = config.lxc.enable;
  isImpermanence = config.disko.simple.impermanence.enable;
  pubkeyPath = config.age.rekey.hostPubkeyRelPath;
  inherit (targetPkgs) openssh age;
in
mkFlakeScript "bootstrap-${hostName}" [ openssh age ] ''
  CURRENT_STEP=1
  BOOTSTRAP_DIR=".bootstrap"
  KEYDIR="$BOOTSTRAP_DIR/${
    if isLxc then
      "nix-lxc/${hostName}"
    else
      (if isImpermanence then "extra/persist/etc" else "extra/etc")
  }"
  KEYFILE="$KEYDIR/agenix_pq_key"

  rm -rf -- "$BOOTSTRAP_DIR"
  mkdir -p "$BOOTSTRAP_DIR"

  function step() {
    local num="$1"
    local text="$2"
    local mod=""

    if [ "$num" -eq "$CURRENT_STEP" ]; then
      mod="$standout"
    elif [ "$num" -lt "$CURRENT_STEP" ]; then
      mod="$italic"
    fi

    echo "$mod$num. $text$normal"
  }

  function wipe() {
    clear
    echo "''${bold}Bootstrapping ${hostName} will:''${normal}"
    step 1 "Generate a post-quantum hybrid ML-KEM-768 + X25519 key pair"
    step 2 "Copy the public key into ${pubkeyPath}"
    ${
      if isLxc then
        ''
          step 3 "Upload the keys to ${config.lxc.pve.host}:${config.lxc.pve.keypairPath}"
        ''
      else
        ''
          step 3 "Place the keys in $KEYDIR"
        ''
    }
    step 4 "Rekey your secrets for the new public key"
    step 5 "Commit rekeyed secrets"
    echo
  }

  wipe

  test -e ${pubkeyPath} && {
    echo "P.S. There is already a public key at ${pubkeyPath}."
    echo "It will be overwritten."
    echo
  }

  confirm "Proceed?" || abort
  wipe

  mkdir -p "$KEYDIR"

  age-keygen -pq -o "$KEYFILE"

  CURRENT_STEP=2
  wipe

  rm -f "${pubkeyPath}"
  age-keygen -y -o "${pubkeyPath}" "$KEYFILE"

  ${
    if isLxc then
      ''
        CURRENT_STEP=3
        wipe

        confirm "Upload the keys to ${config.lxc.pve.host}?" || abort
        ssh "root@${config.lxc.pve.host}" "mkdir -p ${config.lxc.pve.keypairPath}"
        scp "$KEYFILE" "root@${config.lxc.pve.host}:${config.lxc.pve.keypairPath}/"
        ssh "root@${config.lxc.pve.host}" "chown -R 100000:100000 ${config.lxc.pve.keypairPath}"
      ''
    else
      ""
  }

  CURRENT_STEP=4
  wipe
  git add --all
  echo "Rekeying..."
  nix run .#agenix-rekey.${targetPkgs.stdenv.hostPlatform.system}.rekey -- -a

  CURRENT_STEP=5
  wipe
  git add --all
  echo "Git changes to be committed on $(git rev-parse --abbrev-ref HEAD):"
  git status --short
  confirm "Commit with message 'rekey: ${hostName}'?" && {
    git commit -m "rekey: ${hostName}"
  }

  CURRENT_STEP=6
  wipe
  echo "Done!"
  echo "I suggest pushing the changes and waiting for the CI build to complete."
  echo
  echo "Then, run ''${bold}just install ${hostName}''${normal}"
  ${
    if !isLxc then
      ''
        echo "P.S. The install command will require the keys I just put in $KEYDIR"
        echo "Don't lose them!"
      ''
    else
      ""
  }
''
