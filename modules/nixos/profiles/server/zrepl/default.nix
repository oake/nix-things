{
  config,
  pkgs,
  lib,
  unstable,
  ...
}:
let
  cfg = config.profiles.server.zrepl;
in
{
  options.profiles.server.zrepl = {
    enable = lib.mkEnableOption "zrepl server profile";

    pruningKeepSchedule = lib.mkOption {
      type = lib.types.str;
      example = "1x1h(keep=all) | 24x1h | 30x1d | 3x30d";
      description = "Pruning grid schedule used for snapshotting and pulling.";
    };

    dataset = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "storage/zrepl";
      description = "Dataset on this machine to replicate to.";
    };

    snapshotting = {
      datasets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "List of datasets to snapshot (see zrepl docs).";
      };
      cron = lib.mkOption {
        type = lib.types.str;
        example = "0 * * * *";
        description = "Cron schedule for snapshotting (every hour by default).";
      };
    };

    localJob = {
      datasets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "List of datasets to replicate locally (see zrepl docs).";
      };
      interval = lib.mkOption {
        type = lib.types.str;
        example = "1h";
        description = "Interval for local replication.";
      };
    };

    remoteJobs = {
      pull = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              address = lib.mkOption {
                type = lib.types.str;
                example = "remote.me.ow:8888";
                description = "Host and port of the remote server to pull from.";
              };
              interval = lib.mkOption {
                type = lib.types.str;
                example = "24h";
                description = "Interval for pulling from this remote server.";
              };
              bandwidthLimit = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                example = "23.5 MiB";
                description = "Bandwidth limit for pulling from this remote server.";
              };
            };
          }
        );
        default = { };
        description = "Remote servers to pull from.";
      };
      serve = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              listenAddress = lib.mkOption {
                type = lib.types.str;
                example = ":8888";
                description = "Address to serve on.";
              };
              datasets = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                description = "List of datasets to serve.";
              };
              clientAddress = lib.mkOption {
                type = lib.types.str;
                example = "100.94.1.2";
                description = "Address of the client to serve for.";
              };
            };
          }
        );
        default = { };
        description = "What to serve from this machine for remote pullers.";
      };
    };
  };

  config = lib.mkIf config.profiles.server.zrepl.enable (
    lib.mkMerge [
      (lib.mkIf config.lxc.enable {
        lxc = {
          unprivileged = lib.mkForce false;
          devices = lib.mkForce [
            "/dev/zfs"
          ];
        };
        environment.systemPackages = [
          pkgs.zfs
        ];
        systemd.services.zrepl = {
          # we need this hack because the original module expects `zfs.target` to be available, which is not the case in our lxc
          after = lib.mkForce [ ];
          wantedBy = lib.mkForce [ "multi-user.target" ];
        };
      })
      {
        assertions = [
          {
            assertion = (cfg.localJob.datasets == [ ] && cfg.remoteJobs.pull == { }) || cfg.dataset != null;
            message = "zrepl.dataset must be set when local replication or pull jobs are configured";
          }
        ];

        profiles.server.enable = lib.mkForce true;

        services.zrepl =
          let
            keepGrid = [
              {
                type = "regex";
                negate = true;
                regex = "^zrepl_";
              }
              {
                type = "grid";
                regex = "^zrepl_";
                grid = cfg.pruningKeepSchedule;
              }
            ];

            keepAll = [
              {
                type = "regex";
                regex = ".*";
              }
            ];

            mapFs =
              x:
              lib.listToAttrs (
                map (fs: {
                  name = fs;
                  value = true;
                }) x
              );
          in
          {
            enable = true;
            package = unstable.zrepl;
            settings.jobs =
              (lib.optional (cfg.snapshotting.datasets != [ ]) {
                type = "snap";
                name = "snapshot";
                filesystems = mapFs cfg.snapshotting.datasets;
                snapshotting = {
                  type = "cron";
                  cron = cfg.snapshotting.cron;
                  prefix = "zrepl_";
                };
                pruning.keep = keepGrid;
              })
              ++ (
                if cfg.localJob.datasets != [ ] then
                  [
                    {
                      type = "source";
                      name = "source-local";
                      serve = {
                        type = "local";
                        listener_name = "source-local";
                      };
                      filesystems = mapFs cfg.localJob.datasets;
                      snapshotting = {
                        type = "manual";
                      };
                    }
                    {
                      type = "pull";
                      name = "pull-local";
                      connect = {
                        type = "local";
                        listener_name = "source-local";
                        client_identity = "local";
                      };
                      recv = {
                        placeholder.encryption = "off";
                      };
                      interval = cfg.localJob.interval;
                      root_fs = cfg.dataset + "/local";
                      pruning = {
                        keep_sender = keepAll;
                        keep_receiver = keepGrid;
                      };
                    }
                  ]
                else
                  [ ]
              )
              ++ (lib.mapAttrsToList (name: job: {
                type = "pull";
                name = "pull-from-" + name;
                connect = {
                  type = "tcp";
                  address = job.address;
                };

                recv = {
                  placeholder.encryption = "off";
                }
                // (lib.optionalAttrs (job.bandwidthLimit != null) { bandwidth_limit.max = job.bandwidthLimit; });

                interval = job.interval;
                root_fs = cfg.dataset + "/" + name;
                pruning = {
                  keep_sender = keepAll;
                  keep_receiver = keepGrid;
                };
              }) cfg.remoteJobs.pull)
              ++ (lib.mapAttrsToList (name: job: {
                type = "source";
                name = "serve-for-" + name;
                serve = {
                  type = "tcp";
                  listen = job.listenAddress;
                  listen_freebind = true;
                  clients = {
                    ${job.clientAddress} = name;
                  };
                };
                send = {
                  compressed = true;
                };
                filesystems = mapFs job.datasets;
                snapshotting = {
                  type = "manual";
                };
              }) cfg.remoteJobs.serve);
          };
      }
    ]
  );
}
