{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.dev-sandbox;

  # Import shared variant defaults
  variants = import ./variants.nix { inherit pkgs; };

  # Helper to merge common and instance-specific options
  mergeInstanceConfig = instanceCfg: {
    name = instanceCfg.name;
    binds = cfg.binds ++ instanceCfg.binds;
    roBinds = cfg.roBinds ++ instanceCfg.roBinds;
    symlinks = cfg.symlinks // instanceCfg.symlinks;
    envs = cfg.envs // instanceCfg.envs;
    extraArgs = cfg.extraArgs ++ instanceCfg.extraArgs;
    runCommand = instanceCfg.runCommand;
    extraRuntimeInputs = instanceCfg.extraRuntimeInputs;
  };

  # Create instance options with variant-specific defaults
  mkInstanceOptions =
    variantDefaults:
    lib.mkOption {
      default = {};
      type = lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "this dev-sandbox instance";

          name = lib.mkOption {
            type = lib.types.str;
            default = variantDefaults.name;
            description = "Name of the executable binary";
            example = "dev-sandbox-custom";
          };

          binds = lib.mkOption {
            type = lib.types.listOf (lib.types.either lib.types.str (lib.types.listOf lib.types.str));
            default = variantDefaults.binds;
            description = "Additional paths to bind read-write (merged with common binds)";
            example = [
              "$HOME/.claude.json"
              [
                "$HOME/.histfile"
                "$HOME/my_history"
              ]
            ];
          };

          roBinds = lib.mkOption {
            type = lib.types.listOf (lib.types.either lib.types.str (lib.types.listOf lib.types.str));
            default = variantDefaults.roBinds;
            description = "Additional paths to bind read-only (merged with common roBinds)";
            example = [ "$HOME/.bashrc" ];
          };

          symlinks = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = variantDefaults.symlinks;
            description = "Symlinks to create in sandbox where keys are link paths and values are targets (merged with common symlinks)";
            example = {
              "/usr/bin/python" = "/nix/store/.../bin/python";
            };
          };

          envs = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = variantDefaults.envs;
            description = "Additional environment variables (merged with common envs)";
            example = {
              EDITOR = "vim";
            };
          };

          extraArgs = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = variantDefaults.extraArgs;
            description = "Additional bwrap arguments (merged with common extraArgs)";
            example = [
              "--hostname"
              "sandbox"
            ];
          };

          runCommand = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = variantDefaults.runCommand;
            description = "Command to run in sandbox (defaults to user shell if empty)";
            example = [
              "claude"
              "--dangerously-skip-permissions"
            ];
          };

          extraRuntimeInputs = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = variantDefaults.extraRuntimeInputs;
            description = "Additional packages to include in the sandbox environment";
            example = [
              pkgs.git
              pkgs.nodejs
            ];
          };
        };
      };
    };

  mkSandboxPackage =
    instanceName: instanceCfg:
    let
      mergedConfig = mergeInstanceConfig instanceCfg;
    in
    pkgs.callPackage ./default.nix {
      inherit (mergedConfig)
        name
        binds
        roBinds
        symlinks
        envs
        extraArgs
        runCommand
        extraRuntimeInputs
        ;
    };

  enabledInstances = lib.filterAttrs (name: cfg: cfg.enable) {
    inherit (cfg) default claude codex;
  };

  sandboxPackages = lib.mapAttrsToList mkSandboxPackage enabledInstances;

in
{
  options.programs.dev-sandbox = {
    # Common options applied to all instances
    binds = lib.mkOption {
      type = lib.types.listOf (lib.types.either lib.types.str (lib.types.listOf lib.types.str));
      default = [ ];
      description = "Common paths to bind read-write in all sandbox instances";
      example = [
        "$HOME/.config/common"
        [
          "$HOME/.histfile"
          "$HOME/my_history"
        ]
      ];
    };

    roBinds = lib.mkOption {
      type = lib.types.listOf (lib.types.either lib.types.str (lib.types.listOf lib.types.str));
      default = [ ];
      description = "Common paths to bind read-only in all sandbox instances";
      example = [
        "$HOME/.bashrc"
        "$HOME/.zshrc"
      ];
    };

    symlinks = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Common symlinks to create in all sandbox instances where keys are link paths and values are targets";
      example = {
        "/usr/bin/python" = "/nix/store/.../bin/python";
      };
    };

    envs = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Common environment variables for all sandbox instances";
      example = {
        EDITOR = "vim";
        TERM = "xterm-256color";
      };
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Common bwrap arguments for all sandbox instances";
      example = [
        "--hostname"
        "sandbox"
      ];
    };

    # Instance-specific configurations
    default = mkInstanceOptions variants.default;

    claude = mkInstanceOptions variants.claude;

    codex = mkInstanceOptions variants.codex;
  };

  config = lib.mkIf (enabledInstances != { }) {
    environment.systemPackages = sandboxPackages;
  };
}
