# Per-OS-user AI-CLI transcript inputs (standalone Edge GitOps config)
#
# Split out of ./cribl.nix for the repo file-size gate: this generates one
# full claude/codex/gemini/antigravity input set PER MANAGED OS USER
# (userConfig.user plus every automation identity in userConfig.agentUsers —
# modules/darwin/agent-identity.nix), so a second OS user's transcripts are
# collected too. The result is a plain YAML text fragment, spliced verbatim
# into cribl.nix's `inputs.yml` body under `inputs:`.

{ lib, userConfig }:

let
  # Every managed OS user whose home gets AI-CLI transcript collection.
  # Enumerated explicitly rather than a $HOME wildcard, so a new OS user is a
  # Nix change here, not an implicit pickup by a glob.
  aiHomes = [
    {
      user = userConfig.user.name;
      inherit (userConfig.user) homeDir;
    }
  ]
  ++ lib.mapAttrsToList (name: agent: {
    user = name;
    inherit (agent) homeDir;
  }) userConfig.agentUsers;

  # One full AI-CLI transcript input set per OS user above, input names
  # suffixed `_<user>` so each stays a distinct, independently-tracked
  # source. `enduser_id` (OpenTelemetry enduser.id semantics, underscore
  # form for Splunk field-naming) is stamped as a literal per input rather
  # than parsed from the path at runtime: the owning user is already known
  # statically at generation time.
  #
  # Splicing this multi-line string into inputs.yml's YAML body needs every
  # line at the right depth, but the OUTER string's own indentation prefix
  # (see the splice site in cribl.nix) only reaches this value's FIRST line
  # — an embedded newline carries no outer indentation with it. So the raw
  # per-user YAML below (each `in_*` key at column 0, its own fields/lists
  # relatively indented, per this string's OWN common-indentation strip) has
  # 2 extra spaces added to every line but the first, matching the 2-space
  # prefix the splice site supplies for the first line alone.
  mkAiCliInputsRaw =
    { user, homeDir }:
    ''
      in_claude_logs_${user}:
        type: file
        disabled: false
        mode: manual
        interval: 10
        path: ${homeDir}/.claude/projects/
        filenames:
          - "*.jsonl"
        recurse: true
        tailOnly: true
        sendToRoutes: false
        metadata:
          - name: enduser_id
            value: "'${user}'"
        connections:
          - output: cribl_claude
      in_codex_sessions_${user}:
        type: file
        disabled: false
        mode: manual
        interval: 30
        path: ${homeDir}/.codex/sessions
        filenames:
          - "*/rollout-*.jsonl"
        recurse: true
        tailOnly: false
        sendToRoutes: false
        breakerRulesets:
          - AI CLI JSONL
        metadata:
          - name: datatype
            value: "'codex-cli-session'"
          - name: enduser_id
            value: "'${user}'"
        connections:
          - pipeline: codex_sessions
            output: cribl_codex
      in_codex_history_${user}:
        type: file
        disabled: false
        mode: manual
        interval: 30
        path: ${homeDir}/.codex
        filenames:
          - "*/history.jsonl"
        recurse: false
        tailOnly: false
        sendToRoutes: false
        breakerRulesets:
          - AI CLI JSONL
        metadata:
          - name: datatype
            value: "'codex-cli-history'"
          - name: enduser_id
            value: "'${user}'"
        connections:
          - pipeline: codex_history
            output: cribl_codex
      in_gemini_sessions_${user}:
        type: file
        disabled: false
        mode: manual
        interval: 30
        path: ${homeDir}/.gemini/tmp
        filenames:
          - "*session-*.json"
          - "*session-*.jsonl"
        recurse: true
        tailOnly: true
        sendToRoutes: false
        breakerRulesets:
          - AI CLI JSONL
        metadata:
          - name: datatype
            value: "'gemini-cli-session'"
          - name: enduser_id
            value: "'${user}'"
        connections:
          - pipeline: llm_normalize
            output: cribl_agy
      in_antigravity_transcripts_${user}:
        type: file
        disabled: false
        mode: manual
        interval: 60
        path: ${homeDir}/.gemini/antigravity-cli/brain
        filenames:
          - "*/transcript_full.jsonl"
        recurse: true
        tailOnly: false
        sendToRoutes: false
        breakerRulesets:
          - AI CLI JSONL
        metadata:
          - name: datatype
            value: "'antigravity-cli-transcript'"
          - name: enduser_id
            value: "'${user}'"
        connections:
          - pipeline: llm_normalize
            output: cribl_agy
      in_antigravity_history_${user}:
        type: file
        disabled: false
        mode: manual
        interval: 30
        path: ${homeDir}/.gemini/antigravity-cli
        filenames:
          - "*history.jsonl"
        recurse: false
        tailOnly: true
        sendToRoutes: false
        breakerRulesets:
          - AI CLI JSONL
        metadata:
          - name: datatype
            value: "'antigravity-cli-history'"
          - name: enduser_id
            value: "'${user}'"
        connections:
          - pipeline: llm_normalize
            output: cribl_agy
    '';
in

# Every user's raw block concatenated FIRST, then the +2-spaces-per-line
# fix-up applied ONCE across the whole result — applying it per-user call
# would also re-exempt each user's own first line, which (after the first)
# is a MIDDLE line of the spliced block, not the outer string's first line.
lib.concatStringsSep "\n" (
  lib.imap0 (i: l: if i == 0 || l == "" then l else "  " + l) (
    lib.splitString "\n" (lib.concatMapStrings mkAiCliInputsRaw aiHomes)
  )
)
