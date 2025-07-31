{
  description = "Jonathan McGee's Personal Website";

  # Keep updated with HUGO_VERSION in .github/workflows/hugo.yml
  inputs.nixpkgs.url = "nixpkgs";

  outputs =
    { self, nixpkgs }@inputs:
    let
      # Import nixpkgs
      inherit (nixpkgs) lib;
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      # Configure source formatting
      formatter = pkgs.nixfmt-rfc-style;
    in
    with pkgs;
    {
      # Expose inputs for diagnostic use
      inherit inputs;

      # Expose formatter for diagnostic use
      formatter.${system} = formatter;

      # Helper macros
      apps.${system} = {
        # Run formatter over all Nix scripts
        format = {
          type = "app";
          meta.description = "Reformat source files";
          program = toString (
            writeShellScript "format" ''
              find . -name '*.nix' -print0 | xargs -0 ${lib.getExe formatter} --
            ''
          );
        };

        # Run hugo in server mode
        server = {
          type = "app";
          meta.description = "Start development server";
          program = toString (
            writeShellScript "server" ''
              exec ${lib.getExe hugo} server -DEF "$@"
            ''
          );
        };
      };

      # Validity Checks
      checks.${system} = {
        format = runCommandLocal "format-check" { } ''
          find ${self} -name '*.nix' -print0 | xargs -0 ${lib.getExe formatter} --verify --
          echo ${self} > $out
        '';
      };

      # Exposed Packages
      packages.${system} = rec {
        default = website;

        # Export hugo so it's easy to see which version nixpkgs is providing
        inherit hugo;

        # The actual website
        website = stdenvNoCC.mkDerivation {
          name = "website";
          src = self;

          # By default, source files will have a modified date of the epoch,
          # which is what Hugo will use when generating the indices.  While we
          # can't get access to the git history as a flake, we can at least
          # bring the source files to a more reasonable date.
          patchPhase = ''
            runHook prePatch
            find -print0 | xargs -0 touch -d @${toString self.lastModified} --
            runHook postPatch
          '';

          buildPhase = ''
            runHook preBuild
            ${lib.getExe hugo} build --minify
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            mv public $out
            runHook postInstall
          '';
        };

        # Compressed version of the website
        compressed = compressDrvWeb default { };
      };
    };
}
