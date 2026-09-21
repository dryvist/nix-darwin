#!/usr/bin/env bash
# zcode — the open-llm identity's Z.ai-backed claude launcher.
#
# A real PATH command, not a zsh function: a zsh-function `zcode` is
# invisible to any non-interactive invocation (`sudo -u open-llm -i zcode`,
# `su -l open-llm -c zcode`, cron, launchd), because none of those source
# interactive zshrc for the OUTER command itself. `-ic` below re-sources
# zshrc in the INNER exec'd child only, so the `claude-zai` function
# (defined there, nix-ai modules/ai-aliases.zsh) exists to call.
exec openbao-run --domain open-llm \
  --env-file "$HOME/.openbao/open-llm.env" \
  --secrets apps/open-llm \
  -- zsh -ic 'claude-zai "$@"' zsh "$@"
