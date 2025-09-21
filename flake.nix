{
  description = "Developer sandbox offers a lightweight isolated environment. Helpful for AI assisted coding";
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
        lib = pkgs.lib;

        # Normalize an entry to { src, dst }
        normalizeToSrcDst =
          p:
          if builtins.isList p && builtins.length p == 2 then
            {
              src = builtins.elemAt p 0;
              dst = builtins.elemAt p 1;
            }
          else
            {
              src = p;
              dst = p;
            };

        mkDevSandbox = lib.makeOverridable (
          {
            runCommand ? [ ],
            binds ? [ ],
            roBinds ? [ ],
            extraArgs ? [ ],
            envs ? { },
          }:
          let
            script = ''
              BWRAP="${pkgs.bubblewrap}/bin/bwrap"
              CACERT="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"

              SHELL_RESOLVED="$(readlink "$(command -v "$SHELL")")"

              USER="$(whoami)"
              SANDBOX_HOME="/tmp/dev-sandbox-home-$$"
              SANDBOX_TMP="/tmp/dev-sandbox-tmp-$$"

              # remove sandbox files on exit
              trap 'rm -rf "$SANDBOX_HOME" "$SANDBOX_TMP"' EXIT

              mkdir -p "$SANDBOX_TMP" "$SANDBOX_HOME" "$SANDBOX_HOME/.cache" "$SANDBOX_HOME/.config"

              maybe_bind() {
                if [[ -e "$1" ]]; then
                  args+=( --bind "$1" "''${2:-$1}" )
                else
                  echo "Warning: Will not bind $1 as it does not exist."
                fi
                return 0
              }

              maybe_ro_bind() {
                if [[ -e "$1" ]]; then
                  args+=( --ro-bind "$1" "''${2:-$1}" )
                else
                  echo "Warning: Will not ro-bind $1 as it does not exist."
                fi
                return 0
              }

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
                --setenv "SHELL" "$SHELL_RESOLVED"
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
                --ro-bind /bin/sh /bin/sh
                --ro-bind /usr/bin/env /usr/bin/env
                --ro-bind /nix /nix
              )

              # These binds may not be available on non nixos systems
              maybe_bind /etc/nix
              maybe_bind /etc/static/nix
              maybe_ro_bind /run/current-system/sw

              ${pkgs.lib.concatStringsSep "\n" (
                map (
                  p:
                  let
                    b = normalizeToSrcDst p;
                  in
                  ''maybe_ro_bind "${b.src}" "${b.dst}"''
                ) roBinds
              )}

              ${pkgs.lib.concatStringsSep "\n" (
                map (
                  p:
                  let
                    b = normalizeToSrcDst p;
                  in
                  ''maybe_bind "${b.src}" "${b.dst}"''
                ) binds
              )}

              ${pkgs.lib.concatStringsSep "\n" (map (a: ''args+=( ${a} )'') extraArgs)}

              ${pkgs.lib.concatStringsSep "\n" (
                pkgs.lib.mapAttrsToList (n: v: ''args+=( --setenv "${n}" "${v}" )'') envs
              )}

              RUN_CMD=(${pkgs.lib.concatStringsSep " " (map pkgs.lib.escapeShellArg runCommand)})
              if [[ ''${#RUN_CMD[@]} -eq 0 ]]; then
                RUN_CMD=("$SHELL_RESOLVED")
              fi

              echo "$BWRAP" "''${args[@]}" "''${RUN_CMD[@]}"
              "$BWRAP" "''${args[@]}" "''${RUN_CMD[@]}"
            '';
          in
          pkgs.writeShellApplication {
            name = "dev-sandbox";
            runtimeInputs = with pkgs; [
              bubblewrap
              bash
              cacert
            ];
            text = script;
            meta = {
              description = "Developer sandbox offers a lightweight isolated environment. Helpful for AI assisted coding";
              mainProgram = "dev-sandbox";
              platforms = pkgs.lib.platforms.linux;
              license = pkgs.lib.licenses.mit;
            };
          }
        );
        devSandbox = mkDevSandbox { };
      in
      {
        packages.dev-sandbox = devSandbox;
        packages.default = devSandbox;

        apps.default = {
          type = "app";
          program = "${devSandbox}/bin/dev-sandbox";
        };
      }
    );
}
