{
  self,
  inputs,
  system,
  interactive ? false,
}:
let
  inherit (inputs) nixpkgs;
  inherit (nixpkgs) lib;

  pkgs = import nixpkgs { inherit system; };

  tests = lib.pipe ./. [
    builtins.readDir
    (lib.filterAttrs (name: type: type == "directory" && !lib.hasPrefix "_" name))
    builtins.attrNames
  ];
in
builtins.listToAttrs (
  map (name: {
    inherit name;
    value =
      let
        test = import ./${name} {
          inherit
            self
            inputs
            lib
            pkgs
            ;
        };
        driver = pkgs.testers.runNixOSTest (
          lib.recursiveUpdate {
            defaults = {
              virtualisation.memorySize = 2048; # TODO check if still needed in interactive test with splitted setup

              imports = [
                (nixpkgs + "/nixos/modules/profiles/minimal.nix")
                (nixpkgs + "/nixos/modules/profiles/perlless.nix")
              ];

              nix.enable = lib.mkDefault false;
              services.lvm.enable = lib.mkDefault false;
              security.sudo.enable = lib.mkDefault false;

              environment.systemPackages = with pkgs; [
                srsran
                open5gs
                open5gs-webui
                ueransim
                zeromq

                tcpdump
              ];
            };
            interactive = {
              sshBackdoor.enable = true;
              nodes = lib.listToAttrs (
                map (name: {
                  inherit name;
                  value.virtualisation.graphics = true; # TODO set to false after vsock-mux work as before with vsock/3
                }) (builtins.attrNames test.nodes)
              );
            };
          } test
        );
      in
      if interactive then
        {
          type = "app";
          program = lib.getExe' driver.driverInteractive "nixos-test-driver";
          meta.description = test.name;
        }
      else
        driver;
  }) tests
)
