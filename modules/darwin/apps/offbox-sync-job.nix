# Per-job options for programs.offboxSync (see offbox-sync.nix).
{ lib }:
lib.types.submodule {
  options = {
    name = lib.mkOption {
      type = lib.types.str;
      description = "Short identifier; appears in the emitted facts.";
    };
    source = lib.mkOption {
      type = lib.types.str;
      description = "Absolute local path to replicate from.";
    };
    dest = lib.mkOption {
      type = lib.types.str;
      description = "Remote path under the SFTP root, e.g. \"data\".";
    };
    immutable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Treat already-transferred files as never changing. Correct for
        date-partitioned capture output, where a changed file means
        corruption and should surface as an error rather than a silent
        overwrite. Must be false for mutable trees (notes, transcripts).
      '';
    };
    maxAge = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "36h";
      description = ''
        Only consider files newer than this. Combined with --no-traverse it
        is what makes a short interval viable against a tree with hundreds of
        thousands of files: the remote is never listed, only the few
        candidates are stat'd. Leave null for mutable trees, where an edit to
        an old file must still replicate.
      '';
    };
    keepVersions = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Preserve superseded remote files by renaming them with a dated
        suffix instead of overwriting. Use for mutable trees so an edit
        cannot destroy the prior remote copy. Unnecessary for immutable
        trees, where a changed file is corruption rather than an update.
      '';
    };
    minAge = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "30m";
      description = ''
        Per-job override of the global minAge. Needed when a source writes
        one file over a long span with pauses in it: the global 2m floor lets
        such a file be copied during a lull, and when the writer appends
        afterwards an immutable job wedges permanently on an immutable-file
        -modified error. Every later run then fails, so nothing else in that
        job replicates either. Observed live. Set above the longest write
        span for the source. Null inherits the global value.
      '';
    };
  };
}
