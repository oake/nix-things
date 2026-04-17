# shamelessly stolen from https://github.com/numtide/blueprint/blob/main/lib/default.nix
# stripped down, with lots of weird nix-things specific things added
# don't use this unless you are an oake
#
{ inputs, ... }:
# Blueprint entrypoint
let
  bpInputs = inputs;
  nixpkgs = bpInputs.nixpkgs;
  lib = nixpkgs.lib;
  defaultSystems = [
    "aarch64-linux"
    "x86_64-linux"
    "aarch64-darwin"
  ];

  # A generator for the top-level attributes of the flake.
  #
  # Designed to work with https://github.com/nix-systems
  mkEachSystem =
    {
      inputs,
      flake,
      systems,
      nixpkgs,
      extraOverlays ? [ ],
      unfilteredPackages,
    }:
    let
      # Memoize the args per system
      systemArgs = lib.genAttrs systems (
        system:
        let
          pkgs = mkConfiguredPkgs {
            input = inputs.nixpkgs;
            inherit system nixpkgs extraOverlays;
          };
        in
        lib.makeScope lib.callPackageWith (_: {
          inherit
            inputs
            flake
            pkgs
            system
            ;
        })
      );

      eachSystem = f: lib.genAttrs systems (system: f systemArgs.${system});
    in
    {
      inherit systemArgs eachSystem;
    };

  optionalPathAttrs = path: f: lib.optionalAttrs (builtins.pathExists path) (f path);

  tryImport = path: args: optionalPathAttrs path (path: import path args);

  # Maps all the nix files and folders in a directory to name -> path.
  importDir =
    path: fn:
    let
      entries = builtins.readDir path;

      # Get paths to directories
      onlyDirs = lib.filterAttrs (_name: type: type == "directory") entries;
      dirPaths = lib.mapAttrs (name: type: {
        path = path + "/${name}";
        inherit type;
      }) onlyDirs;

      # Get paths to nix files, where the name is the basename of the file without the .nix extension
      nixPaths = removeAttrs (lib.mapAttrs' (
        name: type:
        let
          nixName = builtins.match "(.*)\\.nix" name;
        in
        {
          name = if type == "directory" || nixName == null then "__junk" else (builtins.head nixName);
          value = {
            path = path + "/${name}";
            type = type;
          };
        }
      ) entries) [ "__junk" ];

      # Have the nix files take precedence over the directories
      combined = dirPaths // nixPaths;
    in
    lib.optionalAttrs (builtins.pathExists path) (fn combined);

  entriesPath = lib.mapAttrs (_name: { path, type }: path);

  # Prefixes all the keys of an attrset with the given prefix
  withPrefix =
    prefix:
    lib.mapAttrs' (
      name: value: {
        name = "${prefix}${name}";
        value = value;
      }
    );

  withDefaultModule =
    modules:
    modules
    // {
      default = {
        imports = lib.attrValues (removeAttrs modules [ "default" ]);
      };
    };

  mkConfiguredPkgs =
    {
      input,
      system,
      nixpkgs,
      extraOverlays ? [ ],
    }:
    if (nixpkgs.config or { }) == { } && (nixpkgs.overlays or [ ]) == [ ] && extraOverlays == [ ] then
      input.legacyPackages.${system}
    else
      import input {
        inherit system;
        config = nixpkgs.config or { };
        overlays = (nixpkgs.overlays or [ ]) ++ extraOverlays;
      };

  filterPlatforms =
    system: attrs:
    lib.filterAttrs (
      _: x:
      if (x.meta.platforms or [ ]) == [ ] then
        true # keep every package that has no meta.platforms
      else
        lib.elem system x.meta.platforms
    ) attrs;

  mkBlueprint' =
    {
      inputs,
      nixpkgs,
      flake,
      src,
      systems,
    }:
    let
      blueprintRoot = ../.;

      specialArgs = {
        inherit inputs flake;
        self = throw "self was renamed to flake";
      };

      packageEntriesFor =
        root:
        (optionalPathAttrs (root + "/packages") (path: importDir path lib.id))
        // (optionalPathAttrs (root + "/package.nix") (path: {
          default = {
            inherit path;
          };
        }));

      consumerPackageEntries = packageEntriesFor src;
      overlayPackageEntries = packageEntriesFor blueprintRoot // consumerPackageEntries;

      mkPackagesForEntries =
        packageEntries: pkgs:
        let
          system = pkgs.stdenv.hostPlatform.system;
          scope = lib.makeScope lib.callPackageWith (self: {
            inherit
              inputs
              flake
              pkgs
              system
              ;
            # NB: lib.makeScope reserves `packages` for its generator
            # function, so the result lives under a different name.
            packageSet = lib.mapAttrs (
              pname: { path, ... }: self.newScope { inherit pname; } path { }
            ) packageEntries;
          });
        in
        scope.packageSet;

      mkOverlayPackagesFor = mkPackagesForEntries overlayPackageEntries;

      packagesOverlay = final: _prev: mkOverlayPackagesFor final;

      inherit
        (mkEachSystem {
          inherit
            inputs
            flake
            nixpkgs
            systems
            ;
          extraOverlays = [ packagesOverlay ];
          inherit
            unfilteredPackages
            ;
        })
        eachSystem
        systemArgs
        ;

      sharedPkgs = {
        stable = eachSystem ({ pkgs, ... }: pkgs);
      }
      // lib.optionalAttrs (builtins.hasAttr "nix-unstable" inputs) {
        unstable = lib.genAttrs systems (
          system:
          mkConfiguredPkgs {
            input = inputs.nix-unstable;
            inherit system nixpkgs;
            extraOverlays = [ packagesOverlay ];
          }
        );
      };

      # Share the per-system pkgs blueprint already instantiated, and expose
      # a matching unstable package set when available.
      hostDefaultsModule =
        { config, lib, ... }:
        {
          nixpkgs.pkgs = lib.mkDefault systemArgs.${config.nixpkgs.hostPlatform.system}.pkgs;
          _module.args = lib.optionalAttrs (builtins.hasAttr "nix-unstable" inputs) {
            unstable = sharedPkgs.unstable.${config.nixpkgs.hostPlatform.system};
          };
        };

      home-manager =
        inputs.home-manager
          or (throw ''home configurations require Home Manager. To fix this, add `inputs.home-manager.url = "github:nix-community/home-manager";` to your flake'');

      # Sets up declared users without any user intervention, and sets the
      # options that most people would set anyway. The module is only returned
      # if home-manager is an input and the host has at least one user with a
      # home manager configuration. With this module, most users will not need
      # to manually configure Home Manager at all.
      mkHomeUsersModule =
        hostname: homeManagerModule:
        let
          module =
            { config, ... }:
            {
              imports = [ homeManagerModule ];
              home-manager.extraSpecialArgs = specialArgs;
              home-manager.users = homesNested.${hostname};
              home-manager.useGlobalPkgs = lib.mkDefault true;
              home-manager.useUserPackages = lib.mkDefault true;
            };
        in
        lib.optional (builtins.hasAttr hostname homesNested) module;

      # Attribute set mapping hostname (defined in hosts/) to a set of home
      # configurations (modules) for that host. If a host has no home
      # configuration, it will be omitted from the set. Likewise, if the user
      # directory does not contain a home-configuration.nix file, it will
      # be silently omitted - not defining a configuration is not an error.
      homesNested =
        let
          getEntryPath =
            _username: userEntry:
            if userEntry.type == "regular" then
              userEntry.path
            else if builtins.pathExists (userEntry.path + "/home-configuration.nix") then
              userEntry.path + "/home-configuration.nix"
            else
              null;

          # Returns an attrset mapping username to home configuration path. It may be empty
          # if no users have a home configuration.
          mkHostUsers =
            userEntries:
            let
              hostUsers = lib.mapAttrs getEntryPath userEntries;
            in
            lib.filterAttrs (_name: value: value != null) hostUsers;

          mkHosts =
            hostEntries:
            let
              hostDirs = lib.filterAttrs (_: entry: entry.type == "directory") hostEntries;
              hostToUsers = _hostname: entry: importDir (entry.path + "/users") mkHostUsers;
              hosts = lib.mapAttrs hostToUsers hostDirs;
            in
            lib.filterAttrs (_hostname: users: users != { }) hosts;
        in
        importDir (src + "/hosts") mkHosts;

      hosts = importDir (src + "/hosts") (
        entries:
        let
          loadDefaultFn = { class, value }@inputs: inputs;

          loadDefault = hostName: path: loadDefaultFn (import path { inherit flake inputs hostName; });

          loadNixOS = hostName: path: {
            class = "nixos";
            value = inputs.nixpkgs.lib.nixosSystem {
              modules = [
                hostDefaultsModule
                path
              ]
              ++ mkHomeUsersModule hostName home-manager.nixosModules.default;
              specialArgs = specialArgs // {
                inherit hostName;
              };
            };
          };

          loadNixOSRPi =
            hostName: path:
            let
              nixos-raspberrypi =
                inputs.nixos-raspberrypi
                  or (throw ''${path} depends on nixos-raspberrypi. To fix this, add `inputs.nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi";` to your flake'');
            in
            {
              class = "nixos";
              value = nixos-raspberrypi.lib.nixosSystem {
                modules = [
                  hostDefaultsModule
                  path
                ]
                ++ mkHomeUsersModule hostName home-manager.nixosModules.default;
                specialArgs = specialArgs // {
                  inherit hostName;
                  nixos-raspberrypi = inputs.nixos-raspberrypi;
                };
              };
            };

          loadNixDarwin =
            hostName: path:
            let
              nix-darwin =
                inputs.nix-darwin
                  or (throw ''${path} depends on nix-darwin. To fix this, add `inputs.nix-darwin.url = "github:Lnl7/nix-darwin";` to your flake'');
            in
            {
              class = "nix-darwin";
              value = nix-darwin.lib.darwinSystem {
                modules = [
                  hostDefaultsModule
                  path
                ]
                ++ mkHomeUsersModule hostName home-manager.darwinModules.default;
                specialArgs = specialArgs // {
                  inherit hostName;
                };
              };
            };

          loadHost =
            name:
            { path, type }:
            if builtins.pathExists (path + "/default.nix") then
              loadDefault name (path + "/default.nix")
            else if builtins.pathExists (path + "/configuration.nix") then
              loadNixOS name (path + "/configuration.nix")
            else if builtins.pathExists (path + "/rpi-configuration.nix") then
              loadNixOSRPi name (path + "/rpi-configuration.nix")
            else if builtins.pathExists (path + "/darwin-configuration.nix") then
              loadNixDarwin name (path + "/darwin-configuration.nix")
            else if builtins.hasAttr name homesNested then
              # If there are any home configurations defined for this host, they
              # must be standalone configurations since there is no OS config.
              # No config should be returned, but no error should be thrown either.
              null
            else
              throw "host '${name}' does not have a configuration";

          hostsOrNull = lib.mapAttrs loadHost entries;
        in
        lib.filterAttrs (_n: v: v != null) hostsOrNull
      );

      hostsByCategory = lib.mapAttrs (_: hosts: lib.listToAttrs hosts) (
        lib.groupBy (
          x:
          if x.value.class == "nixos" then
            "nixosConfigurations"
          else if x.value.class == "nix-darwin" then
            "darwinConfigurations"
          else
            throw "host '${x.name}' of class '${x.value.class or "unknown"}' not supported"
        ) (lib.attrsToList hosts)
      );

      darwinConfigurations = lib.mapAttrs (_: x: x.value) (hostsByCategory.darwinConfigurations or { });
      nixosConfigurations = lib.mapAttrs (_: x: x.value) (hostsByCategory.nixosConfigurations or { });
      allHostConfigurations = nixosConfigurations // darwinConfigurations;

      publisherArgs = {
        inherit flake inputs;
      };

      expectsPublisherArgs =
        module:
        builtins.isFunction module
        && builtins.all (arg: builtins.elem arg (builtins.attrNames publisherArgs)) (
          builtins.attrNames (builtins.functionArgs module)
        );

      # Checks if the given module is wrapped in a function accepting one or more of publisherArgs.
      # If so, call that function. This allows modules to refer to the flake where it is
      # defined, while the module arguments "flake" and "inputs" refer to the flake where the
      # module is consumed.
      injectPublisherArgs =
        modulePath:
        let
          module = import modulePath;
        in
        if expectsPublisherArgs module then
          lib.setDefaultModuleLocation modulePath (module publisherArgs)
        else
          modulePath;

      modules =
        let
          moduleNamespacesFor =
            root:
            let
              path = root + "/modules";
            in
            if builtins.pathExists path then
              let
                moduleDirs = builtins.attrNames (
                  lib.filterAttrs (_name: value: value == "directory") (builtins.readDir path)
                );
              in
              lib.genAttrs moduleDirs (
                name:
                lib.mapAttrs (_name: moduleDir: injectPublisherArgs moduleDir) (
                  importDir (path + "/${name}") entriesPath
                )
              )
            else
              { };
        in
        lib.mapAttrs (_: withDefaultModule) (moduleNamespacesFor src);

      # See the comment in mkEachSystem
      unfilteredPackages = lib.traceIf (builtins.pathExists (
        src + "/pkgs"
      )) "blueprint: the /pkgs folder is now /packages" (eachSystem ({ pkgs, ... }: mkPackagesFor pkgs));

      # Load the packages/ tree against a given nixpkgs instance.
      # Packages get the same scope arguments as via systemArgs
      # (pkgs, flake, inputs, system, pname).
      #
      # Used internally for packages.<system> (with blueprint's own
      # pkgs) and exposed so consumers can build an overlay that uses
      # their pkgs instead.
      mkPackagesFor = mkPackagesForEntries consumerPackageEntries;

      packages = lib.mapAttrs filterPlatforms unfilteredPackages;

      mkDiskoChecks =
        cfgs:
        let
          withDisko = lib.filterAttrs (_: c: c.config.disko.simple.device != null) cfgs;
        in
        lib.foldl' (
          acc: name:
          let
            c = withDisko.${name};
            sys = c.pkgs.stdenv.hostPlatform.system;
          in
          lib.recursiveUpdate acc { ${sys}."disko-${name}" = c.config.system.build.diskoScript; }
        ) { } (builtins.attrNames withDisko);

      mkDeployNodes =
        cfgs:
        let
          deployCfgs = lib.filterAttrs (_: c: c.config.deploy.enable) cfgs;
          deploy-rs =
            if builtins.attrNames deployCfgs == [ ] then
              null
            else
              inputs.deploy-rs
                or (throw ''deploy configurations require deploy-rs. To fix this, add `inputs.deploy-rs.url = "github:serokell/deploy-rs";` to your flake'');
          mkActivate =
            cfg:
            let
              inherit (cfg.pkgs.stdenv) isDarwin;
              system = cfg.pkgs.stdenv.hostPlatform.system;
            in
            deploy-rs.lib.${system}.activate.${if isDarwin then "darwin" else "nixos"} cfg;
          nodes = lib.mapAttrs (_: cfg: {
            hostname = cfg.config.deploy.fqdn;
            profiles.system = {
              sshUser = "deploy";
              user = "root";
              path = mkActivate cfg;
            };
          }) deployCfgs;
          checks = lib.foldl' lib.recursiveUpdate { } (
            lib.mapAttrsToList (name: cfg: {
              ${cfg.pkgs.stdenv.hostPlatform.system} = {
                "deploy-${name}" = mkActivate cfg;
              };
            }) deployCfgs
          );
        in
        {
          inherit nodes checks;
        };

      mkPerHostScripts =
        mkScript: cfgs:
        let
          builderSystem = "x86_64-linux";
          builderPkgs = sharedPkgs.stable.${builderSystem};

          apps = eachSystem (
            { pkgs, ... }:
            pkgs.lib.mapAttrs' (
              name: cfg:
              let
                drv = mkScript pkgs pkgs name cfg;
              in
              {
                name = drv.name;
                value = {
                  type = "app";
                  program = "${drv}/bin/${drv.name}";
                  meta.description = "Helper script ${drv.name}";
                };
              }
            ) cfgs
          );

          checks =
            if builtins.attrNames cfgs == [ ] then
              { }
            else
              {
                ${builderSystem} = builderPkgs.lib.mapAttrs' (
                  name: cfg:
                  let
                    perTarget = lib.genAttrs systems (
                      system: mkScript builderPkgs sharedPkgs.stable.${system} name cfg
                    );
                    scriptName = perTarget.${builderSystem}.name;
                    checkDrv = builderPkgs.linkFarm scriptName (
                      lib.mapAttrsToList (system: drv: {
                        name = "bin/${drv.name}-${system}";
                        path = "${drv}/bin/${drv.name}";
                      }) perTarget
                    );
                  in
                  {
                    name = scriptName;
                    value = checkDrv;
                  }
                ) cfgs;
              };
        in
        {
          inherit apps checks;
        };

      bootstrapScripts = mkPerHostScripts (import ./scripts/bootstrap.nix) nixosConfigurations;

      lxcScripts = mkPerHostScripts (import ./scripts/install-lxc.nix) (
        lib.filterAttrs (_: c: c.config.lxc.enable) nixosConfigurations
      );

      deployCfgs = mkDeployNodes allHostConfigurations;

      apps = lib.foldl' lib.recursiveUpdate bootstrapScripts.apps [ lxcScripts.apps ];

      extraChecks = lib.foldl' lib.recursiveUpdate { } [
        (mkDiskoChecks nixosConfigurations)
        bootstrapScripts.checks
        lxcScripts.checks
        deployCfgs.checks
      ];
    in
    # FIXME: maybe there are two layers to this. The blueprint, and then the mapping to flake outputs.
    {
      formatter = eachSystem ({ pkgs, ... }: pkgs.nixfmt-tree);

      lib = tryImport (src + "/lib") specialArgs;

      # See the comment in mkEachSystem
      inherit packages;

      inherit darwinConfigurations nixosConfigurations;

      commonModules = modules.common or { };
      darwinModules = modules.darwin or { };
      homeModules = modules.home or { };
      # TODO: how to extract NixOS tests?
      nixosModules = modules.nixos or { };

      inherit apps;

      deploy = {
        nodes = deployCfgs.nodes;
      };

      checks = lib.recursiveUpdate (eachSystem (
        { system, pkgs, ... }:
        let
          formatterCheck = pkgs.runCommand "formatter-check" { buildInputs = [ pkgs.nixfmt-tree ]; } ''
            treefmt --ci ${src} && touch "$out"
          '';
        in
        lib.mergeAttrsList ([
          (lib.optionalAttrs (system == "x86_64-linux") {
            formatting = formatterCheck;
          })
          # add all the supported packages, and their passthru.tests to checks
          (withPrefix "pkgs-" (
            lib.concatMapAttrs (
              pname: package:
              {
                ${pname} = package;
              }
              # also add the passthru.tests to the checks
              // (lib.mapAttrs' (tname: test: {
                name = "${pname}-${tname}";
                value = test;
              }) (filterPlatforms system (package.passthru.tests or { })))
            ) (filterPlatforms system (packages.${system} or { }))
          ))
          # add nixos system closures to checks
          (withPrefix "nixos-" (
            lib.mapAttrs (_: x: x.config.system.build.toplevel) (
              lib.filterAttrs (_: x: x.pkgs.stdenv.hostPlatform.system == system) nixosConfigurations
            )
          ))
          # add darwin system closures to checks
          (withPrefix "darwin-" (
            lib.mapAttrs (_: x: x.system) (
              lib.filterAttrs (_: x: x.pkgs.stdenv.hostPlatform.system == system) darwinConfigurations
            )
          ))
          # load checks from the /checks folder. Those take precedence over the others.
          (filterPlatforms system (
            optionalPathAttrs (src + "/checks") (
              path:
              let
                importChecksFn = lib.mapAttrs (
                  pname: { type, path }: import path (systemArgs.${system} // { inherit pname; })
                );
              in

              (importDir path importChecksFn)
            )
          ))
        ])
      )) extraChecks;
    };

  # Create a new flake
  mkFlake =
    {
      # Pass the flake inputs to blueprint
      inputs,
      # Used to configure nixpkgs
      nixpkgs ? { },
      # The systems to generate the flake for
      systems ? (inputs.systems or defaultSystems),
    }:
    mkBlueprint' {
      inputs = bpInputs // inputs;
      flake = inputs.self;

      nixpkgs = lib.recursiveUpdate {
        config.allowUnfree = true;
      } nixpkgs;

      src = inputs.self;

      # Make compatible with github:nix-systems/default
      systems = if lib.isList systems then systems else import systems;
    };
in
{
  inherit mkFlake;
}
