{ pkgs }:

{
  # Default variant - generic sandbox with no preset config
  default = {
    name = "dev-sandbox";
    runCommand = [ ];
    binds = [ ];
    roBinds = [ ];
    symlinks = { };
    envs = { };
    extraArgs = [ ];
    extraRuntimeInputs = [ ];
  };

  # Claude Code variant - preconfigured for Claude Code usage
  claude = {
    name = "dev-sandbox-claude";
    runCommand = [
      "claude"
      "--dangerously-skip-permissions"
    ];
    binds = [
      "$HOME/.claude.json"
      "$HOME/.claude"
    ];
    roBinds = [ ];
    symlinks = { };
    envs = { };
    extraArgs = [ ];
    extraRuntimeInputs = [ ];
  };

  # Codex variant - preconfigured for Codex usage
  codex = {
    name = "dev-sandbox-codex";
    runCommand = [
      "codex"
      "-a"
      "never"
      "-s"
      "danger-full-access"
    ];
    binds = [
      "$HOME/.codex"
    ];
    roBinds = [ ];
    symlinks = { };
    envs = { };
    extraArgs = [ ];
    extraRuntimeInputs = [ ];
  };
}
