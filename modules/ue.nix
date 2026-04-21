{
  config,
  lib,
  ini,
  ...
}:
let
  cfg = config.services.srsran.ue;
  inherit (lib) mkOption mkEnableOption types;
in
{
  options = {
    enable = mkEnableOption "UE";

    configFile = mkOption {
      type = types.path;
      visible = false;
      default = ini.generate "ue.conf" (lib.filterAttrsRecursive (_k: v: v != null) cfg.settings);
      description = ''
        srsUE configuration file
      '';
    };

    settings = {
      rf = mkOption {
        type = types.nullOr (
          types.submodule {
            freeformType = ini.type;
            options = {
              freq_offset = mkOption {
                type = with types; nullOr str;
                description = "Uplink and Downlink optional frequency offset (in Hz)";
              };
              tx_gain = mkOption {
                type = types.str;
                default = "80";
                description = "Transmit gain (dB)";
              };
              rx_gain = mkOption {
                type = types.str;
                default = "40";
                description = "Optional receive gain (dB). If disabled, AGC if enabled";
              };
              srate = mkOption {
                type = types.str;
                default = "11.52e6";
                description = "Optional fixed sampling rate (Hz), corresponding to cell bandwidth. Must be set for 5G-SA";
              };
              nof_antennas = mkOption {
                type = with types; nullOr str;
                description = "Number of antennas per carrier (all carriers have the same number of antennas)";
              };
              device_name = mkOption {
                type =
                  with types;
                  nullOr (enum [
                    "auto" # default, uses first found
                    "UHD"
                    "bladeRF"
                    "zmq"
                  ]);
                description = "Device driver family";
              };
              device_args = mkOption {
                type = with types; nullOr str;
                # Example for ZMQ-based operation with TCP transport for I/Q samples
                example = "tx_port=tcp://*:2001,rx_port=tcp://localhost:2000,id=ue,base_srate=23.04e6";
                description = ''
                  Arguments for the device driver. Options are "auto" or any string.

                  Default for UHD: "recv_frame_size=9232,send_frame_size=9232"
                  Default for bladeRF: ""

                  For best performance in 2x2 MIMO and >= 15 MHz use the following device_args settings:
                      USRP B210: num_recv_frames=64,num_send_frames=64

                  For best performance when BW<5 MHz (25 PRB), use the following device_args settings:
                      USRP B210: send_frame_size=512,recv_frame_size=512
                '';
              };
              #device_args_2 = mkOption {
              #  type = with types; nullOr str;
              #  default = "auto";
              #  description = "Arguments for the RF device driver 2.";
              #};
              #device_args_3 = mkOption {
              #  type = with types; nullOr str;
              #  default = "auto";
              #  description = "Arguments for the RF device driver 3.";
              #};
              time_adv_nsamples = mkOption {
                type = with types; nullOr str;
                description = ''
                  Transmission time advance (in number of samples) to compensate for RF delay from antenna to timestamp insertion.

                  Default "auto". B210 USRP: 100 samples, bladeRF: 27.
                '';
              };
              continuous_tx = mkOption {
                type =
                  with types;
                  nullOr (enum [
                    "auto"
                    "yes"
                    "no"
                  ]);
                description = "Transmit samples continuously to the radio or on bursts. Default is auto (yes for UHD, no for rest)";
              };
            };
          }
        );
        default = { }; # add default values to config
        description = "RF configuration";
      };

      "rat.eutra" = mkOption {
        type = types.nullOr (
          types.submodule {
            freeformType = ini.type;
            options = {
              dl_earfcn = mkOption {
                type = types.str;
                default = "3350";
                description = "Downlink EARFCN list";
              };
              dl_freq = mkOption {
                type = with types; nullOr str;
                description = "Override DL frequency corresponding to dl_earfcn";
              };
              ul_freq = mkOption {
                type = with types; nullOr str;
                description = "Override UL frequency corresponding to dl_earfcn";
              };
              nof_carriers = mkOption {
                type = with types; nullOr str;
                description = "Number of carriers";
              };
            };
          }
        );
        default = { }; # add default values to config
        description = "EUTRA RAT configuration";
      };

      "rat.nr" = mkOption {
        type = types.nullOr (
          types.submodule {
            freeformType = ini.type;
            options = {
              bands = mkOption {
                type = types.str;
                default = "78";
                description = "List of support NR bands seperated by a comma";
              };
              nof_carriers = mkOption {
                type = with types; nullOr str;
                description = "Number of NR carriers (must be at least 1 for NR support)";
              };
            };
          }
        );
        default = { }; # add default values to config
        description = "NR RAT configuration";
      };

      pcap = mkOption {
        type = types.nullOr (
          types.submodule {
            freeformType = ini.type;
            options = {
              enable = mkOption {
                type =
                  with types;
                  nullOr (
                    listOf (enum [
                      "mac"
                      "mac_nr"
                      "nas"
                      "none"
                    ])
                  );
                apply = builtins.concatStringsSep ","; # convert list to csv
                example = [
                  "mac"
                  "nas"
                ];
                description = "Enable packet captures of layers (mac/mac_nr/nas/none) multiple option list";
              };
              mac_filename = mkOption {
                type = with types; nullOr str;
                example = "/tmp/ue_mac.pcap";
                description = "File path to use for MAC packet capture";
              };
              mac_nr_filename = mkOption {
                type = with types; nullOr str;
                example = "/tmp/ue_mac_nr.pcap";
                description = "File path to use for MAC NR packet capture";
              };
              nas_filename = mkOption {
                type = with types; nullOr str;
                example = "/tmp/ue_nas.pcap";
                description = "File path to use for NAS packet capture";
              };
            };
          }
        );
        default = { }; # add default values to config
        description = ''
          **Packet capture configuration**

          Packet capture is supported at the MAC, MAC_NR, and NAS layer.
          MAC-layer packets are captured to file a the compact format decoded
          by the Wireshark. For decoding, use the UDP dissector and the UDP
          heuristic dissection. Edit the preferences (Edit > Preferences >
          Protocols > DLT_USER) for DLT_USER to add an entry for DLT=149 with
          Protocol=udp. Further, enable the heuristic dissection in UDP under:
          Analyze > Enabled Protocols > MAC-LTE > mac_lte_udp and MAC-NR > mac_nr_udp
          For more information see: https://wiki.wireshark.org/MAC-LTE
          Using the same filename for mac_filename and mac_nr_filename writes both
          MAC-LTE and MAC-NR to the same file allowing a better analysis.
          NAS-layer packets are dissected with DLT=148, and Protocol = nas-eps.
        '';
      };

      log = mkOption {
        type =
          with types;
          submodule {
            freeformType = ini.type;
            options = {
              # TODO generate other options: rf, phy, mac, rlc, pdcp, rrc, nas, gw, usim, stack, all
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
                example = "warning";
                description = "Log levels for all layers";
              };
              phy_lib_level = mkOption {
                type =
                  with types;
                  nullOr (enum [
                    "debug"
                    "info"
                    "warning"
                    "error"
                    "none"
                  ]);
                example = "none";
                description = "Log level for phy layer";
              };
              all_hex_limit = mkOption {
                type = types.str;
                default = "32";
                description = "Limit for packet hex dumps for all layers";
              };
              filename = mkOption {
                type = with types; nullOr str;
                example = "/tmp/ue.log";
                description = "File path to use for log output. Can be set to stdout to print logs to standard output.";
              };
              file_max_size = mkOption {
                type = with types; nullOr str;
                description = "Maximum file size (in kilobytes). When passed, multiple files are created. If set to negative, a single log file will be created.";
              };
            };
          };
        default = { }; # add default values to config
        description = ''
          **Log configuration**

          Log levels can be set for individual layers. "all_level" sets log
          level for all layers unless otherwise configured.
          Format: e.g. phy_level = info

          In the same way, packet hex dumps can be limited for each level.
          "all_hex_limit" sets the hex limit for all layers unless otherwise
          configured.
          Format: e.g. phy_hex_limit = 32
        '';
      };

      usim = mkOption {
        type = types.nullOr (
          types.submodule {
            freeformType = ini.type;
            options = {
              mode = mkOption {
                type =
                  with types;
                  nullOr (enum [
                    "soft"
                    "pcsc"
                  ]);
                description = "USIM mode";
              };
              algo = mkOption {
                type = types.enum [
                  "xor"
                  "milenage"
                ];
                default = "milenage";
                description = "Authentication algorithm";
              };
              # TODO how to do either the one or the other ?
              op = mkOption {
                type = with types; nullOr str;
                default = null;
                example = "63BFA50EE6523365FF14C1F45F88737D";
                description = ''
                  128-bit operator code

                  Specify either op or opc (only used in milenage)
                '';
              };
              opc = mkOption {
                type = with types; nullOr str;
                default = null;
                example = "63BFA50EE6523365FF14C1F45F88737D";
                description = ''
                  128-bit operator code (ciphered variant)

                  Specify either op or opc (only used in milenage)
                '';
              };
              k = mkOption {
                type = types.str;
                example = "00112233445566778899aabbccddeeff";
                description = "128-bit subscriber key (hex)";
              };
              imsi = mkOption {
                type = types.str;
                example = "001010123456780";
                description = "15 digit International Mobile Subscriber Identity";
              };
              imei = mkOption {
                type = types.str;
                example = "353490069873319";
                description = "15 digit International Mobile Station Equipment Identity";
              };
              pin = mkOption {
                type = with types; nullOr str;
                example = "1234";
                description = "PIN in case real SIM card is used";
              };
              reader = mkOption {
                type = with types; nullOr str;
                description = "Specify card reader by it's name as listed by 'pcsc_scan'. If empty, try all available readers.";
              };
            };
          }
        );
        default = { }; # add default values to config
        description = "USIM configuration";
      };

      rrc = mkOption {
        type = types.nullOr (
          types.submodule {
            freeformType = ini.type;
            options = {
              ue_category = mkOption {
                type = with types; nullOr str;
                description = "Sets UE category";
              };
              release = mkOption {
                type = with types; nullOr str;
                description = "UE Release (8 to 15)";
              };
              feature_group = mkOption {
                type = with types; nullOr str;
                description = "Hex value of the featureGroupIndicators field in the UECapabilityInformation message";
              };
              mbms_service_id = mkOption {
                type = with types; nullOr str;
                description = "MBMS service id for autostarting MBMS reception. Default -1 means disabled.";
              };
              mbms_service_port = mkOption {
                type = with types; nullOr str;
                description = "Port of the MBMS service";
              };
              nr_measurement_pci = mkOption {
                type = with types; nullOr str;
                description = "NR PCI for the simulated NR measurement";
              };
              nr_short_sn_support = mkOption {
                type = with types; nullOr bool;
                description = "Announce PDCP short SN support";
              };
            };
          }
        );
        default = { }; # add default values to config
        description = "RRC configuration";
      };

      nas = mkOption {
        type = types.nullOr (
          types.submodule {
            freeformType = ini.type;
            options = {
              apn = mkOption {
                type = with types; nullOr str;
                example = "internet";
                description = "Set Access Point Name (APN)";
              };
              apn_protocol = mkOption {
                type = with types; nullOr str;
                example = "ipv4";
                description = "Set APN protocol (IPv4, IPv6 or IPv4v6.)";
              };
              user = mkOption {
                type = with types; nullOr str;
                example = "srsuser";
                description = "Username for CHAP authentication";
              };
              pass = mkOption {
                type = with types; nullOr str;
                default = "srspass";
                description = "Password for CHAP authentication";
              };
              force_imsi_attach = mkOption {
                type = with types; nullOr bool;
                description = "Whether to always perform an IMSI attach";
              };
              eia = mkOption {
                type = with types; nullOr str; # TODO list
                description = "List of integrity algorithms included in UE capabilities: Supported: 1 - Snow3G, 2 - AES, 3 - ZUC";
              };
              eea = mkOption {
                type = with types; nullOr str; # TODO list
                description = "List of ciphering algorithms included in UE capabilities: Supported: 0 - NULL, 1 - Snow3G, 2 - AES, 3 - ZUC";
              };
            };
          }
        );
        default = { }; # add default values to config
        description = "NAS configuration";
      };

      slicing = mkOption {
        type = types.nullOr (
          types.submodule {
            freeformType = ini.type;
            options = {
              enable = mkEnableOption "slice";
              nssai-sst = mkOption {
                type = with types; nullOr str;
                description = "Specfic Slice Type";
              };
              nssai-sd = mkOption {
                type = with types; nullOr str;
                description = "Slice diffentiator";
              };
            };
          }
        );
        default = { }; # add default values to config
        description = "Slice configuration";
      };

      gw = mkOption {
        type = types.nullOr (
          types.submodule {
            freeformType = ini.type;
            options = {
              netns = mkOption {
                type = with types; nullOr str;
                description = "Network namespace to create TUN device";
              };
              ip_devname = mkOption {
                type = with types; nullOr str;
                example = "tun_srsue";
                description = "Name of the tun_srsue device";
              };
              ip_netmask = mkOption {
                type = with types; nullOr str;
                example = "255.255.255.0";
                description = "Netmask of the tun_srsue device";
              };
            };
          }
        );
        default = { }; # add default values to config
        description = "GW configuration";
      };

      gui = mkOption {
        type = types.nullOr (
          types.submodule {
            freeformType = ini.type;
            options = {
              enable = mkEnableOption "graphical interface";
            };
          }
        );
        default = { }; # add default values to config
        description = ''
          GUI configuration

          Simple GUI displaying PDSCH constellation and channel freq response.
        '';
      };
      /*
        #####################################################################
        # Channel emulator options:
        # enable:            Enable/Disable internal Downlink/Uplink channel emulator
        #
        # -- AWGN Generator
        # awgn.enable:       Enable/disable AWGN generator
        # awgn.snr:          SNR in dB
        # awgn.signal_power: Received signal power in decibels full scale (dBfs)
        #
        # -- Fading emulator
        # fading.enable:     Enable/disable fading simulator
        # fading.model:      Fading model + maximum doppler (E.g. none, epa5, eva70, etu300, etc)
        #
        # -- Delay Emulator     delay(t) = delay_min + (delay_max - delay_min) * (1 + sin(2pi*t/period)) / 2
        #                       Maximum speed [m/s]: (delay_max - delay_min) * pi * 300 / period
        # delay.enable:      Enable/disable delay simulator
        # delay.period_s:    Delay period in seconds.
        # delay.init_time_s: Delay initial time in seconds.
        # delay.maximum_us:  Maximum delay in microseconds
        # delay.minumum_us:  Minimum delay in microseconds
        #
        # -- Radio-Link Failure (RLF) Emulator
        # rlf.enable:        Enable/disable RLF simulator
        # rlf.t_on_ms:       Time for On state of the channel (ms)
        # rlf.t_off_ms:      Time for Off state of the channel (ms)
        #
        # -- High Speed Train Doppler model simulator
        # hst.enable:        Enable/Disable HST simulator
        # hst.period_s:      HST simulation period in seconds
        # hst.fd_hz:         Doppler frequency in Hz
        # hst.init_time_s:   Initial time in seconds
        #####################################################################
        [channel.dl]
        #enable        = false

        [channel.dl.awgn]
        #enable        = false
        #snr           = 30

        [channel.dl.fading]
        #enable        = false
        #model         = none

        [channel.dl.delay]
        #enable        = false
        #period_s      = 3600
        #init_time_s   = 0
        #maximum_us    = 100
        #minimum_us    = 10

        [channel.dl.rlf]
        #enable        = false
        #t_on_ms       = 10000
        #t_off_ms      = 2000

        [channel.dl.hst]
        #enable        = false
        #period_s      = 7.2
        #fd_hz         = 750.0
        #init_time_s   = 0.0

        [channel.ul]
        #enable        = false

        [channel.ul.awgn]
        #enable        = false
        #n0            = -30

        [channel.ul.fading]
        #enable        = false
        #model         = none

        [channel.ul.delay]
        #enable        = false
        #period_s      = 3600
        #init_time_s   = 0
        #maximum_us    = 100
        #minimum_us    = 10

        [channel.ul.rlf]
        #enable        = false
        #t_on_ms       = 10000
        #t_off_ms      = 2000

        [channel.ul.hst]
        #enable        = false
        #period_s      = 7.2
        #fd_hz         = -750.0
        #init_time_s   = 0.0

        #####################################################################
        # PHY configuration options
        #
        # rx_gain_offset:       RX Gain offset to add to rx_gain to calibrate RSRP readings
        # prach_gain:           PRACH gain (dB). If defined, forces a gain for the tranmsission of PRACH only.,
        #                       Default is to use tx_gain in [rf] section.
        # cqi_max:              Upper bound on the maximum CQI to be reported. Default 15.
        # cqi_fixed:            Fixes the reported CQI to a constant value. Default disabled.
        # snr_ema_coeff:        Sets the SNR exponential moving average coefficient (Default 0.1)
        # snr_estim_alg:        Sets the noise estimation algorithm. (Default refs)
        #                          Options: pss:   use difference between received and known pss signal,
        #                                   refs:  use difference between noise references and noiseless (after filtering)
        #                                   empty: use empty subcarriers in the boarder of pss/sss signal
        # pdsch_max_its:        Maximum number of turbo decoder iterations (Default 4)
        # pdsch_meas_evm:       Measure PDSCH EVM, increases CPU load (default false)
        # nof_phy_threads:      Selects the number of PHY threads (maximum 4, minimum 1, default 3)
        # equalizer_mode:       Selects equalizer mode. Valid modes are: "mmse", "zf" or any
        #                       non-negative real number to indicate a regularized zf coefficient.
        #                       Default is MMSE.
        # correct_sync_error:   Channel estimator measures and pre-compensates time synchronization error. Increases CPU usage,
        #                       improves PDSCH decoding in high SFO and high speed UE scenarios.
        # sfo_ema:              EMA coefficient to average sample offsets used to compute SFO
        # sfo_correct_period:   Period in ms to correct sample time to adjust for SFO
        # sss_algorithm:        Selects the SSS estimation algorithm. Can choose between
        #                       {full, partial, diff}.
        # estimator_fil_auto:   The channel estimator smooths the channel estimate with an adaptative filter.
        # estimator_fil_stddev: Sets the channel estimator smooth gaussian filter standard deviation.
        # estimator_fil_order:  Sets the channel estimator smooth gaussian filter order (even values perform better).
        #                       The taps are [w, 1-2w, w]
        #
        # snr_to_cqi_offset:    Sets an offset in the SNR to CQI table. This is used to adjust the reported CQI.
        #
        # interpolate_subframe_enabled: Interpolates in the time domain the channel estimates within 1 subframe. Default is to average.
        #
        # pdsch_csi_enabled:     Stores the Channel State Information and uses it for weightening the softbits. It is only
        #                        used in TM1. It is True by default.
        #
        # pdsch_8bit_decoder:    Use 8-bit for LLR representation and turbo decoder trellis computation (Experimental)
        # force_ul_amplitude:    Forces the peak amplitude in the PUCCH, PUSCH and SRS (set 0.0 to 1.0, set to 0 or negative for disabling)
        #
        # in_sync_rsrp_dbm_th:    RSRP threshold (in dBm) above which the UE considers to be in-sync
        # in_sync_snr_db_th:      SNR threshold (in dB) above which the UE considers to be in-sync
        # nof_in_sync_events:     Number of PHY in-sync events before sending an in-sync event to RRC
        # nof_out_of_sync_events: Number of PHY out-sync events before sending an out-sync event to RRC
        #
        # force_N_id_2: Force using a specific PSS (set to -1 to allow all PSSs).
        # force_N_id_1: Force using a specific SSS (set to -1 to allow all SSSs).
        #
        #####################################################################
        [phy]
        #rx_gain_offset      = 62
        #prach_gain          = 30
        #cqi_max             = 15
        #cqi_fixed           = 10
        #snr_ema_coeff       = 0.1
        #snr_estim_alg       = refs
        #pdsch_max_its       = 8    # These are half iterations
        #pdsch_meas_evm      = false
        #nof_phy_threads     = 3
        #equalizer_mode      = mmse
        #correct_sync_error  = false
        #sfo_ema             = 0.1
        #sfo_correct_period  = 10
        #sss_algorithm       = full
        #estimator_fil_auto  = false
        #estimator_fil_stddev  = 1.0
        #estimator_fil_order  = 4
        #snr_to_cqi_offset   = 0.0
        #interpolate_subframe_enabled = false
        #pdsch_csi_enabled  = true
        #pdsch_8bit_decoder = false
        #force_ul_amplitude = 0
        #detect_cp          = false

        #in_sync_rsrp_dbm_th    = -130.0
        #in_sync_snr_db_th      = 3.0
        #nof_in_sync_events     = 10
        #nof_out_of_sync_events = 20

        #force_N_id_2           = 1
        #force_N_id_1           = 10

        #####################################################################
        # PHY NR specific configuration options
        #
        # store_pdsch_ko:       Dumps the PDSCH baseband samples into a file on KO reception
        #
        #####################################################################
        [phy.nr]
        #store_pdsch_ko = false

        #####################################################################
        # CFR configuration options
        #
        # The CFR module provides crest factor reduction for the transmitted signal.
        #
        # enable:           Enable or disable the CFR. Default: disabled
        #
        # mode:             manual:   CFR threshold is set by cfr_manual_thres (default).
        #                   auto_ema: CFR threshold is adaptive based on the signal PAPR. Power avg. with Exponential Moving Average.
        #                             The time constant of the averaging can be tweaked with the ema_alpha parameter.
        #                   auto_cma: CFR threshold is adaptive based on the signal PAPR. Power avg. with Cumulative Moving Average.
        #                             Use with care, as CMA's increasingly slow response may be unsuitable for most use cases.
        #
        # strength:         Ratio between amplitude-limited vs unprocessed signal (0 to 1). Default: 1
        # manual_thres:     Fixed manual clipping threshold for CFR manual mode. Default: 2
        # auto_target_papr: Signal PAPR target (in dB) in CFR auto modes. output PAPR can be higher due to peak smoothing. Default: 7
        # ema_alpha:        Alpha coefficient for the power average in auto_ema mode. Default: 1/7
        #
        #####################################################################
        [cfr]
        #enable           = false
        #mode             = manual
        #manual_thres     = 2.0
        #strength         = 1.0
        #auto_target_papr = 7.0
        #ema_alpha        = 0.0143

        #####################################################################
        # Simulation configuration options
        #
        # The UE simulation supports turning on and off airplane mode in the UE.
        # The actions are carried periodically until the UE is stopped.
        #
        # airplane_t_on_ms:   Time to leave airplane mode turned on (in ms)
        #
        # airplane_t_off_ms:  Time to leave airplane mode turned off (in ms)
        #
        #####################################################################
        [sim]
        #airplane_t_on_ms  = -1
        #airplane_t_off_ms = -1

        #####################################################################
        # General configuration options
        #
        # metrics_csv_enable:    Write UE metrics to CSV file.
        #
        # metrics_period_secs:   Sets the period at which metrics are requested from the UE.
        #
        # metrics_csv_filename:  File path to use for CSV metrics.
        #
        # tracing_enable:        Write source code tracing information to a file.
        #
        # tracing_filename:      File path to use for tracing information.
        #
        # tracing_buffcapacity:  Maximum capacity in bytes the tracing framework can store.
        #
        # have_tti_time_stats:   Calculate TTI execution statistics using system clock
        #
        # metrics_json_enable:   Write UE metrics to JSON file.
        #
        # metrics_json_filename: File path to use for JSON metrics.
        #
        #####################################################################
        [general]
        #metrics_csv_enable    = false
        #metrics_period_secs   = 1
        #metrics_csv_filename  = /tmp/ue_metrics.csv
        #have_tti_time_stats   = true
        #tracing_enable        = true
        #tracing_filename      = /tmp/ue_tracing.log
        #tracing_buffcapacity  = 1000000
        #metrics_json_enable   = false
        #metrics_json_filename = /tmp/ue_metrics.json

        _template = mkOption {
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
      */
    };
  };
}
