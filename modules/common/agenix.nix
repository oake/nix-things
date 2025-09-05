{
  inputs,
  lib,
  hostName,
  config,
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
      (lib.mkIf (!config.age.ready) ''
        After initial target provisioning, fetch the target ssh identity:

          ssh-keyscan -qt ssh-ed25519 $target | cut -d' ' -f2,3 > ./${publicKeyRelPath}

        And rebuild NixOS.
      '')
    ];

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
