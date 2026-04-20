{
  config,
  lib,
  ini,
  ...
}:
let
  cfg = config.services.srsran.enb;
  inherit (lib) mkOption mkEnableOption types;
in
{
  options = {
    enable = mkEnableOption "ENB";

    configFile = mkOption {
      type = types.path;
      visible = false;
      default = ini.generate "enb.conf" (lib.filterAttrsRecursive (_k: v: v != null) cfg.settings);
      description = ''
        srsENB configuration file
      '';
    };

    settings = {
      pcap = mkOption {
        type = types.nullOr (
          types.submodule {
            freeformType = ini.type;
            options = {
              #enable = mkEnableOption "PCAP";
              #bogus = mkOption {
              #  default = "default";
              #  type = types.str;
              #  description = "";
              #};
            };
          }
        );
        default = { }; # add default values to config
        description = "";
      };
    };
  };
}
