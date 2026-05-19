{
  description = "A small JSON-RPC 2.0 server library for MoonBit";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    moonbit-overlay.url = "github:moonbit-community/moonbit-overlay";
    moon-registry = {
      url = "git+https://mooncakes.io/git/index";
      flake = false;
    };
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      perSystem = { system, ... }:
        let
          pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [ inputs.moonbit-overlay.overlays.default ];
          };
        in
        {
          devShells.default = pkgs.mkShell {
            packages = [
              pkgs.moonbit-bin.moonbit.latest
            ];
          };

          packages.default = pkgs.moonPlatform.buildMoonPackage {
            src = ./.;
            moonModJson = ./moon.mod.json;
            moonRegistryIndex = inputs.moon-registry;
          };
        };
    };
}
