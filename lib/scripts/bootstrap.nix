pkgs: targetPkgs: hostName: nixosConfig:
let
  inherit ((import ./helpers.nix) { inherit pkgs targetPkgs; }) mkFlakeScript;
  config = nixosConfig.config;
  isLxc = config.lxc.enable;
  isImpermanence = config.environment ? persistence;
  pubkeyPath = config.age.rekey.hostPubkeyRelPath;
  inherit (targetPkgs) openssh;
in
mkFlakeScript "bootstrap-${hostName}" [ openssh ] ''
  CURRENT_STEP=1
  BOOTSTRAP_DIR=".bootstrap"
  SSHDIR="$BOOTSTRAP_DIR/${
    if isLxc then
      "nix-lxc/${hostName}"
    else
      (if isImpermanence then "extra/persist/etc/ssh" else "extra/etc/ssh")
  }"

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

  function genkey() {
    local keyType="$1"
    local keyName="$2"

    if [ "$keyType" = "ed25519" ]; then
      ssh-keygen -q -t ed25519 -N "" -C "${hostName}" -f "$SSHDIR/$keyName"
    elif [ "$keyType" = "rsa" ]; then
      ssh-keygen -q -t rsa -b 4096 -N "" -C "${hostName}" -f "$SSHDIR/$keyName"
    fi
  }

  function wipe() {
    clear
    echo "''${bold}Bootstrapping ${hostName} will:''${normal}"
    step 1 "Generate ${if isLxc then "an Ed25519 keypair" else "Ed25519 and RSA keypairs"}"
    step 2 "Copy the public key into ${pubkeyPath}"
    ${
      if isLxc then
        ''
          step 3 "Upload the keys to ${config.lxc.pve.host}:${config.lxc.pve.keypairPath}"
        ''
      else
        ''
          step 3 "Place the keys in $SSHDIR"
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

  mkdir -p "$SSHDIR"

  ${
    if isLxc then
      ''
        genkey ed25519 agenix_key
        PUBKEY_FILE="$SSHDIR/agenix_key.pub"
      ''
    else
      ''
        genkey ed25519 ssh_host_ed25519_key
        genkey rsa ssh_host_rsa_key
        chmod 0755 "$SSHDIR/.."
        chmod 0755 "$SSHDIR"
        PUBKEY_FILE="$SSHDIR/ssh_host_ed25519_key.pub"
      ''
  }

  CURRENT_STEP=2
  wipe

  install -m 0644 "$PUBKEY_FILE" "${pubkeyPath}"

  ${
    if isLxc then
      ''
        CURRENT_STEP=3
        wipe

        confirm "Upload the keys to ${config.lxc.pve.host}?" || abort
        ssh "root@${config.lxc.pve.host}" "mkdir -p ${config.lxc.pve.keypairPath}"
        scp "$SSHDIR/agenix_key"{,.pub} "root@${config.lxc.pve.host}:${config.lxc.pve.keypairPath}/"
        ssh "root@${config.lxc.pve.host}" "chown -R 100000:100000 ${config.lxc.pve.keypairPath}"
      ''
    else
      ''''
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
        echo "P.S. The install command will require the keys I just put in $SSHDIR"
        echo "Don't lose them!"
      ''
    else
      ''''
  }
''
