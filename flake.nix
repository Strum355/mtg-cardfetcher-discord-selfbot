{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    pyproject-nix = {
      url = "github:nix-community/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, pyproject-nix, uv2nix, pyproject-build-systems }: let
    forAllSystems = function:
      nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
        "aarch64-linux"
      ] (system: function nixpkgs.legacyPackages.${system});
    # wew what a load of fanfare
    uv-workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };
    overlay = uv-workspace.mkPyprojectOverlay {
      sourcePreference = "wheel";
    };
    pythonSet = pkgs: (pkgs.callPackage pyproject-nix.build.packages {
      python = pkgs.python312;
    }).overrideScope (
      nixpkgs.lib.composeManyExtensions [
        pyproject-build-systems.overlays.default
        overlay
        (_final: _prev: {
          discord-protos = _prev.discord-protos.overrideAttrs (oldAttrs: {
            buildInputs = (oldAttrs.buildInputs or []) ++ _final.resolveBuildSystem ({ setuptools = []; }); 
          });
        })
      ]
    );
  in {
    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        nativeBuildInputs = with pkgs; [
          uv
          python312
        ];
      };
    });

    packages = forAllSystems (pkgs: {
      default = (pkgs.callPackage pyproject-nix.build.util {}).mkApplication {
        venv = (pythonSet pkgs).mkVirtualEnv "sample-text" uv-workspace.deps.default;
        package = (pythonSet pkgs).mtg-cardfetcher-discord-selfbot;
      };
    });
  };
}
