from ape import project
from ethpm_types import PackageManifest
from pathlib import Path


def main():
    manifest = project.extract_manifest().dict(
        include={
            "manifest": True,
            "contract_types": {
                "LlamaPayFactory": {"name", "abi", "userdoc", "devdoc"},
                "LlamaPay": {"name", "abi", "userdoc", "devdoc"},
            },
            "deployments": True,
        }
    )
    manifest = PackageManifest.parse_obj(manifest).json()
    Path("manifest.json").write_text(manifest)
    print("written to manifest.json")
