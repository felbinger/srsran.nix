{
  config,
  lib,
  ini,
  ...
}:
let
  cfg = config.services.srsran.epc;
  inherit (lib) mkOption mkEnableOption types;
in
{
  options = {
    enable = mkEnableOption "EPC";

    configFile = mkOption {
      type = types.path;
      visible = false;
      default = ini.generate "epc.conf" (lib.filterAttrsRecursive (_k: v: v != null) cfg.settings);
      description = ''
        srsEPC configuration file
      '';
    };

    settings = {
      mme = mkOption {
        type = types.nullOr (
          types.submodule {
            freeformType = ini.type;
            options = {
              mme_code = mkOption {
                type = with types; nullOr str;
                description = "8-bit MME code identifies the MME within a group";
              };

              mme_group = mkOption {
                type = with types; nullOr str;
                description = "16-bit MME group identifier";
              };

              tac = mkOption {
                type = with types; nullOr str;
                example = "0x0001";
                description = "16-bit Tracking Area Code";
              };

              mcc = mkOption {
                type = with types; nullOr str;
                description = "Mobile Country Code";
              };

              mnc = mkOption {
                type = with types; nullOr str;
                description = "Mobile Network Code";
              };

              mme_bind_addr = mkOption {
                type = with types; nullOr str;
                example = "127.0.1.100";
                description = "IP bind addr to listen for eNB S1-MME connnections.";
              };

              apn = mkOption {
                type = with types; nullOr str;
                example = "srsapn";
                description = "Access Point Name";
              };

              dns_addr = mkOption {
                type = with types; nullOr str;
                example = "8.8.8.8";
                description = "DNS server address for the UEs.";
              };

              encryption_algo = mkOption {
                type =
                  with types;
                  nullOr (enum [
                    "EEA0"
                    "EEA1"
                    "EEA2"
                    "EEA3"
                  ]);
                description = "Preferred encryption algorithm for NAS layer";
              };

              integrity_algo = mkOption {
                type =
                  with types;
                  nullOr (enum [
                    "EIA0" # rejected by most UEs
                    "EIA1"
                    "EIA2"
                    "EIA3"
                  ]);
                description = "Preferred integrity protection algorithm for NAS";
              };

              paging_timer = mkOption {
                type = with types; nullOr int;
                description = "Value of paging timer in seconds (T3413)";
              };

              request_imeisv = mkOption {
                type = with types; nullOr bool;
                description = "Request UE's IMEI-SV in security mode command";
              };

              lac = mkOption {
                type = with types; nullOr str;
                example = "0x0006";
                description = "16-bit Location Area Code";
              };
            };
          }
        );
        default = { }; # add default values to config
        description = ''
          MME configuration
        '';
      };
      hss = mkOption {
        type = types.nullOr (
          types.submodule {
            freeformType = ini.type;
            options = {
              db_file = mkOption {
                type = types.path;
                description = "Location of .csv file that stores UEs information";
              };
            };
          }
        );
        default = { }; # add default values to config
        description = ''
          HSS configuration
        '';
      };
      spgw = mkOption {
        type = types.nullOr (
          types.submodule {
            freeformType = ini.type;
            options = {
              gtpu_bind_addr = mkOption {
                type = with types; nullOr str;
                example = "127.0.1.100";
                description = "GTP-U bind address";
              };

              sgi_if_addr = mkOption {
                type = with types; nullOr str;
                example = "172.16.0.1";
                description = "SGi TUN interface IP address";
              };

              sgi_if_name = mkOption {
                type = with types; nullOr str;
                example = "srs_spgw_sgi";
                description = "SGi TUN interface name";
              };

              max_paging_queue = mkOption {
                type = with types; nullOr int;
                description = "Maximum packets in paging queue (per UE)";
              };
            };
          }
        );
        default = { }; # add default values to config
        description = ''
          SP-GW configuration
        '';
      };
      pcap = mkOption {
        type = types.nullOr (
          types.submodule {
            freeformType = ini.type;
            options = {
              enable = mkEnableOption "PCAP";
              filename = mkOption {
                type = with types; nullOr str;
                example = "/tmp/epc.pcap";
                description = "File name where to save the PCAP";
              };
            };
          }
        );
        default = { }; # add default values to config
        description = ''
          PCAP configuration

          Packets are captured to file in the compact format decoded by
          the Wireshark s1ap dissector and with DLT 150.
          To use the dissector, edit the preferences for DLT_USER to
          add an entry with DLT=150, Payload Protocol=s1ap.
        '';
      };
      log = mkOption {
        type =
          with types;
          submodule {
            freeformType = ini.type;
            options = {
              # TODO generate other options: nas, s1ap, mme_gtpc, spgw_gtpc, gtpu, spgw, hss, all
              all_level = mkOption {
                type =
                  with types;
                  nullOr (enum [
                    "debug"
                    "info" # default
                    "warning"
                    "error"
                    "none"
                  ]);
                description = "Log levels for all layers";
              };
              all_hex_limit = mkOption {
                type = with types; nullOr str;
                example = "32";
                description = "Limit for packet hex dumps for all layers";
              };
              filename = mkOption {
                type = with types; nullOr str;
                example = "/tmp/epc.log";
                description = "File path to use for log output. Can be set to stdout to print logs to standard output.";
              };
            };
          };
        default = { }; # add default values to config
        description = ''
          Log configuration

          Log levels can be set for individual layers. "all_level" sets log
          level for all layers unless otherwise configured.
          Format: e.g. s1ap_level = info

          In the same way, packet hex dumps can be limited for each level.
          "all_hex_limit" sets the hex limit for all layers unless otherwise
          configured.
          Format: e.g. s1ap_hex_limit = 32
        '';
      };
    };
  };
}
