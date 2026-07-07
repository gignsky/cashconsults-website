{
  description = "CASH Consults — static 'Site in Progress' landing page";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # The whole deployable site. Building this derivation outputs the
        # landing page (index.html + CNAME, and whatever gets added under
        # site/ later) into a single $out tree that is ready to be served
        # or handed to GitHub Pages verbatim.
        cashconsults-site = pkgs.stdenvNoCC.mkDerivation {
          pname = "cashconsults-site";
          version = "0.1.0";

          src = ./site;

          nativeBuildInputs = [ pkgs.html-tidy ];

          # Lint the markup, but never let a cosmetic warning fail the deploy.
          buildPhase = ''
            runHook preBuild
            echo "Checking index.html markup..."
            tidy -q -e index.html || echo "tidy reported warnings (non-fatal)"
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            mkdir -p $out
            cp -r ./. $out/
            runHook postInstall
          '';

          meta = {
            description = "CASH Consults landing page";
            homepage = "https://cashrealestateconsulting.com";
          };
        };
      in
      {
        packages.default = cashconsults-site;
        packages.site = cashconsults-site;

        # `nix run` spins up a throwaway local preview of the built site.
        apps.default = {
          type = "app";
          program = "${pkgs.writeShellScript "serve-cashconsults" ''
            exec ${pkgs.python3}/bin/python3 -m http.server 8080 \
              --directory ${cashconsults-site}
          ''}";
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            nodejs_22
            python3
            git
            html-tidy
          ];
          shellHook = ''
            echo "  CASH Consults dev shell"
            echo "  live preview:   npx live-server site   (or: nix run)"
            echo "  build output:   nix build .#site"
          '';
        };
      });
}
