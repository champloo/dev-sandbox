# dev-sandbox

**Developer sandbox** offers a lightweight isolated environment using [Bubblewrap](https://github.com/containers/bubblewrap).
It’s designed to keep your host data isolated while you (or AI coding assistants) run tools inside a minimal, network-enabled container.

## Features

- 🛡️ Isolation via `bwrap`
- 📦 Packaged as a Nix flake
- 🔧 Build-time configuration:
  - `runCommand` — command to run inside the sandbox. Defaults to your current shell.
  - `binds` — list of paths to expose. Equivalent to  `bwrap --bind`. Can either be a string path where the same path is bound inside the sandbox or a two-element list [ src dst ].
  - `roBinds` — list of paths to expose as read only. Equivalent to  `bwrap --ro-bind`.
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
}
```

Then in your `configuration.nix`:

```nix
{ inputs, pkgs, ... }:

{
  imports = [ inputs.dev-sandbox.nixosModules.default ];

  programs.dev-sandbox = {
    # Common settings applied to ALL sandbox instances
    binds = [
      "$HOME/.config/common"
      "$HOME/.local/share"
    ];
    roBinds = [
      "$HOME/.bashrc"
      "$HOME/.zshrc"
    ];
    envs = {
      EDITOR = "vim";
    };

    # Default sandbox instance
    default = {
      enable = true;
      # Inherits common settings above
    };

    # Claude Code sandbox instance (has smart defaults!)
    claude = {
      enable = true;
      # Defaults are pre-configured:
      #   runCommand = [ "claude" "--dangerously-skip-permissions" ]
      #   binds = [ "$HOME/.claude.json" "$HOME/.claude" ]
      #   extraRuntimeInputs = [ pkgs.claude-code ]
      #
      # You can override or extend any defaults:
      # binds = [ "$HOME/.custom-claude-config" ];
    };
  };
}
```

This creates two executables:
- `dev-sandbox` - plain shell sandbox
- `dev-sandbox-claude` - Claude Code sandbox

Both will be available in your system PATH.

### From [devenv](https://devenv.sh/)

```yaml
# devenv.yaml

inputs:
  dev-sandbox:
    url: github:champloo/dev-sandbox
```

```nix
# devenv.nix

{ pkgs, inputs, ... }:

let
  dev-sandbox = inputs.dev-sandbox.packages.${pkgs.system}.dev-sandbox;

  claudeCode = dev-sandbox.override {
    runCommand = [ "claude" "--dangerously-skip-permissions" ];
    envs = {
      EDITOR = "nano";
    };
    binds = [
      "$HOME/.claude.json"
      "$HOME/.claude"
      ["$HOME/.histfile" "$HOME/my_history"]
    ];
    roBinds = [
      "$HOME/.zshrc"
    ];
  };
in {
  scripts.claude-code.exec = ''${claudeCode}/bin/dev-sandbox'';
}
```

From your shell you can then...

```bash
devenv shell
claude-code
```
### Running directly from shell

If you just want to try it out with the default config you can...

```bash
nix run github:champloo/dev-sandbox
````
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
