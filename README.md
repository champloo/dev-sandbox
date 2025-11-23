# dev-sandbox

**Developer sandbox** offers a lightweight isolated environment using [Bubblewrap](https://github.com/containers/bubblewrap).
It’s designed to keep your host data isolated while you (or AI coding assistants) run tools inside a minimal, network-enabled container.

## Features

- 🛡️ Isolation via `bwrap`
- 📦 Packaged as a Nix flake
- 🛒 Provides convenient shell, claude, and codex sandboxes
- 🔧 Build-time configuration:
  - `runCommand` — command to run inside the sandbox. Defaults to your current shell.
  - `binds` — list of paths to expose. Equivalent to  `bwrap --bind`. Can either be a string path where the same path is bound inside the sandbox or a two-element list [ src dst ].
  - `roBinds` — list of paths to expose as read only. Equivalent to  `bwrap --ro-bind`.
  - `symlinks` — attrset of symlinks to create inside the sandbox. Keys are link paths, values are targets. Equivalent to `bwrap --symlink TARGET LINK`.
  - `envs` — key/value pairs. Equivalent to `brwap --setenv KEY VALUE`.
  - `extraArgs` — extra `bwrap` flags to append.
- Sets DEV_SANDOX env var to allow you to detect when sandbox is active.
  - For example, you can use this to change your prompt to indicate when you are in the sandbox.

## Requirements

- [Nix](https://nix.dev/) package manager with [flakes](https://nix.dev/concepts/flakes.html#flakes) enabled.
- 🐧 Linux (`x86_64-linux`, `aarch64-linux`). Tested on NixOS. Should work on other Linux distros, but not tested.

## Usage

### As a NixOS Module

Add to your `flake.nix` inputs:

```nix
{
  inputs.dev-sandbox.url = "github:champloo/dev-sandbox";
  inputs.dev-sandbox.inputs.nixpkgs.follows = "nixpkgs";

  # And add to your modules

      modules = [ inputs.dev-sandbox.nixosModules.default ];
}
```

Then in your `configuration.nix`:

```nix
{ inputs, pkgs, ... }:

{
  programs.dev-sandbox = {
    # Common settings applied to all sandbox variants
    binds = [
      "$HOME/.cache/uv"
    ];
    roBinds = [
      "$HOME/.zshrc"
    ];
    symlinks = {
      # Example: ensure /usr/bin/python exists inside sandbox
      "/usr/bin/python" = "/nix/store/.../bin/python";
    };
    envs = {
      EDITOR = "nano";
    };

    # Enable shell sandbox which can be run with dev-sandbox
    default = {
      enable = true;
      # Inherits common settings above
    };

    # Enable Claude Code sandbox which can be run with dev-sandbox-claude
    claude = {
      enable = true;
      # Defaults are pre-configured:
      #   name = "dev-sandbox-claude"
      #   runCommand = [ "claude" "--dangerously-skip-permissions" ]
      #   binds = [ "$HOME/.claude.json" "$HOME/.claude" ]
      #   extraRuntimeInputs = [ pkgs.claude-code ]
      #
      # You can override or extend any defaults:
      # name = "claudebox"; # also changes name of the binary
      # binds = [ "$HOME/.custom-claude-config" ];
    };

    # Enable Codex sandbox which can be run with dev-sandbox-codex
    codex = {
      enable = true;
      # Defaults are pre-configured:
      #   name = "dev-sandbox-codex"
      #   runCommand = [ "codex" "-a" "never" "-s" "danger-full-access" ]
      #   binds = [ "$HOME/.codex" ]
      #
      # You can override or extend any defaults:
      # binds = [ "$HOME/.custom-codex-config" ];
    };
  };
}
```

This creates three executables:
- `dev-sandbox` - plain shell sandbox
- `dev-sandbox-claude` - Claude Code sandbox
- `dev-sandbox-codex` - Codex sandbox

All will be available in your system PATH.

### Running directly from shell

If you just want to try it out with the default config you can...

```bash
nix run github:champloo/dev-sandbox
```

Run the Claude Code variant:

```bash
NIXPKGS_ALLOW_UNFREE=1 nix run github:champloo/dev-sandbox#claude --impure
```

Run the Codex variant:

```bash
nix run github:champloo/dev-sandbox#codex
```
## What gets mounted by default

* Read/write: the current directory, synthetic home and tmp at `/tmp/dev-sandbox-home-$$` and `/tmp/dev-sandbox-tmp-$$`, `/etc/resolv.conf`, `/etc/nix`, `/etc/static/nix`.
* Read-only: `/nix`, `/bin/sh`, `/usr/bin/env`, and on NixOS systems `/run/current-system/sw`.
* `PATH`, `HOME`, `USER`, `LOGNAME`, `TERM` environment variables.
  * `cacert` is installed as a dependency and the relevant cert env vars are pointed to the installed `ca-bundle.crt` file.

## Similar projects

* <https://github.com/numtide/nix-ai-tools/blob/main/packages/claudebox/claudebox.sh>
* <https://github.com/longregen/claude-sandbox>
* <https://github.com/Naxdy/nix-bwrapper>
* <https://github.com/fgaz/nix-bubblewrap>
