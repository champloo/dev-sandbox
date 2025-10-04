# dev-sandbox

## Project Overview

This is a **Nix Flake** project that provides lightweight sandboxed development environments using [Bubblewrap](https://github.com/containers/bubblewrap). It's specifically designed to isolate the host system when running AI coding assistants like Claude Code.

## Architecture

- **Language**: Nix expression language
- **Main file**: `flake.nix` - contains all package logic
- **Output**: Shell script wrapper that invokes `bwrap` with configured arguments

## How It Works

1. The flake defines a `mkDevSandbox` function that accepts configuration options
2. It generates a bash script using `pkgs.writeShellApplication`
3. The script builds `bwrap` arguments based on configuration
4. At runtime, it creates synthetic home/tmp directories and runs the command in isolation

## Key Files

- `flake.nix` - Flake entry point, exports packages and NixOS module (~75 lines)
- `default.nix` - Package builder, generates the sandbox script
- `module.nix` - NixOS module definition with declarative configuration
- `variants.nix` - Shared default configurations for different sandbox variants
- `flake.lock` - Nix dependency lock file
- `README.md` - User-facing documentation
- `.gitignore` - Ignores build artifacts (`result`)

## Development Workflow

### Testing Changes

```bash
# Build the package
nix build

# Run with default config
nix run

# Run the Claude Code variant
nix run .#claude

# Test with verbose output
VERBOSE=1 nix run

# Test NixOS module evaluation
nix eval .#nixosModules.default
```

### Making Changes

**Package Logic** (`default.nix`):
- Contains the script template and build logic
- Accepts configuration parameters (binds, roBinds, envs, etc.)
- Generates the final bash script using `writeShellApplication`

**Variant Defaults** (`variants.nix`):
- Defines default configurations for different sandbox types
- Currently has `default` (empty) and `claude` (preconfigured) variants
- Shared by both module and flake to avoid duplication

**NixOS Module** (`module.nix`):
- Defines declarative options for `programs.dev-sandbox`
- Supports common options + per-instance configuration
- Imports variants and applies defaults to each instance type
- Merges common and instance-specific configs before building packages

**Flake Entry** (`flake.nix`):
- Exports `nixosModules.dev-sandbox` and `nixosModules.default`
- Defines two pre-built package variants using `variants.nix` defaults
- Uses `lib.makeOverridable` to allow runtime customization

## Configuration Options

- `runCommand` - Array of command + args to execute (default: user's shell)
- `binds` - R/W bind mounts (can be string or [src, dst] pair)
- `roBinds` - Read-only bind mounts
- `envs` - Environment variables to set
- `extraArgs` - Additional bwrap flags
- `extraRuntimeInputs` - Additional Nix packages to include

## Sandbox Isolation Details

**Isolated**:
- User namespace
- PID namespace
- UTS namespace
- IPC namespace
- All namespaces except network

**Not Isolated**:
- Network (needed for API calls)

**Default Mounts**:
- R/W: Current directory, synthetic `/home/$USER`, synthetic `/tmp`
- R/O: `/nix`, `/bin/sh`, `/usr/bin/env`, `/run/current-system/sw` (NixOS)
- Special: `/etc/resolv.conf` for DNS

## Environment Variables Set

- `DEV_SANDBOX=enabled` - Detection flag
- SSL cert variables point to `cacert` bundle
- `PATH`, `HOME`, `USER`, `LOGNAME`, `TERM` inherited/set

## Testing Approach

When making changes:
1. Verify the generated script syntax is valid bash
2. Test that bwrap arguments are correctly formatted
3. Ensure bind paths are properly normalized (string vs array handling)
4. Check both default and Claude variants work
5. Validate on both x86_64-linux and aarch64-linux if possible

## Nix Patterns Used

- `lib.makeOverridable` - Allows users to override configuration
- `writeShellApplication` - Creates executable with runtime dependencies
- `concatStringsSep` - Builds dynamic script sections from config
- `mapAttrsToList` - Transforms envs attrset to setenv args

## Common Tasks

- **Add new config option**:
  1. Add parameter to `default.nix` function signature
  2. Add to variant defaults in `variants.nix` if applicable
  3. Add option to `module.nix` (both common and instance-level if applicable)
  4. Use in script template in `default.nix`

- **Add new variant type**:
  1. Add variant definition to `variants.nix` with defaults
  2. Add instance option in `module.nix` using `mkInstanceOptions variants.yourVariant`
  3. Add to `enabledInstances` filter
  4. Optionally create package in `flake.nix` using `mkDevSandbox variants.yourVariant`

- **Add new runtime tool**: Include in `runtimeInputs` array in `default.nix`

- **Change default mounts**: Modify the `args` array in script template in `default.nix`

- **Create new variant**:
  - For packages: Add new definition in `flake.nix` like `claudeSandbox`
  - For module: Add new instance option in `module.nix`

- **Add new instance type to module**:
  1. Add new option in `module.nix` options section (e.g., `programs.dev-sandbox.myinstance`)
  2. Add to `enabledInstances` filter in module.nix config section

## NixOS Module Architecture

The module provides a declarative interface with:

**Common options** (`programs.dev-sandbox.*`):
- Apply to ALL sandbox instances
- Useful for system-wide settings (editor, shell config, etc.)

**Instance options** (`programs.dev-sandbox.<instance>.*`):
- Per-instance configuration
- Inherits + merges with common options
- Lists are concatenated, attrs are merged (instance overrides common)

**Current instances**:
- `default` - Generic sandbox
- `claude` - Claude Code-specific sandbox

**Merging behavior**:
```nix
programs.dev-sandbox.binds = [ "A" ];
programs.dev-sandbox.claude.binds = [ "B" ];
# Result: claude sandbox gets [ "A" "B" ]

programs.dev-sandbox.envs = { X = "1"; };
programs.dev-sandbox.claude.envs = { Y = "2"; };
# Result: claude sandbox gets { X = "1"; Y = "2"; }
```

## Important Notes

- Only supports Linux (uses Linux namespaces)
- Requires Nix with flakes enabled
- Uses shell variable expansion - be careful with escaping in script template
- The `normalizeToSrcDst` function in `default.nix` handles both string and [src,dst] bind formats
- Module config is evaluated at build time, not runtime
- Packages can still be used directly via `.override` without the module
