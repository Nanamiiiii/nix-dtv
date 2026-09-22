"""Select upstream tags/branches and delegate package and dependency hashes to nix-update."""

import argparse
import json
from pathlib import Path
import re
import shlex
import subprocess


# Package attribute: (GitHub repository, tag pattern, branch).
# None for a branch means the remote's default branch (HEAD).
SOURCES = {
    "isdb-scanner": ("tsukumijima/ISDBScanner", r"v(\d.*)", None),
    "mirakurun": ("Chinachu/Mirakurun", r"(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)", None),
    "px4_drv": ("tsukumijima/px4_drv", r"v(\d.*)", None),
    "edcb": ("xtne6f/EDCB", r"(work-plus-s-\d+)", None),
    "edcb-material-webui": ("EMWUI/EDCB_Material_WebUI", None, "E3"),
    "bondriver-linux-mirakc": ("matching/BonDriver_LinuxMirakc", None, None),
    "recisdb": ("kazuki0824/recisdb-rs", None, None),
    "b24tovtt": ("xtne6f/b24tovtt", r"(master-\d+)", None),
    "psisiarc": ("xtne6f/psisiarc", r"(master-\d+)", None),
    "psisimux": ("xtne6f/psisimux", r"(master-\d+)", None),
    "tsreadex": ("xtne6f/tsreadex", r"(master-\d+)", None),
    "tsmemseg": ("xtne6f/tsmemseg", r"(master-with-d-\d+)", None),
}


def output(*args):
    return subprocess.check_output(args, text=True).strip()


def matching_versions(refs, pattern):
    versions = set()
    for line in refs.splitlines():
        _, ref = line.split()
        match = re.fullmatch(pattern, ref.removeprefix("refs/tags/"))
        if match:
            versions.add(match.group(1))
    return sorted(versions)


def semver_key(version):
    core, separator, prerelease = version.partition("-")
    identifiers = tuple(
        (0, int(part)) if part.isdigit() else (1, part)
        for part in prerelease.split(".")
    )
    return tuple(map(int, core.split("."))), not separator, identifiers


def latest_tag(repository, pattern):
    refs = output("git", "ls-remote", "--tags", "--refs", f"https://github.com/{repository}.git")
    versions = matching_versions(refs, pattern)
    if not versions:
        raise RuntimeError(f"No tags matching {pattern!r} in {repository}")
    if repository == "Chinachu/Mirakurun":
        # Nix and Git version sorting can place -beta after the same stable
        # version. Mirakurun uses SemVer precedence instead.
        return max(versions, key=semver_key)
    # Numeric comparison handles date tags and multi-digit version components.
    return json.loads(output(
        "nix", "eval", "--json", "--expr",
        "let versions = builtins.fromJSON " + json.dumps(json.dumps(versions)) + "; "
        "in builtins.head (builtins.sort (a: b: builtins.compareVersions a b > 0) versions)",
    ))


def update_command(package, build=False):
    repository, pattern, branch = SOURCES[package]
    if pattern is not None:
        version = latest_tag(repository, pattern)
    else:
        version = f"branch={branch or 'HEAD'}"
    command = ["nix-update", "--flake", package, f"--version={version}"]
    if build:
        command.append("--build")
    return command


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("packages", nargs="*", help="Package attributes (default: all)")
    parser.add_argument("--build", action="store_true", help="Build each updated package")
    parser.add_argument("--dry-run", action="store_true", help="Resolve tags and print commands without editing files")
    args = parser.parse_args()
    packages = args.packages or list(SOURCES)
    unknown = sorted(set(packages) - SOURCES.keys())
    if unknown:
        parser.error("Unknown packages: " + ", ".join(unknown))
    if not Path("pkgs/default.nix").is_file() or not Path("flake.nix").is_file():
        parser.error("Run from the nix-dtv repository root")
    for package in packages:
        command = update_command(package, args.build)
        print(shlex.join(command), flush=True)
        if not args.dry_run:
            subprocess.run(command, check=True)
            if package == "edcb-material-webui":
                # There are no E3 releases for nix-update to infer the major
                # version from; retain the existing E3 version convention.
                path = Path("pkgs/edcb-material-webui/default.nix")
                text = path.read_text()
                text, count = re.subn(
                    r'version = "[^"\n]*-unstable-(\d{4}-\d{2}-\d{2})";',
                    r'version = "3-unstable-\1";',
                    text,
                )
                if count != 1:
                    raise RuntimeError("Unexpected E3 snapshot version format")
                path.write_text(text)


if __name__ == "__main__":
    main()
