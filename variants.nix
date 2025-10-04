{ pkgs }:

{
  # Default variant - generic sandbox with no preset config
  default = {
    runCommand = [ ];
    binds = [ ];
    roBinds = [ ];
    envs = { };
    extraArgs = [ ];
    extraRuntimeInputs = [ ];
  };

  # Claude Code variant - preconfigured for Claude Code usage
  claude = {
    runCommand = [
      "claude"
      "--dangerously-skip-permissions"
    ];
    binds = [
      "$HOME/.claude.json"
      "$HOME/.claude"
    ];
    roBinds = [ ];
    envs = { };
    extraArgs = [ ];
    extraRuntimeInputs = [ pkgs.claude-code ];
  };
}
