{
  self,
  pkgs,
  ...
}:
{
  name = "epc+enb";

  defaults = {
    # remove default ip addresses from interface
    virtualisation.interfaces.eth1 = {
      vlan = 1;
      assignIP = false;
    };

    networking.firewall.enable = false;

    imports = [ self.nixosModules.default ];
    services.srsran.enable = true;
  };

  nodes = {
    epc = {
      networking.interfaces.eth1.ipv4.addresses = [
        {
          address = "192.0.2.10";
          prefixLength = 24;
        }
      ];
      services.srsran.epc = {
        enable = true;
        settings = {
          hss.db_file = pkgs.writeText "user_db.csv" "";
          mme.mme_bind_addr = "192.0.2.10";
          spgw.gtpu_bind_addr = "192.0.2.10";
        };
      };
    };
    enb = {
      networking.interfaces.eth1.ipv4.addresses = [
        {
          address = "192.0.2.11";
          prefixLength = 24;
        }
      ];
      services.srsran.enb = {
        enable = true;
        settings = {
          enb = {
            # IP address of MME for S1 connection
            mme_addr = "192.0.2.10";
            # Local IP address to bind for GTP/S1AP connection
            gtp_bind_addr = "192.0.2.11";
            s1c_bind_addr = "192.0.2.11";
          };
          rf = {
            # use ZeroMQ Virtual Radios
            device_name = "zmq";
            device_args = "fail_on_disconnect=true,tx_port=tcp://*:2000,rx_port=tcp://192.168.2.11:2001,id=enb,base_srate=23.04e6";
          };
        };
      };
    };
  };

  testScript = /* python */ ''
    start_all()

    def check_log(component: str, line: str):
      """
      Utility function to check if the log of an srsran service contains a specified line.
      """
      globals()[component].wait_until_succeeds(f"journalctl --boot --unit srsran-{component}.service | grep '{line}'")

    with subtest("EPC"):
      epc.wait_for_unit("network.target")
      epc.wait_for_unit("srsran-epc.service")
      check_log("epc", "HSS Initialized")
      check_log("epc", "MME S11 Initialized")
      check_log("epc", "MME GTP-C Initialized")
      check_log("epc", "SPGW GTP-U Initialized")
      check_log("epc", "SPGW S11 Initialized")
      check_log("epc", "SP-GW Initialized")

    with subtest("eNodeB"):
      enb.wait_for_unit("network.target")
      enb.wait_for_unit("srsran-enb.service")
      enb.wait_for_open_port(2000) # port 2000 is defined in zmq device_args
      check_log("enb", "==== eNodeB started ===")

    with subtest("Check if eNodeB has connected to EPC"):
      check_log("epc", "Received S1 Setup Request")
      check_log("epc", "S1 Setup Request - eNB Name: srsenb01, eNB id: 0x0")
      check_log("epc", "S1 Setup Request - MCC:001, MNC:01")
      check_log("epc", "S1 Setup Request - TAC 1, B-PLMN 0xf110")
      check_log("epc", "S1 Setup Request - Paging DRX v128")
      check_log("epc", "Sending S1 Setup Response")

    print(enb.succeed("journalctl -u srsran-enb -n 20"))
    print(epc.succeed("journalctl -u srsran-epc -n 20"))
  '';
}
