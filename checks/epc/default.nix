{
  self,
  pkgs,
  ...
}:
{
  name = "epc";

  nodes.machine = {
    imports = [
      self.nixosModules.default
    ];
    services.srsran = {
      enable = true;
      epc = {
        enable = true;
        settings = {
          hss.db_file = pkgs.writeText "user_db.csv" "";
          spgw = {
            # tun interface for the SGi connection
            # these are the default values of srsran, they had to be specified to use the nix options values within the testScript
            sgi_if_addr = "172.16.0.1";
            sgi_if_name = "srs_spgw_sgi";
          };
        };
      };
    };
  };

  testScript =
    { nodes, ... }:
    let
      inherit (nodes.machine.services.srsran.epc) settings;
    in
    /* python */ ''
      machine.wait_for_unit("srsran-epc.service")

      machine.wait_until_succeeds("""
        ip -br a show ${settings.spgw.sgi_if_name} | grep ${settings.spgw.sgi_if_addr}
      """)
    '';
}
