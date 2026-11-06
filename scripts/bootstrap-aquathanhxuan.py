#!/usr/bin/env python3
"""Fixed-scope Aqua Thanh Xuan bootstrap from approved template repositories."""
from pathlib import Path
import argparse
import ast
import json
import shutil
import subprocess

p = argparse.ArgumentParser()
p.add_argument("--project", choices=["astro", "php", "actions"], required=True)
p.add_argument("--source", type=Path, required=True)
p.add_argument("--destination", type=Path, required=True)
args = p.parse_args()

src = args.source.resolve()
dst = args.destination.resolve()
assert src.is_dir() and (src / ".git").is_dir()
assert not dst.exists(), "Never overwrite destination"

shutil.copytree(src, dst, ignore=shutil.ignore_patterns(".git"), symlinks=True)

repos = {
    "template-astro": "aquathanhxuan-astro",
    "template-php": "aquathanhxuan-php",
    "template-actions": "aquathanhxuan-actions",
}
wp = "https://admin-aquathanhxuan.io.vn"
client = "https://aquathanhxuan.io.vn"
brand = "Aqua Thanh Xuân"

def rename(old: str, new: str) -> None:
    a, b = dst / old, dst / new
    assert a.is_file() and not b.exists(), (old, new)
    b.parent.mkdir(parents=True, exist_ok=True)
    a.rename(b)

def replace_repo_names(text: str) -> str:
    for old, new in repos.items():
        text = text.replace("ngocnhanvo/" + old, "ngocnhanvo/" + new)
    return text

def replace_project_tokens(text: str) -> str:
    text = replace_repo_names(text)
    text = text.replace("TEMPLATE_", "AQUATHANHXUAN_")
    text = text.replace(".template-", ".aquathanhxuan-")
    text = text.replace("template-staging-build.json", "aquathanhxuan-staging-build.json")
    return text

if args.project == "astro":
    # Update exact project identities without changing generic programming uses
    # of the word "template".
    for f in dst.rglob("*"):
        if not f.is_file():
            continue
        try:
            raw = f.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        updated = replace_project_tokens(raw)
        if updated != raw:
            f.write_text(updated, encoding="utf-8")

    f = dst / "package.json"
    j = json.loads(f.read_text(encoding="utf-8"))
    assert j["name"] == "template-astro"
    j["name"] = "aquathanhxuan-astro"
    f.write_text(json.dumps(j, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    f = dst / ".template-config.json"
    j = json.loads(f.read_text(encoding="utf-8"))
    j["slug"] = "aquathanhxuan-astro"
    f.write_text(json.dumps(j, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    f = dst / "ecosystem.config.cjs"
    s = f.read_text(encoding="utf-8")
    assert "'template-local'" in s
    f.write_text(s.replace("'template-local'", "'aquathanhxuan-astro'"), encoding="utf-8")

    f = dst / "AGENTS.md"
    s = f.read_text(encoding="utf-8")
    s = s.replace("# AGENTS.md — Template", "# AGENTS.md — Aqua Thanh Xuân")
    s = s.replace(
        "Exact repository scope: `ngocnhanvo/aquathanhxuan-astro` (`github` = Development/Test, `master` = Production), "
        "`ngocnhanvo/aquathanhxuan-php` (`master`), `ngocnhanvo/aquathanhxuan-actions` (`main`).",
        "Exact repository scope: `ngocnhanvo/aquathanhxuan-astro` (`master` = production/source branch), "
        "`ngocnhanvo/aquathanhxuan-php` (`master`), `ngocnhanvo/aquathanhxuan-actions` (`main`)."
    )
    f.write_text(s, encoding="utf-8")

    f = dst / "README.md"
    s = f.read_text(encoding="utf-8")
    s = s.replace("# Template Astro", "# Aqua Thanh Xuân Astro")
    s = s.replace(
        "Repository: `ngocnhanvo/aquathanhxuan-astro`. `github` = development/test; `master` = production source.",
        "Repository: `ngocnhanvo/aquathanhxuan-astro`. `master` is the production/source branch."
    )
    f.write_text(s, encoding="utf-8")

    (dst / ".env.example").write_text(
        "# Aqua Thanh Xuan public origins. Set real secrets only on host and in GitHub Actions.\n"
        "WC_URL=" + wp + "\n"
        "WC_URL_CLIENT=" + client + "\n"
        "ENABLE_WOOCOMMERCE=true\n"
        "PUBLIC_ENABLE_MARKETING=false\n"
        "# CONTACT_FORM_7_ID= (supply only after verifying WP form ID)\n",
        encoding="utf-8",
    )
    (dst / "public/llms.txt").write_text(
        "# Aqua Thanh Xuân\n\n"
        "> Nội dung chính thức của Aqua Thanh Xuân do WordPress quản lý và được đồng bộ khi phát hành.\n",
        encoding="utf-8",
    )

    assert "aquathanhxuan-astro" in (dst / "ecosystem.config.cjs").read_text(encoding="utf-8")
    assert "ngocnhanvo/template-" not in (dst / "README.md").read_text(encoding="utf-8")
    assert "github` = development/test" not in (dst / "README.md").read_text(encoding="utf-8")

elif args.project == "php":
    # Rename the deployment contract files that are coupled to Actions.
    rename("template-image-delta.php", "aquathanhxuan-image-delta.php")
    rename("template-unzip.php", "aquathanhxuan-unzip.php")
    rename("template-unzip-v2.ready", "aquathanhxuan-unzip-v2.ready")
    rename("tests/template-image-delta.php", "tests/aquathanhxuan-image-delta.php")
    rename("tests/template-static-delta.php", "tests/aquathanhxuan-static-delta.php")

    for name in [
        "aquathanhxuan-image-delta.php",
        "aquathanhxuan-unzip.php",
        "aquathanhxuan-unzip-v2.ready",
        "tests/aquathanhxuan-image-delta.php",
        "tests/aquathanhxuan-static-delta.php",
    ]:
        f = dst / name
        s = f.read_text(encoding="utf-8")
        s = s.replace("TEMPLATE", "AQUATHANHXUAN")
        s = s.replace("Template", brand)
        s = s.replace("template", "aquathanhxuan")
        f.write_text(s, encoding="utf-8")

    assert (dst / "aquathanhxuan-unzip-v2.ready").read_text(encoding="utf-8").strip() == "AQUATHANHXUAN_ASTRO_UNZIP_PROTOCOL=2"

    f = dst / "wp-content/mu-plugins/esc-github-trigger-config.php"
    s = f.read_text(encoding="utf-8")
    f.write_text(s.replace("Template GitHub Trigger Config", "Aqua Thanh Xuân GitHub Trigger Config"), encoding="utf-8")

    f = dst / "wp-content/mu-plugins/esc-seo-files.php"
    s = f.read_text(encoding="utf-8")
    s = s.replace("Plugin Name: PSE SEO Files", "Plugin Name: Aqua Thanh Xuân SEO Files")
    s = s.replace("for PSE Astro", "for Aqua Thanh Xuân Astro")
    s = s.replace("# PSE:", "# Aqua Thanh Xuân:")
    s = s.replace("# PSE\\n\\n", "# Aqua Thanh Xuân\\n\\n")
    s = s.replace("> Nhật ký nghiên cứu khoa học dành cho học sinh và giáo viên.\\n\\n",
                  "> Thông tin chính thức của Aqua Thanh Xuân.\\n\\n")
    s = s.replace("- [Trang chủ PSE]({$site}/)\\n", "- [Trang chủ Aqua Thanh Xuân]({$site}/)\\n")
    s = s.replace('            . "- [Sổ tay NCKH — yêu cầu đăng nhập]({$site}/so-tay)\\n",\n', "")
    s = s.replace("Trên EduResearch staging,", "Trên website hiện tại,")
    s = s.replace("EduResearch", "Aqua Thanh Xuân")
    f.write_text(s, encoding="utf-8")

    f = dst / "README.md"
    s = replace_repo_names(f.read_text(encoding="utf-8"))
    s = s.replace("# Template PHP", "# Aqua Thanh Xuân PHP")
    s = s.replace("'template-actions'", "'aquathanhxuan-actions'")
    s = s.replace("template-unzip", "aquathanhxuan-unzip")
    s = s.replace("template-image-delta", "aquathanhxuan-image-delta")
    s = s.replace("template-static-delta", "aquathanhxuan-static-delta")
    f.write_text(s, encoding="utf-8")

    (dst / "AQUATHANHXUAN_DEPLOY_CONFIG.md").write_text(
        "# Aqua Thanh Xuân backend configuration\n\n"
        "WordPress: " + wp + "\n"
        "Frontend: " + client + "\n"
        "Repository: ngocnhanvo/aquathanhxuan-php (master)\n\n"
        "Configure per-server wp-config.php (never commit tokens):\n\n"
        "    define('VCS_GH_OWNER', 'ngocnhanvo');\n"
        "    define('VCS_GH_REPO', 'aquathanhxuan-actions');\n\n"
        "Keep VCS_GH_ACTIONS_TOKEN / VCS_GH_TOKEN in secured host configuration.\n"
        "ZIP endpoint: aquathanhxuan-unzip.php; readiness marker: aquathanhxuan-unzip-v2.ready.\n"
        "Build Astro only from WordPress > GitHub > Build Website.\n"
        "Use a separate WordPress database, users and integration settings.\n",
        encoding="utf-8",
    )

    for name in [
        "aquathanhxuan-image-delta.php",
        "aquathanhxuan-unzip.php",
        "tests/aquathanhxuan-image-delta.php",
        "tests/aquathanhxuan-static-delta.php",
        "wp-content/mu-plugins/esc-seo-files.php",
        "wp-content/plugins/github-trigger/vcs-build-trigger.php",
    ]:
        subprocess.run(["php", "-l", str(dst / name)], check=True)

    subprocess.run(["php", str(dst / "tests/aquathanhxuan-image-delta.php")], check=True)
    subprocess.run(["php", str(dst / "tests/aquathanhxuan-static-delta.php")], check=True)

    seo = (dst / "wp-content/mu-plugins/esc-seo-files.php").read_text(encoding="utf-8")
    assert "Nhật ký nghiên cứu khoa học" not in seo
    assert "Sổ tay NCKH" not in seo
    assert "EduResearch" not in seo

elif args.project == "actions":
    files = [f for f in dst.rglob("*") if f.is_file()]
    assert len(files) >= 8

    for f in files:
        s = f.read_text(encoding="utf-8")
        s = s.replace("TEMPLATE", "AQUATHANHXUAN")
        s = s.replace("Template", brand)
        s = s.replace("template", "aquathanhxuan")
        f.write_text(s, encoding="utf-8")

    for f in sorted(dst.rglob("*"), key=lambda z: len(z.parts), reverse=True):
        if f.name.startswith("template-"):
            f.rename(f.with_name("aquathanhxuan-" + f.name[len("template-"):]))

    readme = dst / "README.md"
    s = readme.read_text(encoding="utf-8")
    s = s.replace(
        "- Astro development/testing: `ngocnhanvo/aquathanhxuan-astro` → `github`.\n"
        "- Astro production source: `ngocnhanvo/aquathanhxuan-astro` → `master`.",
        "- Astro source/production: `ngocnhanvo/aquathanhxuan-astro` → `master`."
    )
    readme.write_text(s, encoding="utf-8")

    for name in [
        "aquathanhxuan-production-deploy.yml",
        "aquathanhxuan-php-release.yml",
        "aquathanhxuan-shared-playwright.yml",
    ]:
        assert (dst / ".github/workflows" / name).is_file(), name

    for f in (dst / "scripts").glob("*.py"):
        ast.parse(f.read_text(encoding="utf-8"), filename=str(f))

    deploy = (dst / ".github/workflows/aquathanhxuan-production-deploy.yml").read_text(encoding="utf-8")
    assert "ngocnhanvo/aquathanhxuan-actions" in deploy
    assert "ngocnhanvo/aquathanhxuan-astro" in deploy
    assert "refs/heads/main" in deploy
    assert "ref: master" in deploy
    assert "AQUATHANHXUAN_" in deploy

    release = (dst / ".github/workflows/aquathanhxuan-php-release.yml").read_text(encoding="utf-8")
    assert "source-php/aquathanhxuan-image-delta.php" in release
    assert "source-php/aquathanhxuan-unzip.php" in release
    assert "tests/aquathanhxuan-image-delta.php" in release
    assert "tests/aquathanhxuan-static-delta.php" in release

else:
    raise AssertionError("Unknown project")

for forbidden in [".env", "wp-config.php"]:
    assert not (dst / forbidden).exists(), forbidden

count = sum(f.is_file() for f in dst.rglob("*"))
assert count >= {"astro": 270, "php": 30000, "actions": 8}[args.project], count
print("AQUATHANHXUAN_BOOTSTRAP_SOURCE_PREPARED=" + args.project + " FILES=" + str(count))
