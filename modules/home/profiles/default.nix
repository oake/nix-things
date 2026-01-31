{
  lib,
  config,
  ...
}:
{
  imports = [
    ./workstation
  ];

  config.assertions = [
    {
      assertion = (lib.count (p: p.enable) (builtins.attrValues config.profiles)) <= 1;
      message = "Only one core profile can be enabled at a time (profiles.<name>.enable).";
    }
  ];
}
