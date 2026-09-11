# Configures macOS Launch Services to recognize custom file extensions
# as specific archive types using UTI (Uniform Type Identifier) mappings.
#
# Reference: https://developer.apple.com/documentation/uniformtypeidentifiers

{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.programs.file-extensions;
in
{
  options.programs.file-extensions = {
    enable = lib.mkEnableOption "custom file extension mappings";

    customMappings = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        ".spl" = "public.tar-archive";
        ".crbl" = "public.tar-archive";
      };
      description = ''
        Custom file extension mappings, keyed by extension (e.g., ".spl").
        Each value is passed straight to duti, which accepts either a UTI
        (Uniform Type Identifier) or an app's bundle identifier — a UTI
        determines how macOS handles the file type generally, while a
        bundle id binds the extension straight to one app (useful when no
        UTI exists for the file type at all).
      '';
      example = {
        ".spl" = "public.tar-archive";
        ".crbl" = "public.tar-archive";
        ".custom" = "public.zip-archive";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Validate that extensions start with a dot
    assertions = [
      {
        assertion = lib.all (ext: lib.hasPrefix "." ext) (lib.attrNames cfg.customMappings);
        message = "All file extensions must start with a dot (e.g., '.spl', not 'spl')";
      }
    ];

    # Install duti for setting file associations
    environment.systemPackages = [ pkgs.duti ];

    # Configure file associations using duti during system activation
    system.activationScripts.postActivation.text = lib.mkAfter ''
      echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Configuring custom file extension mappings..."
      failures=0

      DUTI_CONFIG=$(mktemp)
      LS_ERROR_LOG=$(mktemp)
      trap 'rm -f "$DUTI_CONFIG" "$LS_ERROR_LOG"' EXIT

      printf '%s\n' ${
        lib.concatMapStringsSep " " lib.escapeShellArg (
          lib.mapAttrsToList (ext: uti: "${uti} ${ext} all") cfg.customMappings
        )
      } > "$DUTI_CONFIG"

      if ${pkgs.duti}/bin/duti "$DUTI_CONFIG" 2>/dev/null; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Successfully registered ${toString (lib.length (lib.attrNames cfg.customMappings))} file extension(s)"

        if /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -domain user 2>"$LS_ERROR_LOG" >/dev/null; then
          echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Launch Services database refreshed (user domain)"
        else
          echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] Launch Services refresh failed - associations may require re-login" >&2
          cat "$LS_ERROR_LOG" >&2
          failures=$((failures + 1))
        fi
      else
        echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] Failed to apply file extension mappings" >&2
        failures=$((failures + 1))
      fi

      if [ $failures -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] File extension mappings configured successfully"
      else
        echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] File extension configuration completed with $failures failure(s)" >&2
      fi
    '';

  };
}
