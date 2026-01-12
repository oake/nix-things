{
  inputs,
  ...
}:
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.disko.simple;
  inherit (lib) types;
  diskoLib = inputs.disko.lib;

  persistPath = "/persist";
in
{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.impermanence.nixosModules.impermanence
    (lib.mkAliasOptionModule
      [ "disko" "simple" "impermanence" "persist" ]
      [ "environment" "persistence" persistPath ]
    )
  ];

  options.disko.simple = {
    device = lib.mkOption {
      type = types.nullOr diskoLib.optionTypes.absolute-pathname;
      default = null; # null disables the entire module
      description = "Device path";
    };

    rootType = lib.mkOption {
      type = types.enum [
        "ext4"
        "btrfs"
      ];
      default = "ext4";
      description = "Root filesystem type";
    };

    impermanence = {
      enable = lib.mkEnableOption "impermanence (only with rootType = btrfs for now)";
    };

    luks = lib.mkEnableOption "LUKS encryption of the root filesystem";
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.device != null) (
      let
        rootPartition = config.disko.devices.disk.main.content.partitions.root;
        rootPath = if cfg.luks then rootPartition.content.content.device else rootPartition.device;
      in
      lib.mkMerge [
        {
          assertions = [
            {
              assertion = !cfg.impermanence.enable || cfg.rootType == "btrfs";
              message = "impermanence is only supported with btrfs for now";
            }
          ];

          disko.devices.disk =
            let
              mkLuks = content: {
                type = "luks";
                name = "crypted";
                settings = {
                  crypttabExtraOpts = [
                    "tpm2-device=auto"
                    "tpm2-measure-pcr=yes"
                  ];
                  allowDiscards = true;
                };
                passwordFile = "/tmp/secret.key";
                inherit content;
              };

              roots = {
                ext4 = {
                  type = "filesystem";
                  format = "ext4";
                  mountpoint = "/";
                };

                btrfs = {
                  type = "btrfs";
                  extraArgs = [ "-f" ];
                  postCreateHook = lib.optionalString cfg.impermanence.enable ''
                    MNTPOINT=$(mktemp -d)
                    mount ${rootPath} "$MNTPOINT" -o subvol=/
                    trap 'umount $MNTPOINT; rm -rf $MNTPOINT' EXIT
                    btrfs subvolume snapshot -r $MNTPOINT/root $MNTPOINT/root-blank
                  '';
                  subvolumes =
                    (lib.attrsets.mapAttrs (
                      name: mountpoint: {
                        mountOptions = [
                          "compress=zstd"
                          "noatime"
                        ];
                        inherit mountpoint;
                      }
                    ))
                      (
                        {
                          "root" = "/";
                          "home" = "/home";
                          "nix" = "/nix";
                          "log" = "/var/log";
                        }
                        // (lib.optionalAttrs cfg.impermanence.enable {
                          "persist" = persistPath;
                        })
                      );
                };
              };
            in
            {
              main = {
                type = "disk";
                inherit (cfg) device;
                content = {
                  type = "gpt";
                  partitions = {
                    boot = {
                      size = "512M";
                      type = "EF00";
                      content = {
                        type = "filesystem";
                        format = "vfat";
                        mountpoint = "/boot";
                      };
                    };
                    root = {
                      size = "100%";
                      content = if cfg.luks then mkLuks roots.${cfg.rootType} else roots.${cfg.rootType};
                    };
                  };
                };
              };
            };

          fileSystems = lib.optionalAttrs (cfg.rootType == "btrfs") {
            "/var/log".neededForBoot = true;
          };

          environment.systemPackages = lib.optional cfg.luks (
            pkgs.writeShellScriptBin "cryptenroll" ''
              set -euo pipefail

              if [[ $EUID -ne 0 ]]; then
                echo "Please run as root"
                exit 1
              fi

              systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7+12 --wipe-slot=tpm2 ${rootPartition.device}
              echo "Rebooting now..."
              sleep 3
              reboot
            ''
          );
        }
        (lib.mkIf cfg.impermanence.enable {
          fileSystems.${persistPath}.neededForBoot = true;

          boot.initrd = {
            enable = true;
            supportedFilesystems = [ "btrfs" ];
            postResumeCommands = lib.mkAfter ''
              (
                set -euo pipefail

                udevadm settle || true
                for i in $(seq 1 60); do
                  if [ -b "${rootPath}" ]; then break; fi
                  echo "[impermanence] waiting for ${rootPath} ($i/60)…"
                  sleep 0.5
                  udevadm settle || true
                done

                mkdir -p /btrfs
                mount -o subvol=/ ${rootPath} /btrfs

                btrfs subvolume list -o /btrfs/root |
                cut -f9 -d' ' |
                while read subvolume; do
                  echo "deleting /$subvolume subvolume..."
                  btrfs subvolume delete "/btrfs/$subvolume"
                done &&
                echo "deleting /root subvolume..." &&
                btrfs subvolume delete /btrfs/root

                echo "restoring blank /root subvolume..."
                btrfs subvolume snapshot /btrfs/root-blank /btrfs/root

                umount /btrfs
              ) || echo "[impermanence] wipe failed — continuing boot."
            '';
          };

          security.sudo.extraConfig = ''
            # rollback results in sudo lectures after each reboot
            Defaults lecture = never
          '';

          age.identityPaths = [ "${persistPath}/etc/agenix_pq_key" ];

          disko.simple.impermanence.persist = {
            directories = [
              "/var/lib/nixos"
              "/var/lib/systemd/coredump"
              "/root"
            ]
            ++ lib.optional config.hardware.bluetooth.enable "/var/lib/bluetooth";
            files = [
              "/etc/machine-id"
              "/etc/ssh/ssh_host_ed25519_key"
              "/etc/ssh/ssh_host_ed25519_key.pub"
              "/etc/ssh/ssh_host_rsa_key"
              "/etc/ssh/ssh_host_rsa_key.pub"
              "/etc/agenix_pq_key"
            ];
          };
        })
      ]
    ))
    {
      environment.persistence.${persistPath}.enable = cfg.impermanence.enable;
    }
  ];
}
