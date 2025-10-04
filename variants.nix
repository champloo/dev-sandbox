{ pkgs }:

{
  # Default variant - generic sandbox with no preset config
  default = {
    name = "dev-sandbox";
    runCommand = [ ];
    binds = [ ];
    roBinds = [ ];
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
    envs = { };
    extraArgs = [ ];
    extraRuntimeInputs = [ pkgs.claude-code ];
  };
}
