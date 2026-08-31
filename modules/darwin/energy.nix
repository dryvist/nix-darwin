# Energy & Sleep Configuration
#
# macOS energy/sleep settings via pmset (Power Management Settings)
# Reference: https://ss64.com/mac/pmset.html
#
# Power sources:
#   -a  All power sources (battery, AC, UPS)
#   -c  AC power (plugged in)
#   -b  Battery
#   -u  UPS
#
# pmset parameters:
#   displaysleep N   - Display sleep timer (minutes, 0 = never)
#   sleep N          - System sleep timer (minutes, 0 = never)
#   disksleep N      - Disk spindown timer (minutes, 0 = never)
#   womp 0/1         - Wake on Magic Packet (Ethernet)
#   lidwake 0/1      - Wake on lid open (laptops)
#   acwake 0/1       - Wake on AC power connect

{ lib, config, ... }:

let
  cfg = config.system.energy;
in
{
  options.system.energy = {
    enable = lib.mkEnableOption "Energy and sleep configuration";

    displaysleep = lib.mkOption {
      type = lib.types.int;
      default = 10;
      description = "Display sleep timer in minutes (0 = never). Base for all power sources; AC is overridden by displaysleepAc.";
    };

    displaysleepAc = lib.mkOption {
      type = lib.types.int;
      default = 60;
      description = "Display sleep timer when on AC power (minutes, 0 = never). Overrides displaysleep while plugged in.";
    };

    sleep = {
      ac = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = "System sleep timer when on AC power (0 = never)";
      };

      battery = lib.mkOption {
        type = lib.types.int;
        default = 30;
        description = "System sleep timer when on battery (0 = never)";
      };
    };

    disksleep = lib.mkOption {
      type = lib.types.int;
      default = 10;
      description = "Disk spindown timer in minutes (0 = never). Set to 0 for SSDs.";
    };

    wakeOnMagicPacket = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Wake on Magic Packet (Wake-on-LAN)";
    };

    # Restart-after-power-failure is NOT here: it is nix-darwin's native
    # `power.restartAfterPowerFailure`, set by host class in
    # hosts/common/default.nix. Carrying it as a `pmset -a autorestart` flag
    # bundled into the invocation below meant one knob that a portable rejects
    # could take the other three down with it.
  };

  config = lib.mkIf cfg.enable {
    system.activationScripts.postActivation.text = lib.mkAfter ''
      echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Configuring energy and sleep settings..."
      failures=0

      if sudo pmset -a \
        displaysleep ${toString cfg.displaysleep} \
        disksleep ${toString cfg.disksleep} \
        womp ${if cfg.wakeOnMagicPacket then "1" else "0"}; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Common energy settings applied"
      else
        echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] Failed to apply common energy settings (attempted: display ${toString cfg.displaysleep}m, disk ${toString cfg.disksleep}m)" >&2
        failures=$((failures + 1))
      fi

      if sudo pmset -c sleep ${toString cfg.sleep.ac} displaysleep ${toString cfg.displaysleepAc}; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] AC power settings applied (sleep: ${toString cfg.sleep.ac} min, display: ${toString cfg.displaysleepAc} min)"
      else
        echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] Failed to apply AC power settings (attempted: sleep ${toString cfg.sleep.ac} min, display ${toString cfg.displaysleepAc} min)" >&2
        failures=$((failures + 1))
      fi

      if sudo pmset -b sleep ${toString cfg.sleep.battery}; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Battery settings applied (sleep: ${toString cfg.sleep.battery} min)"
      else
        echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] Failed to apply battery settings (attempted: ${toString cfg.sleep.battery} min)" >&2
        failures=$((failures + 1))
      fi

      if [ $failures -lt 3 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Current pmset configuration:"
        sudo pmset -g || echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] Could not display pmset settings" >&2
      fi
    '';
  };
}
