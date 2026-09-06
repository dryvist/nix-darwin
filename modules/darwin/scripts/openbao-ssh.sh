#!/usr/bin/env bash
#
# OpenBao SSH client-CA certificate provider — the ssh analogue of
# openbao-github-creds.sh and openbao-aws-creds.sh.
#
#   openbao-ssh [--role NAME] [--ttl DURATION] [--] <ssh args...>
#
# Mints a throwaway ed25519 keypair in a private temp directory, has the OpenBao
# SSH client CA sign the public half, and runs ssh with that certificate. The
# keypair, the certificate and the OpenBao token all live only for the lifetime
# of the process: the EXIT trap revokes the token and deletes the directory.
# Nothing is ever cached on disk, and there is no static-key fallback.
#
# THE TRAP THAT COSTS THE MOST TIME: the login user is NOT the certificate
# principal. The CA roles carry the principal `ansible`, and that principal is
# mapped onto root on the guests — there is no `ansible` account to log into.
# Connect as `root@<host>`. A "Permission denied" as `ansible@<host>` is the
# expected result of using the wrong login user; it is NOT evidence that the CA,
# the role or the certificate is broken.
#
# Secret zero — BAO_ADDR (legacy VAULT_ADDR accepted) plus the AppRole pair
# OPENBAO_APPROLE_ANSIBLE_ROLE_ID / _SECRET_ID — is supplied AMBIENTLY by the
# environment and is read only at invocation time. When it is absent the script
# exits naming the exact wrapper that supplies it (see the error text below).
#
# The OpenBao token is passed to curl through a process-substituted header file,
# so it never appears in a command line, in the process table, or in `curl -v`
# output. ssh-keygen and ssh come from openssh; jq and curl are the only other
# runtime dependencies.

role=${SSH_CA_ROLE:-automation-ansible}
ttl=${SSH_CERT_TTL:-2h}
mount=${SSH_CA_MOUNT:-ssh-client-ca}

# Options are consumed only up to the first non-option argument (or an explicit
# `--`); everything after that is handed to ssh untouched, so ssh's own flags
# keep working.
while [[ ${1:-} == --* ]]; do
  case $1 in
  --role)
    role=$2
    shift 2
    ;;
  --ttl)
    ttl=$2
    shift 2
    ;;
  --)
    shift
    break
    ;;
  *)
    echo "openbao-ssh: unknown option $1" >&2
    exit 2
    ;;
  esac
done

: "${BAO_ADDR:=${VAULT_ADDR:-}}"
if [[ -z $BAO_ADDR ]]; then
  echo "openbao-ssh: BAO_ADDR (or legacy VAULT_ADDR) is unset" >&2
  exit 3
fi

if [[ -z ${OPENBAO_APPROLE_ANSIBLE_ROLE_ID:-} || -z ${OPENBAO_APPROLE_ANSIBLE_SECRET_ID:-} ]]; then
  echo "openbao-ssh: AppRole secret zero absent. Retry as:" >&2
  echo "  doppler run -p iac-conf-mgmt -c prd -- openbao-ssh $*" >&2
  exit 3
fi

workdir=$(mktemp -d "${TMPDIR:-/tmp}/openbao-ssh.XXXXXX")
chmod 700 "$workdir"
token=""

cleanup() {
  if [[ -n $token ]]; then
    curl -sS -o /dev/null -X POST -H "X-Vault-Token: $token" \
      "$BAO_ADDR/v1/auth/token/revoke-self" 2>/dev/null || true
  fi
  rm -rf "$workdir"
}
trap cleanup EXIT

(umask 077 && ssh-keygen -q -t ed25519 -N '' -C openbao-ssh -f "$workdir/id")

token=$(jq -nc \
  --arg role_id "$OPENBAO_APPROLE_ANSIBLE_ROLE_ID" \
  --arg secret_id "$OPENBAO_APPROLE_ANSIBLE_SECRET_ID" \
  '{role_id: $role_id, secret_id: $secret_id}' |
  curl -fsSL --max-time 10 -H 'Content-Type: application/json' --data @- \
    "$BAO_ADDR/v1/auth/approle/login" | jq -er '.auth.client_token')

jq -nc --rawfile public_key "$workdir/id.pub" --arg ttl "$ttl" \
  '{public_key: $public_key, ttl: $ttl}' |
  curl -fsSL --max-time 10 -H @<(printf 'X-Vault-Token: %s\n' "$token") --data @- \
    "$BAO_ADDR/v1/$mount/sign/$role" | jq -er '.data.signed_key' >"$workdir/id-cert.pub"

# IdentitiesOnly keeps the ssh agent and any ~/.ssh keys out of the way so the
# certificate is the only credential offered. Host key checking is deliberately
# left at its default.
ssh -o IdentitiesOnly=yes -i "$workdir/id" "$@"
