{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    search = {
      url = "github:NuschtOS/search";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      search,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;
      defaultSystems = [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      eachDefaultSystem = lib.genAttrs defaultSystems;
    in
    {
      nixosModules = rec {
        srsran = ./modules;
        default = srsran;
      };

      packages = eachDefaultSystem (
        system:
        let
          pkgs = (import nixpkgs) { inherit system; };
        in
        {
          default = search.packages.${system}.mkSearch {
            modules = [
              self.nixosModules.default
              {
                _module.args = {
                  inherit pkgs;
                };
              }
            ];
            title = "Module Search of felbinger/srsRAN.nix";
            baseHref = "/srsran.nix/";
            urlPrefix = "https://github.com/felbinger/srsran.nix/blob/main/";
          };
        }
      );

      formatter = eachDefaultSystem (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
      checks = eachDefaultSystem (system: import ./checks { inherit self inputs system; });
      apps = eachDefaultSystem (
        system:
        import ./checks {
          inherit self inputs system;
          interactive = true;
        }
      );
    };
}
