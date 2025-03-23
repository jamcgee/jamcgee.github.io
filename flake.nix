{
  description = "Jonathan McGee's Personal Website";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs =
    {
      self,
      flake-utils,
      nixpkgs,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        inherit (pkgs)
          lib
          runCommand
          stdenv
          writeShellScriptBin
          ;
        formatter = pkgs.nixfmt-rfc-style;
      in
      {
        inherit formatter;

        apps.format = {
          type = "app";
          program = lib.getExe (
            writeShellScriptBin "etherealwake-format" ''
              find . -name '*.nix' -print0 | xargs -0 ${lib.getExe formatter}
            ''
          );
          meta.description = "Reformat source files";
        };

        apps.server = {
          type = "app";
          program = lib.getExe (
            writeShellScriptBin "etherealwake-server" ''
              exec ${lib.getExe pkgs.hugo} server -DEF "$@"
            ''
          );
          meta.description = "Start development server";
        };

        checks.format-check = runCommand "format-check" { } ''
          find ${self} -name '*.nix' -print0 | xargs -0 ${lib.getExe formatter} --verify
          touch $out
        '';

        packages.default = stdenv.mkDerivation {
          name = "etherealwake-website";
          src = self;
          buildPhase = ''
            ${lib.getExe pkgs.hugo} build --destination $out --minify
          '';
        };
      }
    );
}
