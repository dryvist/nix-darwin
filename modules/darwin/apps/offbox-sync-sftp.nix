# SFTP backend flags for programs.offboxSync (see offbox-sync.nix). The host,
# user, key file and known_hosts file arrive as shell words: the global target
# passes OpenBao-sourced variables, a job's own target passes literal values.
{ transfers }:
{
  host,
  user,
  keyFile,
  knownHosts,
}:
[
  "--sftp-host ${host}"
  "--sftp-user ${user}"
  "--sftp-key-file ${keyFile}"
  # rclone needs @cert-authority for certificates, while this file pins plain keys.
  "--sftp-host-key-algorithms \"ssh-ed25519 ecdsa-sha2-nistp256 rsa-sha2-512 rsa-sha2-256\""
  # Host-key validation stays ON. rclone silently disables it unless a
  # known_hosts file is named, which would make a MITM on this path
  # invisible; the estate's standing rule is that host-key checking is
  # never traded for convenience.
  "--sftp-known-hosts-file ${knownHosts}"
  "--sftp-concurrency ${toString transfers}"
]
