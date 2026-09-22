import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "update_packages", Path(__file__).with_name("update-packages.py")
)
updater = importlib.util.module_from_spec(spec)
spec.loader.exec_module(updater)


class UpdatePackagesTest(unittest.TestCase):
    def test_tag_policies(self):
        cases = {
            "isdb-scanner": (["v1.3.3", "1.3.4"], ["1.3.3"]),
            "px4_drv": (["v0.6.1", "other"], ["0.6.1"]),
            "mirakurun": (["4.1.3", "4.0.0-beta.18", "v4.2.0"], ["4.0.0-beta.18", "4.1.3"]),
            "edcb": (["work-plus-s-260904", "work-plus-260905"], ["work-plus-s-260904"]),
            "tsmemseg": (["master-with-d-260611", "master-260612"], ["master-with-d-260611"]),
        }
        for package in ("b24tovtt", "psisiarc", "psisimux", "tsreadex"):
            cases[package] = (["master-260428", "master-with-d-260429"], ["master-260428"])
        for package, (tags, expected) in cases.items():
            with self.subTest(package=package):
                refs = "\n".join(f"abc refs/tags/{tag}" for tag in tags)
                self.assertEqual(updater.matching_versions(refs, updater.SOURCES[package][1]), expected)

    def test_mirakurun_semver_order(self):
        versions = ["4.0.0-beta.18", "4.0.0", "4.0.0-beta.2", "4.1.0-beta.1"]
        self.assertEqual(sorted(versions, key=updater.semver_key), [
            "4.0.0-beta.2", "4.0.0-beta.18", "4.0.0", "4.1.0-beta.1",
        ])
        refs = "\n".join(f"abc refs/tags/{tag}" for tag in versions)
        with patch.object(updater, "output", return_value=refs):
            self.assertEqual(updater.latest_tag(*updater.SOURCES["mirakurun"][:2]), "4.1.0-beta.1")

    def test_snapshot_branches(self):
        for package, branch in (("edcb-material-webui", "E3"), ("bondriver-linux-mirakc", "HEAD"), ("recisdb", "HEAD")):
            with self.subTest(package=package):
                self.assertEqual(updater.update_command(package), ["nix-update", "--flake", package, f"--version=branch={branch}"])

    def test_build_keeps_dependency_hash_updates_enabled(self):
        with patch.object(updater, "latest_tag", return_value="4.1.3"):
            self.assertEqual(updater.update_command("mirakurun", True), ["nix-update", "--flake", "mirakurun", "--version=4.1.3", "--build"])

    def test_no_matching_tags_fails(self):
        with patch.object(updater, "output", return_value="abc refs/tags/unrelated"):
            with self.assertRaises(RuntimeError):
                updater.latest_tag("owner/repo", r"v(\d.*)")


if __name__ == "__main__":
    unittest.main()
