pkgs: targetPkgs: hostName: nixosConfiguration:
let
  cfg = nixosConfiguration.config;
  inherit ((import ./helpers.nix) { inherit pkgs targetPkgs; }) mkFlakeScript;

  inherit (targetPkgs) openssh gum;
  tarball = cfg.system.build.tarball + "/" + cfg.image.filePath;
  tarballName = cfg.image.fileName;
  pve = cfg.lxc.pve;
  shortName = pkgs.lib.removePrefix "lxc-" hostName;
in
mkFlakeScript "install-${hostName}" [ openssh gum ] ''
  function wipe() {
    clear
    echo "''${bold}Installing ${hostName}''${normal}"
    echo "''${bold}PVE Host:''${normal} ${pve.host}"
    echo
  }

  function pverun() {
    local cmd="$1"
    ssh root@${pve.host} "$cmd"
  }

  wipe
  gum confirm "Upload to ${pve.host}:${pve.tarballPath}/${tarballName}?" --negative "Abort" || abort
  wipe
  echo "Uploading tarball..."
  scp ${tarball} "root@${pve.host}:${pve.tarballPath}/"

  wipe
  echo "Collecting information from the PVE host..."
  PCT_LIST="$(pverun "pct list")"
  NEXT_ID="$(pverun "/usr/bin/pvesh get /cluster/nextid")"

  wipe
  mapfile -t CHOICES < <(
    printf '%s\n' "$PCT_LIST" |
    awk '
      NR==1 { name_col = index($0, "Name"); next }
      $1 ~ /^[0-9]+$/ {
        vmid = $1
        name = name_col ? substr($0, name_col) : $NF
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
        printf "%s - Replace %s::%s\n", vmid, name, vmid
      }'
  )
  NEW_TEXT="$NEXT_ID - Create a new LXC"
  CHOICES+=("$NEW_TEXT::$NEXT_ID")
  PCT_ID=$(gum choose "''${CHOICES[@]}" --label-delimiter="::" --selected="$NEW_TEXT" --header="Pick an ID for your LXC")

  read -r PCT_EXISTS PCT_RUNNING PCT_NAME < <(
    awk -v id="$PCT_ID" '
      NR==1 { next }                                   # skip header
      $1==id { print 1, ($2=="running")?1:0, $NF; f=1; exit }
      END { if (!f) print 0, 0, "" }
    ' <<< "$PCT_LIST"
  )

  wipe
  NEW_MAC=""
  if (( PCT_EXISTS ));  then
    echo "Collecting more information..."
    OLD_PCT_CONFIG="$(pverun "pct config $PCT_ID")"
    OLD_MAC=""
    [[ $OLD_PCT_CONFIG =~ hwaddr=([[:xdigit:]]{2}(:[[:xdigit:]]{2}){5})(,|$) ]] && OLD_MAC="''${BASH_REMATCH[1]}"
    wipe
    if [ -n "$OLD_MAC" ]; then
        echo "Existing LXC ''${bold}$PCT_NAME''${normal} ($PCT_ID) uses MAC address ''${bold}$OLD_MAC''${normal}."
        echo "This MAC can be reused for the new LXC."
        echo
        if gum confirm "Reuse the old MAC?" --negative "No, generate a new one"; then
            NEW_MAC="$OLD_MAC"
        fi
    fi

    wipe
    echo "If you proceed, the existing LXC and its bootdisk will be ''${bold}DESTROYED''${normal}!"
    if (( PCT_RUNNING ));  then
      echo "It is now ''${bold}running''${normal}, so it will be stopped first."
    fi
    echo

    gum confirm "Destroy $PCT_NAME ($PCT_ID)?" --negative "Abort" || abort
  fi

  UNIQUE="--unique"
  if [ -n "$NEW_MAC" ]; then
      UNIQUE=""
  fi

  wipe
  if (( PCT_RUNNING )); then
      echo "Stopping the existing LXC $PCT_NAME ($PCT_ID)..."
      pverun "pct stop $PCT_ID"
  fi

  echo "Creating a new LXC ${shortName} ($PCT_ID)..."
  RESTORE_OUT="$(pverun "pct restore $PCT_ID ${pve.tarballPath}/${tarballName} $UNIQUE --force --storage ${cfg.lxc.storageName}")"
  if [ -n "$NEW_MAC" ]; then
      echo "Setting the MAC address to $NEW_MAC..."
      PCT_CONFIG="$(
        pverun "set -e; f=/etc/pve/lxc/$PCT_ID.conf; [ -f \"\$f\" ]; sed -i '0,/00:00:00:00:00:00/s//$NEW_MAC/' \"\$f\"; cat \"\$f\""
      )"
  else
      PCT_CONFIG="$(pverun "pct config $PCT_ID")"
  fi

  wipe
  echo "''${bold}Successfully created LXC ${shortName} ($PCT_ID)!''${normal}"
  echo

  echo "$PCT_CONFIG"
  echo

  gum confirm "Would you like to start it now?" \
    || { echo "Done! You can start the LXC manually."; exit 0; }

  pverun "pct start $PCT_ID"
  echo "Done! Your LXC should be running."
''
