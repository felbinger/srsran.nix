{
  config,
  lib,
  ini,
  ...
}:
let
  cfg = config.services.srsran.mbms;
  inherit (lib) mkOption mkEnableOption types;
in
{
  options = {
    enable = mkEnableOption "MBMS";

    configFile = mkOption {
      type = types.path;
      visible = false;
      default = ini.generate "mbms.conf" (lib.filterAttrsRecursive (_k: v: v != null) cfg.settings);
      description = ''
        srsMBMS configuration file
      '';
    };

    settings = {
      mbms_gw = mkOption {
        type = types.nullOr (
          types.submodule {
            freeformType = ini.type;
            options = {
              name = mkOption {
                type = with types; nullOr str;
                example = "srsmbmsgw01";
                description = "MBMS-GW name";
              };
              sgi_mb_if_name = mkOption {
                type = with types; nullOr str;
                example = "sgi_mb";
                description = "SGi-mb TUN interface name";
              };
              sgi_mb_if_addr = mkOption {
                type = with types; nullOr str;
                example = "172.16.0.254";
                description = "SGi-mb interface IP address";
              };
              sgi_mb_if_mask = mkOption {
                type = with types; nullOr str;
                example = "255.255.255.255";
                description = "SGi-mb interface IP mask";
              };
              m1u_multi_addr = mkOption {
                type = with types; nullOr str;
                example = "239.255.0.1";
                description = "Multicast group for eNBs";
              };
              m1u_multi_if = mkOption {
                type = with types; nullOr str;
                example = "127.0.1.200";
                description = "IP of local interface for multicast traffic";
              };
              m1u_multi_ttl = mkOption {
                type = with types; nullOr ints.u8;
                example = 1;
                description = "TTL for M1-U multicast traffic";
              };
            };
          }
        );
        default = { }; # add default values to config
        description = ''
          MBMS-GW configuration
        '';
      };
      log = mkOption {
        type =
          with types;
          submodule {
            freeformType = ini.type;
            options = {
              all_level = mkOption {
                type =
                  with types;
                  nullOr (enum [
                    "debug"
                    "info"
                    "warning"
                    "error"
                    "none"
                  ]);
                example = "debug";
                description = "Log levels for all layers";
              };
              mbms_gw_hex_limit = mkOption {
                type = with types; nullOr str;
                example = "32";
                description = "Limit for packet hex dumps for all layers";
              };
              mbms_gw_level = mkOption {
                type =
                  with types;
                  nullOr (enum [
                    "debug"
                    "info"
                    "warning"
                    "error"
                    "none"
                  ]);
                example = "debug";
                description = "Log levels for mbms_gw layer";
              };
              all_hex_limit = mkOption {
                type = with types; nullOr str;
                example = "32";
                description = "Limit for packet hex dumps for mbms_gw layer";
              };
              filename = mkOption {
                type = with types; nullOr str;
                example = "/tmp/mbms.log";
                description = "File path to use for log output. Can be set to stdout to print logs to standard output.";
              };
            };
          };
        default = { }; # add default values to config
        description = ''
          Log configuration

          Log levels can be set for individual layers. "all_level" sets log
          level for all layers unless otherwise configured.

          In the same way, packet hex dumps can be limited for each level.
          "all_hex_limit" sets the hex limit for all layers unless otherwise
          configured.
        '';
      };
    };
  };
}
