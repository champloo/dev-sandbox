{
  description = "Developer sandbox offers lightweight environment isolation for use with AI code assistants";
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        # ---- install-time options (override via .override { ... })
        extraEnv = { }; # e.g. { DEV_SANDBOX_CMD = "claude --dangerously-skip-permissions"; }

        script = ''
          BWRAP="${pkgs.bubblewrap}/bin/bwrap"
          CACERT="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"

          # inject extra env baked at build time
          ${pkgs.lib.concatStringsSep "\n" (
            pkgs.lib.mapAttrsToList (n: v: "export " + n + "=" + pkgs.lib.escapeShellArg v) extraEnv
          )}

          USER="$(whoami)"
          SANDBOX_HOME="/tmp/dev-sandbox-home-$$"
          SANDBOX_TMP="/tmp/dev-sandbox-tmp-$$"

          # remove sandbox files on exit
          trap 'rm -rf "$SANDBOX_HOME" "$SANDBOX_TMP"' EXIT

          mkdir -p "$SANDBOX_TMP" "$SANDBOX_HOME" "$SANDBOX_HOME/.cache" "$SANDBOX_HOME/.config"

          # Build bwrap argument list
          args=(
            --unshare-all                         # isolate every namespace except network
            --unshare-user                        # isolate user namespace
            --unshare-pid                         # isolate pid namespace
            --unshare-uts                         # isolate uts namespace
            --unshare-ipc                         # isolate ipc namespace
            --share-net                           # keep Internet access for API calls
            --die-with-parent                     # auto-kill if parent shell exits
            --proc /proc                          # minimal /proc
            --dev /dev                            # minimal /dev
            --tmpfs /usr
            --dir /usr/bin
            --setenv "SHELL" "$(readlink "$(command -v "$SHELL")")"
            --setenv "DEV_SANDBOX" "enabled"      # allows us to know when we are inside the sandbox in case other scripts need to be aware of it
            --setenv "SSL_CERT_FILE" "$CACERT"
            --setenv "NIX_SSL_CERT_FILE" "$CACERT"
            --setenv "CURL_CA_BUNDLE" "$CACERT"
            --setenv "REQUESTS_CA_BUNDLE" "$CACERT"
            --setenv "PATH" "$PATH"
            --setenv "HOME" "$HOME"
            --setenv "USER" "$USER"
            --setenv "LOGNAME" "$LOGNAME"
            --setenv "TERM" "$TERM"
            --bind "$SANDBOX_HOME" "/home/$USER"
            --bind "$SANDBOX_TMP" /tmp
            --bind "$PWD" "$PWD"
            --bind /etc/resolv.conf /etc/resolv.conf
            --bind /etc/nix /etc/nix
            --bind /etc/static/nix /etc/static/nix
            --ro-bind /run/current-system/sw /run/current-system/sw
            --ro-bind /bin/sh /bin/sh
            --ro-bind /usr/bin/env /usr/bin/env
            --ro-bind /nix /nix
          )

          : "''${DEV_SANDBOX_EXTRA_ARGS:=}"
          # Allow users to pass extra bwrap args via a simple string
          if [[ -n "''${DEV_SANDBOX_EXTRA_ARGS:-}" ]]; then
            # Split on IFS into an array (no arrays in env)
            read -r -a _extra <<< "$DEV_SANDBOX_EXTRA_ARGS"
            args+=( "''${_extra[@]}" )
          fi

          : "''${DEV_SANDBOX_CMD:=}"
          if [[ -n "''${DEV_SANDBOX_CMD:-}" ]]; then
            echo "$BWRAP" "''${args[@]}" "$DEV_SANDBOX_CMD"
            "$BWRAP" "''${args[@]}" "$DEV_SANDBOX_CMD"
          else
            echo "$BWRAP" "''${args[@]}" "$(readlink "$(command -v "$SHELL")")"
            "$BWRAP" "''${args[@]}" "$(readlink "$(command -v "$SHELL")")"
          fi
        '';

        app = pkgs.writeShellApplication {
          name = "dev-sandbox";
          runtimeInputs = with pkgs; [
            bubblewrap
            bash
            cacert
          ];
          text = script;
        };
      in
      {
        packages.dev-sandbox = app;
        packages.default = app;

        apps.default = {
          type = "app";
          program = "${app}/bin/dev-sandbox";
        };
      }
    );
}
