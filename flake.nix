{
  description = "Developer sandbox offers a lightweight isolated environment. Helpful for AI assisted coding";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    let
      # NixOS module output (not system-specific)
      nixosModule = import ./module.nix;
    in
    {
      # Export NixOS module
      nixosModules.dev-sandbox = nixosModule;
      nixosModules.default = nixosModule;
    }
    // flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;

        # Import shared variant defaults
        variants = import ./variants.nix { inherit pkgs; };

        # Simple wrapper around default.nix with makeOverridable
        mkDevSandbox = lib.makeOverridable (
          {
            name ? "dev-sandbox",
            runCommand ? [ ],
            binds ? [ ],
            roBinds ? [ ],
            extraArgs ? [ ],
            envs ? { },
            extraRuntimeInputs ? [ ],
          }:
          pkgs.callPackage ./default.nix {
            inherit
              name
              runCommand
              binds
              roBinds
              extraArgs
              envs
              extraRuntimeInputs
              ;
          }
        );

        # Create packages using variant defaults
        devSandbox = mkDevSandbox variants.default;

        claudeSandbox = mkDevSandbox variants.claude;

        codexSandbox = mkDevSandbox variants.codex;
      in
      {
        packages.dev-sandbox = devSandbox;
        packages.default = devSandbox;
        packages.dev-sandbox-claude = claudeSandbox;
        packages.dev-sandbox-codex = codexSandbox;

        apps.claude = {
          type = "app";
          program = lib.getExe claudeSandbox;
        };

        apps.codex = {
          type = "app";
          program = lib.getExe codexSandbox;
        };

        apps.default = {
          type = "app";
          program = lib.getExe devSandbox;
        };
      }
    );
}
