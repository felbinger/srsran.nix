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
        settings.hss.db_file = pkgs.writeText "user_db.csv" ''
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
          ue2,mil,${imsi},${k},opc,${opc},8000,000000001234,7,dynamic
        '';
      };
      enb = {
        enable = true;
        settings = {
          rf = {
            device_name = "zmq";
            device_args = "fail_on_disconnect=true,tx_port=tcp://*:2000,rx_port=tcp://localhost:2001,id=enb,base_srate=23.04e6";
          };
        };
      };
      ue = {
        enable = true;
        settings = {
          rf = {
            device_name = "zmq";
            device_args = "tx_port=tcp://*:2001,rx_port=tcp://localhost:2000,id=ue,base_srate=23.04e6";
          };
          gw.netns = "ue1";
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
      inherit (nodes.machine.services.srsran) epc;
    in
    /* python */ ''
      # start_all()

      machine.wait_for_unit("srsran-epc.service")

      machine.wait_until_succeeds("""
        ip -br a show ${epc.settings.spgw.sgi_if_name} | grep ${epc.settings.spgw.sgi_if_addr}
      """)

      machine.wait_for_unit("srsran-enb.service")

      machine.wait_for_unit("srsran-ue.service")

      machine.sleep(15)

      print(machine.succeed("ip a"))
      machine.succeed("ip netns add ue1")
      print(machine.succeed("ip -n ue1 a"))
      print(machine.wait_until_succeeds("ip netns exec ue1 ping -c 1 172.16.0.1"))
    '';
}
