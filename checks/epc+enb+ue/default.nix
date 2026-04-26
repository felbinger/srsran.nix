{
  self,
  pkgs,
  ...
}:
let
  k = "00112233445566778899aabbccddeeff";
  imsi = "001010123456780";
  opc = "63BFA50EE6523365FF14C1F45F88737D";
in
{
  name = "epc+enb+ue";

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
          hss.db_file = pkgs.writeText "user_db.csv" ''
            #
            # .csv to store UE's information in HSS
            # Kept in the following format: "Name,Auth,IMSI,Key,OP_Type,OP/OPc,AMF,SQN,QCI,IP_alloc"
            #
            # Name:     Human readable name to help distinguish UE's. Ignored by the HSS
            # Auth:     Authentication algorithm used by the UE. Valid algorithms are XOR
            #           (xor) and MILENAGE (mil)
            # IMSI:     UE's IMSI value
            # Key:      UE's key, where other keys are derived from. Stored in hexadecimal
            # OP_Type:  Operator's code type, either OP or OPc
            # OP/OPc:   Operator Code/Cyphered Operator Code, stored in hexadecimal
            # AMF:      Authentication management field, stored in hexadecimal
            # SQN:      UE's Sequence number for freshness of the authentication
            # QCI:      QoS Class Identifier for the UE's default bearer.
            # IP_alloc: IP allocation stratagy for the SPGW.
            #           With 'dynamic' the SPGW will automatically allocate IPs
            #           With a valid IPv4 (e.g. '172.16.0.2') the UE will have a statically assigned IP.
            #
            # Note: Lines starting by '#' are ignored and will be overwritten
            ue,mil,${imsi},${k},opc,${opc},8000,000000001234,7,dynamic
          '';
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
            device_args = "fail_on_disconnect=true,tx_port=tcp://0.0.0.0:2000,rx_port=tcp://192.0.2.12:2001,id=enb,base_srate=23.04e6";
          };
        };
      };
    };
    ue = {
      networking.interfaces.eth1.ipv4.addresses = [
        {
          address = "192.0.2.12";
          prefixLength = 24;
        }
      ];
      services.srsran.ue = {
        enable = true;
        settings = {
          rf = {
            # use ZeroMQ Virtual Radios
            device_name = "zmq";
            device_args = "tx_port=tcp://0.0.0.0:2001,rx_port=tcp://192.0.2.11:2000,id=ue,base_srate=23.04e6";
          };
          gw.ip_devname = "wwan0";
          usim = {
            inherit opc k imsi;
            imei = "353490069873319";
          };
        };
      };
    };
  };

  testScript =
    { nodes, ... }:
    let
      inherit (nodes.ue.services.srsran) ue;
    in
    /* python */ ''
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
        check_log("enb", "==== eNodeB started ===")

      with subtest("Check if eNodeB has connected to EPC"):
        check_log("epc", "Received S1 Setup Request")
        check_log("epc", "S1 Setup Request - eNB Name: srsenb01, eNB id: 0x0")
        check_log("epc", "S1 Setup Request - MCC:001, MNC:01")
        check_log("epc", "S1 Setup Request - TAC 1, B-PLMN 0xf110")
        check_log("epc", "S1 Setup Request - Paging DRX v128")
        check_log("epc", "Sending S1 Setup Response")

      with subtest("UE"):
        ue.wait_for_unit("network.target")
        ue.wait_for_unit("srsran-ue.service")
        check_log("ue", "Found Cell")
        check_log("epc", "Received Initial UE message -- Attach Request")
        check_log("epc", "Attach request -- IMSI: ${imsi}")
        check_log("epc", "SPGW: Allocate UE IP")
        check_log("ue", "Network attach successful")
        ue.succeed("ip addr show ${ue.settings.gw.ip_devname}")

        print(ue.wait_until_succeeds("ping -c 1 172.16.0.1")) # TODO doesn't work

      print(epc.succeed("journalctl -u srsran-epc -n 20"))
      print(enb.succeed("journalctl -u srsran-enb -n 20"))
      print(ue.succeed("journalctl -u srsran-ue -n 20"))
    '';
}
