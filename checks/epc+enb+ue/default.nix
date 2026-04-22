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

  node.pkgsReadOnly = false;

  nodes.machine = {
    imports = [
      self.nixosModules.default
    ];
    services.srsran = {
      enable = true;
      epc = {
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
          spgw = {
            # tun interface for the SGi connection
            sgi_if_addr = "172.16.0.1";
            sgi_if_name = "srs_spgw_sgi";
          };
        };
      };
      enb = {
        enable = true;
        settings = {
          enb = {
            # Local IP address to bind for GTP connection
            gtp_bind_addr = "127.0.1.1";
            # Local IP address to bind for S1AP connection
            s1c_bind_addr = "127.0.1.1";
          };
          rf = {
            # use ZeroMQ Virtual Radios
            device_name = "zmq";
            device_args = "fail_on_disconnect=true,tx_port=tcp://*:2000,rx_port=tcp://localhost:2001,id=enb,base_srate=23.04e6";
          };
        };
      };
      ue = {
        enable = true;
        settings = {
          rf = {
            # use ZeroMQ Virtual Radios
            device_name = "zmq";
            device_args = "tx_port=tcp://*:2001,rx_port=tcp://localhost:2000,id=ue,base_srate=23.04e6";
          };
          gw = {
            netns = "ue1";
            ip_devname = "tun_srsue";
          };
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
      inherit (nodes.machine.services.srsran) epc ue;
    in
    /* python */ ''
      machine.wait_for_unit("srsran-epc.service")

      machine.wait_until_succeeds("""
        ip -br a show ${epc.settings.spgw.sgi_if_name} | grep ${epc.settings.spgw.sgi_if_addr}
      """)

      machine.wait_for_unit("srsran-enb.service")

      machine.wait_for_open_port(2000) # port 2000 is defined in zmq device_args

      machine.wait_until_succeeds("journalctl --boot --unit srsran-enb.service | grep '==== eNodeB started ==='")

      machine.wait_for_unit("srsran-ue.service")

      machine.wait_for_open_port(2001) # port 2001 is defined in zmq device_args

      machine.wait_until_succeeds("journalctl --boot --unit srsran-ue.service | grep 'Found Cell'")
      machine.wait_until_succeeds("journalctl --boot --unit srsran-ue.service | grep 'Network attach successful'")

      machine.succeed("ip -n ue1 addr show ${ue.settings.gw.ip_devname}")

      print(machine.wait_until_succeeds("ip netns exec ue1 ping -c 1 172.16.0.1"))
    '';
}
