#!/usr/bin/env bats
#
# The transcript_mask Mask rules, applied the way Cribl applies them: each
# rule's regex in turn, every match replaced. The rules are read from the Nix
# file itself, so the test cannot drift from what ships. Perl stands in for the
# JavaScript engine; every construct these rules use (\b, character classes,
# lazy [\s\S]*?) means the same in both.
#
# Sample credentials are assembled at runtime from fragments so no
# credential-shaped literal sits in this file for a secret scanner to flag.

MASK_NIX="$BATS_TEST_DIRNAME/../../hosts/common/cribl-transcript-mask.nix"

rules() {
  awk "/transcript_mask\/conf.yml\" = ''/{f=1;next} /^  '';/{f=0} f" "$MASK_NIX" \
    | yq -r '.functions[0].conf.rules[] | .matchRegex + "\t" + .replaceExpr'
}

mask() {
  local text="$1" re rep
  while IFS=$'\t' read -r re rep; do
    re="${re#/}"; re="${re%/g}"
    rep="${rep#\'}"; rep="${rep%\'}"
    text="$(RE="$re" REP="$rep" perl -0pe 's/$ENV{RE}/$ENV{REP}/g' <<<"$text")"
  done < <(rules)
  printf '%s' "$text"
}

rep() { printf "%${2}s" "" | tr ' ' "$1"; }

@test "the rules parse out of the Nix file" {
  run rules
  [ "$status" -eq 0 ]
  [ "$(wc -l <<<"$output")" -ge 8 ]
}

@test "every credential shape is masked" {
  local p="ghs" q="ghp" b="hvs" d="dp" x="xoxb" s="sk" a="AKIA" e="eyJ"
  local samples=(
    "${p}_1234567_${e}$(rep a 20).${e}$(rep b 20).$(rep c 20)"
    "${q}_$(rep A 36)"
    "github_pat_$(rep B 60)"
    "${b}.$(rep C 30)"
    "${d}.st.prd.$(rep D 30)"
    "${e}$(rep E 12).${e}$(rep F 12).$(rep G 12)"
    "${x}-123456789012-$(rep H 20)"
    "${s}-ant-api03-$(rep I 30)"
    "${a}$(rep J 16)"
    "-----BEGIN RSA PRIVATE KEY-----\\nMII$(rep K 40)\\n-----END RSA PRIVATE KEY-----"
  )
  local t out
  for t in "${samples[@]}"; do
    out="$(mask "token=${t} rest")"
    [[ "$out" == "token=<redacted:"*"> rest" ]] || { echo "not masked: $out"; return 1; }
  done
}

@test "ordinary transcript text is left alone" {
  local t
  for t in \
    "process.environment_variables_are_long_here" \
    "/Users/someone/.claude/projects/-Users-someone-git/0a1b2c3d-4e5f-6789-abcd-ef0123456789.jsonl" \
    "commit 0bf04a17e3d2c1b0a9f8e7d6c5b4a3f2e1d0c9b8" \
    "gh""s_short" \
    "sk-learn and scikit-learn" \
    "see s.t. and e.g. here"; do
    [ "$(mask "$t")" = "$t" ] || { echo "changed: $t"; return 1; }
  done
}
