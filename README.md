# dev-sandbox

**Developer sandbox** offers a lightweight isolated environment using [Bubblewrap](https://github.com/containers/bubblewrap).
It’s designed to keep your host tidy while you (or AI coding assistants) run tools inside a minimal, network-enabled container.

---

## Features

- 🛡️ Isolation via `bwrap`
- 📦 Packaged as a Nix flake
- 🔧 **Build-time** configuration:
  - `runCommand` — command to run inside the sandbox. Defaults to your current shell.
  - `binds` — list of directories to `--bind`. Can either be a string path where the same path is bound inside the sandbox or a two-element list [ src dst ].
  - `roBinds` — list of directories to `--ro-bind`
  - `envs` — key/value pairs injected as `--setenv KEY VALUE` on the `bwrap` cmdline.
  - `extraArgs` — extra `bwrap` flags/argv to append.
- Set DEV_SANDOX env var to allow you to detect when running inside a sendbox.
  - For example you can use this to change your prompt to indicate when you are in the sandbox 

## Requirements

- 🐧 Linux only (`x86_64-linux`, `aarch64-linux`). Works on NixOS. Should work on other Linux distros with Nix, but not tested.

---

## Install / Run

Run directly (flake-enabled Nix):
```bash
nix run github:champloo/dev-sandbox
````

---

## Usage

### Example: use from `devenv.nix`

```nix
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

Usage:

```bash
devenv shell
claude-code
```

---

## What gets mounted

* Read/write: your project directory (`$PWD`), per-invocation tmp (`/tmp`), and a synthetic home at `/home/$USER`.
* Read-only: `/nix`, `/bin/sh`, `/usr/bin/env`, and (on NixOS) `/run/current-system/sw` (only if present).
* PATH, HOME, USER, LOGNAME, TERM environment variables
* Certs env is set to the flake’s `cacert` bundle for reliable TLS.

