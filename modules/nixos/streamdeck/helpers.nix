{ lib, allAttributes }:
let
  inherit (lib) mkOption types filterAttrs;

  cleanAttrs =
    value:
    if builtins.isAttrs value then
      lib.mapAttrs (_: cleanAttrs) (lib.filterAttrs (_: v: v != null) value)
    else if builtins.isList value then
      builtins.map cleanAttrs value
    else
      value;

  renameKeys =
    d: r:
    let
      renameKey = key: if builtins.hasAttr key r then r.${key} else key;
      transform =
        x:
        if lib.isAttrs x then
          renameKeys x r
        else if lib.isList x then
          lib.map (y: if lib.isAttrs y then renameKeys y r else y) x
        else
          x;
    in
    lib.foldl' (
      acc: k:
      let
        newKey = renameKey k;
        val = transform (d.${k});
      in
      acc // { "${newKey}" = val; }
    ) { } (lib.attrNames d);
in
{
  mkColorOption =
    description:
    mkOption {
      inherit description;
      type = types.nullOr (
        types.addCheck (types.listOf (types.ints.between 0 255)) (x: builtins.length x == 4)
      );
      default = null;
      example = [
        244
        32
        105
        255
      ];
    };

  mkAttributesOption =
    description: attrs:
    mkOption {
      inherit description;
      type = types.nullOr (
        types.submodule {
          options = filterAttrs (name: _: lib.elem name attrs) allAttributes;
        }
      );
      default = null;
    };

  transformPage =
    let
      transformModule =
        moduleAttrs:
        let
          names = lib.attrNames (filterAttrs (_: v: v != null) moduleAttrs);
        in
        if lib.length names == 1 then
          let
            typeName = lib.head names;
          in
          {
            type = typeName;
            attributes = moduleAttrs.${typeName};
          }
        else
          throw "Each display/action must have exactly one type configured. You configured multiple or no types at all.";

      transformKey =
        name: keyAttrs:
        keyAttrs
        // {
          display = transformModule keyAttrs.display;
          actions = lib.map (action: transformModule action) keyAttrs.actions;
        };
    in
    name: pageAttrs:
    pageAttrs
    // {
      keys = lib.mapAttrs transformKey pageAttrs.keys;
    };

  inherit cleanAttrs renameKeys;
}
