# Argv prefix that runs a command under openbao-run: it logs in with one AppRole
# domain from that domain's secret-zero env file and injects each secret as an
# environment variable. Entries are `NAME=path#field` or `mount:NAME=path#field`;
# the command follows the returned `--`.
{ lib }:
{
  package,
  domain,
  envFile,
  secrets,
}:
[
  "/bin/bash"
  (lib.getExe package)
  "--domain"
  domain
  "--env-file"
  envFile
]
++ lib.concatMap (secret: [
  "--secret"
  secret
]) secrets
++ [ "--" ]
