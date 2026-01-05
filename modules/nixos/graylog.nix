{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.graylog;

  glPlugins = pkgs.buildEnv {
    name = "graylog-plugins";
    paths = cfg.plugins;
  };
in
{
  disabledModules = [ "services/logging/graylog.nix" ];

  options = {
    services.graylog = {
      enable = lib.mkEnableOption "Graylog, a log management solution";

      package = lib.mkPackageOption pkgs "graylog" {
        example = "graylog-6_0";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "graylog";
        description = "User account under which graylog runs";
      };

      isMaster = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether this is the master instance of your Graylog cluster";
      };

      nodeIdFile = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/graylog/server/node-id";
        description = "Path of the file containing the graylog node-id";
      };

      passwordSecret = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          You MUST set a secret to secure/pepper the stored user passwords. Use at least 64 characters.
          Generate one by using for example: pwgen -N 1 -s 96
          Consider using passwordSecretFile to avoid revealing the secret.
        '';
      };

      passwordSecretFile = lib.mkOption {
        type = lib.types.str;
        description = ''
          Path to a file containing a secret to secure/pepper the stored user passwords. Use at least 64 characters.
          Generate one by using for example: pwgen -N 1 -s 96
          When set, passwordSecret is ignored
        '';
      };

      rootUsername = lib.mkOption {
        type = lib.types.str;
        default = "admin";
        description = "Name of the default administrator user";
      };

      rootPasswordSha2 = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "e3c652f0ba0b4801205814f8b6bc49672c4c74e25b497770bb89b22cdeb4e952";
        description = ''
          You MUST specify a hash password for the root user (which you only need to initially set up the
          system and in case you lose connectivity to your authentication backend)
          This password cannot be changed using the API or via the web interface. If you need to change it,
          modify it here.
          Create one by using for example: echo -n yourpassword | shasum -a 256
          and use the resulting hash value as string for the option
          Consider using rootPasswordSha2File to avoid revealing the secret.
        '';
      };

      rootPasswordSha2File = lib.mkOption {
        type = lib.types.str;
        description = ''
          Path to a file containing a hash password for the root user (which you only need to initially set up the
          system and in case you lose connectivity to your authentication backend)
          This password cannot be changed using the API or via the web interface. If you need to change it,
          modify it here.
          Create one by using for example: echo -n yourpassword | shasum -a 256
          and use the resulting hash value as string for the option.
          When set, rootPasswordSha2 is ignored
        '';
      };

      elasticsearchHosts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "http://127.0.0.1:9200" ];
        example = lib.literalExpression ''[ "http://node1:9200" "http://user:password@node2:19200" ]'';
        description = "List of valid URIs of the http ports of your elastic nodes. If one or more of your elasticsearch hosts require authentication, include the credentials in each node URI that requires authentication";
      };

      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/graylog/data";
        description = "Directory used to store Graylog server state.";
      };

      messageJournalDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/graylog/data/journal";
        description = "The directory which will be used to store the message journal. The directory must be exclusively used by Graylog and must not contain any other files than the ones created by Graylog itself";
      };

      mongodbUri = lib.mkOption {
        type = lib.types.str;
        default = "mongodb://localhost/graylog";
        description = "MongoDB connection string. See http://docs.mongodb.org/manual/reference/connection-string/ for details";
      };

      extraConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Any other configuration options you might want to add";
      };

      plugins = lib.mkOption {
        description = "Extra graylog plugins";
        default = [ ];
        type = lib.types.listOf lib.types.package;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.graylog.passwordSecretFile = lib.mkDefault (
      assert cfg.passwordSecret != null;
      toString (
        pkgs.writeTextFile {
          name = "graylog-password-secret";
          text = cfg.passwordSecret;
        }
      )
    );

    services.graylog.rootPasswordSha2File = lib.mkDefault (
      assert cfg.rootPasswordSha2 != null;
      toString (
        pkgs.writeTextFile {
          name = "graylog-root-password-sha2";
          text = cfg.rootPasswordSha2;
        }
      )
    );

    assertions = [
      {
        assertion = cfg.passwordSecretFile != null || cfg.passwordSecret != null;
        message = "services.graylog.passwordSecretFile or services.graylog.passwordSecret must be set.";
      }
      {
        assertion = cfg.rootPasswordSha2File != null || cfg.rootPasswordSha2 != null;
        message = "services.graylog.rootPasswordSha2File or services.graylog.rootPasswordSha2 must be set.";
      }
    ];

    # Note: when changing the default, make it conditional on
    # ‘system.stateVersion’ to maintain compatibility with existing
    # systems!
    services.graylog.package =
      let
        mkThrow = ver: throw "graylog-${ver} was removed, please upgrade your graylog version.";
        base =
          if lib.versionAtLeast config.system.stateVersion "25.05" then
            pkgs.graylog-6_0
          else if lib.versionAtLeast config.system.stateVersion "23.05" then
            mkThrow "5_1"
          else
            mkThrow "3_3";
      in
      lib.mkDefault base;

    users.users = lib.mkIf (cfg.user == "graylog") {
      graylog = {
        isSystemUser = true;
        group = "graylog";
        description = "Graylog server daemon user";
      };
    };
    users.groups = lib.mkIf (cfg.user == "graylog") { graylog = { }; };

    systemd.tmpfiles.rules = [
      "d '${cfg.messageJournalDir}' - ${cfg.user} - - -"
    ];

    systemd.services.graylog =
      let
        confFile = "/run/graylog/graylog.conf";
      in
      {
        description = "Graylog Server";
        wantedBy = [ "multi-user.target" ];
        environment = {
          GRAYLOG_CONF = confFile;
        };
        path = [
          pkgs.which
          pkgs.procps
        ];
        preStart = ''
          cat > ${confFile} <<EOF
          is_master = ${lib.boolToString cfg.isMaster}
          node_id_file = ${cfg.nodeIdFile}
          password_secret = $(cat ${cfg.passwordSecretFile})
          root_username = ${cfg.rootUsername}
          root_password_sha2 = $(cat ${cfg.rootPasswordSha2File})
          elasticsearch_hosts = ${lib.concatStringsSep "," cfg.elasticsearchHosts}
          message_journal_dir = ${cfg.messageJournalDir}
          mongodb_uri = ${cfg.mongodbUri}
          plugin_dir = /var/lib/graylog/plugins
          data_dir = ${cfg.dataDir}

          ${cfg.extraConfig}
          EOF

          chmod 0600 ${confFile}

          rm -rf /var/lib/graylog/plugins || true
          mkdir -p /var/lib/graylog/plugins -m 755

          mkdir -p "$(dirname ${cfg.nodeIdFile})"
          chown -R ${cfg.user} "$(dirname ${cfg.nodeIdFile})"

          for declarativeplugin in `ls ${glPlugins}/bin/`; do
            ln -sf ${glPlugins}/bin/$declarativeplugin /var/lib/graylog/plugins/$declarativeplugin
          done
          for includedplugin in `ls ${cfg.package}/plugin/`; do
            ln -s ${cfg.package}/plugin/$includedplugin /var/lib/graylog/plugins/$includedplugin || true
          done
        '';
        serviceConfig = {
          User = "${cfg.user}";
          StateDirectory = "graylog";
          RuntimeDirectory = "graylog";
          RuntimeDirectoryMode = "0700";
          ExecStart = "${cfg.package}/bin/graylogctl run";
        };
      };
  };
}
