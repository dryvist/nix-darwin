# Custom File Extension Mappings

This documentation explains how to configure custom file extension mappings on macOS to enable proper file type recognition for non-standard archive extensions.

## Overview

Some tools distribute archives with custom file extensions (e.g., `.spl`, `.crbl`) instead of standard `.tar.gz` extensions.
macOS treats these as unknown files, which breaks:

- **Finder auto-extract**: Double-clicking doesn't automatically extract the archive
- **Shell autocomplete**: Tab completion doesn't recognize these as archive files
- **File icons**: Files don't display the proper archive icon
- **Quick Look**: Preview doesn't work correctly

The `file-extensions` module solves this by configuring macOS Launch Services to recognize these custom extensions as specific file types.

## Features

- Declarative configuration via Nix
- Automatic registration with macOS Launch Services
- Support for any UTI (Uniform Type Identifier) type
- Pre-configured mappings for `.spl` and `.crbl` as tar.gz archives
- Easy to extend with additional custom extensions

## Quick Start

The feature is enabled by default with mappings for `.spl` and `.crbl`:

```nix
# In your host configuration (e.g., hosts/macbook-m4/default.nix)
programs.file-extensions = {
  enable = true;
  # Default mappings are already configured:
  # .spl and .crbl → public.tar-archive
};
```

After running `darwin-rebuild switch`, files with `.spl` and `.crbl` extensions will be recognized as tar.gz archives.

## Adding Custom Extensions

To add your own custom file extension mappings:

```nix
programs.file-extensions = {
  enable = true;
  customMappings = {
    ".spl" = "public.tar-archive";
    ".crbl" = "public.tar-archive";
    ".myarchive" = "public.tar-archive";
    ".myzip" = "public.zip-archive";
  };
};
```

## Common UTI Types

Here are the most commonly used UTI (Uniform Type Identifier) values:

| UTI | Description | Standard Extensions |
| --- | --- | --- |
| `public.tar-archive` | TAR archives (including gzipped) | `.tar`, `.tar.gz`, `.tgz` |
| `public.zip-archive` | ZIP archives | `.zip` |
| `public.gzip-archive` | GZIP compressed files | `.gz` |
| `public.bzip2-archive` | BZIP2 compressed files | `.bz2` |
| `org.7-zip.7-zip-archive` | 7-Zip archives | `.7z` |
| `public.archive` | Generic archive type | - |

For a complete list of UTI types, see [Apple's UTI Reference](https://developer.apple.com/documentation/uniformtypeidentifiers).

## How It Works

When you enable the module:

1. **duti is installed**: A command-line utility for managing file associations
2. **Mappings are registered**: During system activation, `duti` registers your custom extensions with macOS
3. **Launch Services is updated**: The system's Launch Services database is rebuilt to recognize the new associations
4. **Changes take effect**: Finder and shell tools immediately recognize the custom extensions

The configuration is applied during `darwin-rebuild switch` and persists across reboots.

## Verification

To verify that your extensions are properly registered:

```bash
# Check file type for a .spl file
mdls -name kMDItemContentType example.spl
# Should show: kMDItemContentType = "public.tar-archive"

# Check default handler
duti -x spl
# Should show archive handler information
```

## Troubleshooting

### Extensions not recognized after rebuild

1. **Restart Finder**:

   ```bash
   killall Finder
   ```

2. **Rebuild Launch Services database manually**:

   ```bash
   /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -domain user
   ```

3. **Check for errors in activation logs**:

   ```bash
   darwin-rebuild switch --show-trace
   ```

### File still opens with wrong application

The module sets the default handler based on the UTI type. If you want to specify a particular application:

```bash
# Set a specific app as default for .spl files
duti -s com.apple.archiveutility .spl all
```

### Shell autocomplete not working

Shell autocomplete behavior depends on your shell configuration. For zsh:

1. Ensure you're using the latest shell completion scripts
2. Restart your terminal or run: `exec zsh`

## Implementation Details

The module uses:

- **duti**: For declarative file association management
- **PlistBuddy**: For plist manipulation (if needed)
- **lsregister**: For refreshing the Launch Services database (user domain only)
- **System activation scripts**: For applying configuration during rebuild

The implementation follows the nix-darwin module pattern and integrates with the existing system activation workflow.

## Examples

### Scientific Data Archives

```nix
customMappings = {
  ".spl" = "public.tar-archive";   # Seismic data
  ".crbl" = "public.tar-archive";  # Calibration data
  ".dat.gz" = "public.gzip-archive";
};
```

### Custom Build Artifacts

```nix
customMappings = {
  ".bundle" = "public.zip-archive";
  ".package" = "public.tar-archive";
  ".artifact" = "public.archive";
};
```

### Development Tools

```nix
customMappings = {
  ".sdist" = "public.tar-archive";  # Python source distributions
  ".whl" = "public.zip-archive";    # Python wheels
};
```

## Security Considerations

- Only add mappings for file types you trust
- Custom extensions will be automatically extracted by the system
- Be cautious with extensions that could be executable content
- Verify the source of files before opening

## Contributing

To add new default mappings to the module:

1. Update `modules/darwin/file-extensions.nix`
2. Add appropriate defaults to the `customMappings` option
3. Update this documentation with examples
4. Test on a clean system

## References

- [macOS Launch Services](https://developer.apple.com/documentation/coreservices/launch_services)
- [Uniform Type Identifiers](https://developer.apple.com/documentation/uniformtypeidentifiers)
- [duti - Command-line Utility to Set Default Apps](https://github.com/moretension/duti)
- [nix-darwin Documentation](https://daiderd.com/nix-darwin/)
