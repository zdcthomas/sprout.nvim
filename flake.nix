{
  description = "sprout.nvim: ascii art that grows with the hour of the day";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forEachSystem = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      pythonFor = pkgs: pkgs.python3.withPackages (ps: [ ps.pillow ]);
    in
    {
      packages = forEachSystem (pkgs: rec {
        # Renders assets/bonsai.gif from the art in lua/sprout/sets/.
        # Run from the repo root, or point SPROUT_ROOT at the repo.
        make-gif = pkgs.writeShellApplication {
          name = "make-gif";
          runtimeInputs = [ (pythonFor pkgs) ];
          text = ''
            export SPROUT_ROOT="''${SPROUT_ROOT:-$PWD}"
            exec python3 ${./scripts/make_gif.py}
          '';
        };
        default = make-gif;
      });

      devShells = forEachSystem (pkgs: {
        default = pkgs.mkShell {
          packages = [ (pythonFor pkgs) ];
        };
      });
    };
}
