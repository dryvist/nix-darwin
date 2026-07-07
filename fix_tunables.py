import re

with open('modules/darwin/apple-silicon-tunables.nix', 'r') as f:
    content = f.read()

replacement = """        iogpu.wired_limit_mb — wired-memory ceiling for the IOGPU subsystem.
        0 = OS default (~75% of RAM). Default 118000 = ~92% of a 128 GB host.
        Volatile: re-applied at every boot via a one-shot launchd daemon."""

content = re.sub(r'<<<<<<< HEAD.*?=======\n.*?\n>>>>>>> origin/main', replacement, content, flags=re.DOTALL)

with open('modules/darwin/apple-silicon-tunables.nix', 'w') as f:
    f.write(content)

