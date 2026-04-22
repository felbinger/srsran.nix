{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.srsran;
  ini = pkgs.formats.ini { };
  inherit (lib)
    mkEnableOption
    mkPackageOption
    mkOption
    types
    mkIf
    ;
in
{
  meta.maintainers = with lib.maintainers; [ felbinger ];

  options.services.srsran = {
    enable = mkEnableOption "srsRAN";

    package = mkPackageOption pkgs "srsran" { };

    epc = mkOption {
      type = types.submodule (
        import ./epc.nix {
          inherit
            config
            lib
            ini
            ;
        }
      );
      default = { };
      description = "EPC settings";
    };

    enb = mkOption {
      type = types.submodule (
        import ./enb.nix {
          inherit
            config
            pkgs
            lib
            ini
            ;
        }
      );
      default = { };
      description = "ENB settings";
    };

    ue = mkOption {
      type = types.submodule (
        import ./ue.nix {
          inherit
            config
            pkgs
            lib
            ini
            ;
        }
      );
      default = { };
      description = "UE settings";
    };

    mbms = mkOption {
      type = types.submodule (
        import ./mbms.nix {
          inherit
            config
            pkgs
            lib
            ini
            ;
        }
      );
      default = { };
      description = "MBMS settings";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      (mkIf (cfg.epc.enable && cfg.enb.enable) {
        assertion = cfg.epc.settings.mme.mcc == cfg.enb.settings.enb.mcc;
        message = "EPC MCC must be equal to ENB MCC";
      })
      (mkIf ((cfg.epc != null) && (cfg.enb != null)) {
        assertion = cfg.epc.settings.mme.mnc == cfg.enb.settings.enb.mnc;
        message = "EPC MNC must be equal to ENB MNC";
      })
    ];

    systemd.services = {
      srsran-epc = mkIf cfg.epc.enable {
        description = "srsRAN EPC";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = "${lib.getExe' cfg.package "srsepc"} ${cfg.epc.configFile}";
          Restart = "on-failure";

          # TODO hardening
        };
      };

      srsran-enb = mkIf cfg.enb.enable {
        description = "srsRAN ENB";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = "${lib.getExe' cfg.package "srsenb"} ${cfg.enb.configFile}";
          Restart = "on-failure";

          # TODO hardening
        };
      };

      srsran-ue = mkIf cfg.ue.enable {
        description = "srsRAN UE";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = "${lib.getExe' cfg.package "srsue"} ${cfg.ue.configFile}";
          Restart = "on-failure";

          # TODO hardening
        };
        preStart = "${lib.getExe' pkgs.iproute2 "ip"} netns add ue1"; # TODO testing purpose only, out of scope of this module
        postStop = "${lib.getExe' pkgs.iproute2 "ip"} netns del ue1"; # TODO testing purpose only, out of scope of this module
      };
    };
  };
}
