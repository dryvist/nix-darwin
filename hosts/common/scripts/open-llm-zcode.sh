#!/usr/bin/env bash
# zcode — the open-llm identity's Z.ai-backed claude launcher.
#
# A real PATH command, not a zsh function: a zsh-function `zcode` is
# invisible to any non-interactive invocation (`sudo -u open-llm -i zcode`,
# `su -l open-llm -c zcode`, cron, launchd). claude-zai (nix-ai#2214) is now
# a real binary too, so no zsh -ic re-source is needed to reach it.
exec openbao-run --domain open-llm \
  --env-file "$HOME/.openbao/open-llm.env" \
  --secrets apps/open-llm \
  -- claude-zai "$@"
