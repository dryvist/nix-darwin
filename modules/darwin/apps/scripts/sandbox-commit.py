#!/usr/bin/env python3
"""sandbox-commit — commit changes via GitHub GraphQL API (createCommitOnBranch).

Designed for untrusted harnesses (open-llm) that hold zero local signing keys.
Commits are created via the GitHub API using an ephemeral App token minted at
call time by openbao-github-creds, producing verified GitHub App signed commits
without storing any private signing keys on the machine.

Usage:
  sandbox-commit <commit-headline> [commit-body]
"""

import base64
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen


def die(msg: str):
    print(f"[sandbox-commit] Error: {msg}", file=sys.stderr)
    sys.exit(1)


def run_cmd(cmd: list[str], cwd: Path | None = None) -> str:
    try:
        res = subprocess.run(
            cmd,
            cwd=cwd,
            capture_output=True,
            text=True,
            check=True,
        )
        return res.stdout.strip()
    except subprocess.CalledProcessError as e:
        die(f"command failed: {' '.join(cmd)}\n{e.stderr}")


def parse_repo_owner_name(remote_url: str) -> tuple[str, str]:
    # Match https://github.com/owner/repo(.git) or git@github.com:owner/repo(.git)
    m = re.search(r"github\.com[:/]([a-zA-Z0-9_.-]+)/([a-zA-Z0-9_.-]+?)(?:\.git)?$", remote_url)
    if not m:
        die(f"cannot parse GitHub owner/repo from remote URL: {remote_url}")
    return m.group(1), m.group(2)


def main():
    if len(sys.argv) < 2:
        print("usage: sandbox-commit <commit-headline> [commit-body]", file=sys.stderr)
        sys.exit(1)

    headline = sys.argv[1].strip()
    if not headline:
        die("commit headline cannot be empty")
    body = sys.argv[2].strip() if len(sys.argv) > 2 else ""

    # Ensure in a git repository
    try:
        repo_root = Path(run_cmd(["git", "rev-parse", "--show-toplevel"])).resolve()
    except Exception:
        die("not inside a git repository")

    # Security confinement: must be within /Volumes/git/<current_user>
    current_user = os.environ.get("USER") or run_cmd(["id", "-un"])
    expected_root = (Path("/Volumes/git") / current_user).resolve()
    try:
        repo_root.relative_to(expected_root)
    except ValueError:
        die(f"repository {repo_root} must be within caller's workspace: {expected_root}")

    # Determine remote and branch
    remote_url = run_cmd(["git", "remote", "get-url", "origin"], cwd=repo_root)
    owner, repo = parse_repo_owner_name(remote_url)
    target = f"{owner}/{repo}"

    branch = run_cmd(["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=repo_root)
    if branch == "HEAD":
        die("cannot commit on a detached HEAD; checkout a branch first")

    expected_head_oid = run_cmd(["git", "rev-parse", "HEAD"], cwd=repo_root)

    # Inspect status for modified, added, deleted files
    status_output = run_cmd(["git", "status", "--porcelain=v1"], cwd=repo_root)
    if not status_output:
        print("[sandbox-commit] Nothing to commit, working tree clean")
        sys.exit(0)

    additions = []
    deletions = []

    for line in status_output.splitlines():
        if not line or len(line) < 4:
            continue
        status_code = line[:2]
        path_str = line[3:].strip()
        # Handle renames: R  orig -> dest
        if " -> " in path_str:
            orig_path, dest_path = path_str.split(" -> ", 1)
            orig_path = orig_path.strip().strip('"')
            dest_path = dest_path.strip().strip('"')
            deletions.append({"path": orig_path})
            file_path = repo_root / dest_path
            if file_path.is_file():
                content_b64 = base64.b64encode(file_path.read_bytes()).decode("ascii")
                additions.append({"path": dest_path, "contents": content_b64})
        else:
            clean_path = path_str.strip('"')
            file_path = repo_root / clean_path
            if "D" in status_code:
                deletions.append({"path": clean_path})
            else:
                if file_path.is_file():
                    content_b64 = base64.b64encode(file_path.read_bytes()).decode("ascii")
                    additions.append({"path": clean_path, "contents": content_b64})

    if not additions and not deletions:
        print("[sandbox-commit] No file modifications detected to commit")
        sys.exit(0)

    # Obtain ephemeral write token from OpenBao
    print(f"[sandbox-commit] Minting ephemeral GitHub write token for {target} via OpenBao...")
    token = run_cmd(["openbao-github-creds", "token", "write", target])
    if not token:
        die(f"could not obtain write token for {target} from OpenBao")

    # Build GraphQL mutation payload
    mutation = """
    mutation CreateCommit($input: CreateCommitOnBranchInput!) {
      createCommitOnBranch(input: $input) {
        commit {
          oid
          url
        }
      }
    }
    """

    variables = {
        "input": {
            "branch": {
                "repositoryNameWithOwner": target,
                "branchName": branch,
            },
            "expectedHeadOid": expected_head_oid,
            "message": {
                "headline": headline,
                "body": body,
            },
            "fileChanges": {
                "additions": additions,
                "deletions": deletions,
            },
        }
    }

    req_body = json.dumps({"query": mutation, "variables": variables}).encode("utf-8")
    req = Request(
        "https://api.github.com/graphql",
        data=req_body,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "User-Agent": "sandbox-commit/1.0",
        },
    )

    print(f"[sandbox-commit] Committing changes to {target}:{branch} via GitHub API...")
    try:
        with urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except HTTPError as e:
        err_msg = e.read().decode("utf-8")
        die(f"GitHub API HTTP error {e.code}: {err_msg}")
    except Exception as e:
        die(f"GitHub API request failed: {e}")

    if "errors" in data:
        errs = "\n".join(e.get("message", "unknown error") for e in data["errors"])
        die(f"GitHub GraphQL error:\n{errs}")

    commit_info = data.get("data", {}).get("createCommitOnBranch", {}).get("commit", {})
    new_oid = commit_info.get("oid")
    commit_url = commit_info.get("url")

    if not new_oid:
        die(f"failed to retrieve new commit OID from response: {data}")

    # Synchronize local repository with remote
    print(f"[sandbox-commit] Fast-forwarding local branch to {new_oid[:8]}...")
    subprocess.run(
        ["git", "fetch", "--quiet", "origin", branch],
        cwd=repo_root,
        check=True,
        env=dict(
            os.environ,
            GIT_CONFIG_COUNT="1",
            GIT_CONFIG_KEY_0="http.extraHeader",
            GIT_CONFIG_VALUE_0=f"Authorization: Bearer {token}",
        ),
    )
    subprocess.run(["git", "reset", "--hard", f"origin/{branch}"], cwd=repo_root, check=True)

    print(f"[sandbox-commit] Successfully committed {new_oid} on {branch} via GitHub API (Verified)!")
    if commit_url:
        print(f"[sandbox-commit] Commit URL: {commit_url}")


if __name__ == "__main__":
    main()
