{
  inputs,
  lib,
  hostName,
  config,
  pkgs,
  ...
}:
let
  publicKeyRelPath = "secrets/public-keys/${hostName}.pub";
  publicKeyAbsPath = inputs.self.outPath + "/" + publicKeyRelPath;
in
{
  options = {
    age.ready = lib.mkOption {
      type = lib.types.bool;
      default = builtins.pathExists publicKeyAbsPath;
      readOnly = true;
      internal = true;
    };
    age.rekey.hostPubkeyRelPath = lib.mkOption {
      type = lib.types.str;
      default = publicKeyRelPath;
      readOnly = true;
      internal = true;
    };
  };
  config = {
    warnings = [
      (lib.mkIf (!config.age.ready) "No agenix public key provided. Secrets won't be decrypted.")
    ];

    age.identityPaths = lib.mkDefault [ "/etc/agenix_pq_key" ];

    age.rekey = {
      localStorageDir = inputs.self.outPath + "/secrets/rekeyed/${hostName}";
      secretsDir = inputs.self.outPath + "/secrets/secrets";
      storageMode = "local";
    }
    // lib.optionalAttrs config.age.ready {
      hostPubkey = builtins.readFile publicKeyAbsPath;
    };
  };
}
