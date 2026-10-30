#!/usr/bin/env python3
"""Fixed-scope PTSCPS bootstrap. Only called from the control repository workflow."""
from pathlib import Path
import argparse, json, shutil, subprocess
p=argparse.ArgumentParser()
p.add_argument("--project",choices=["astro","php","actions"],required=True)
p.add_argument("--source",type=Path,required=True)
p.add_argument("--destination",type=Path,required=True)
args=p.parse_args()
src=args.source.resolve()
dst=args.destination.resolve()
assert src.is_dir() and (src/".git").is_dir()
assert not dst.exists(), "Never overwrite destination"
shutil.copytree(src,dst,ignore=shutil.ignore_patterns(".git"),symlinks=True)
repos={"template-astro":"ptscps-astro","template-php":"ptscps-php","template-actions":"ptscps-actions"}
wp="https://admin-ptscps.thegioihosting.io.vn"
client="https://ptscps.thegioihosting.io.vn"
def rename(old,new):
    a,b=dst/old,dst/new
    assert a.is_file() and not b.exists()
    b.parent.mkdir(parents=True,exist_ok=True)
    a.rename(b)
def generic(text):
    for a,b in repos.items():
        text=text.replace("ngocnhanvo/"+a,"ngocnhanvo/"+b)
    return text
if args.project=="astro":
    f=dst/"package.json"; j=json.loads(f.read_text()); assert j["name"]=="template-astro"
    j["name"]="ptscps-astro"; f.write_text(json.dumps(j,indent=2,ensure_ascii=False)+"\n")
    f=dst/".template-config.json";j=json.loads(f.read_text());j["slug"]="ptscps-astro";f.write_text(json.dumps(j,indent=2)+"\n")
    f=dst/"ecosystem.config.cjs";s=f.read_text();assert "'template-local'" in s
    f.write_text(s.replace("'template-local'","'ptscps-astro'"))
    for n in ["AGENTS.md","README.md"]:
        f=dst/n;s=generic(f.read_text())
        f.write_text(s.replace("Template Astro","PTSCPS Astro").replace("template-astro","ptscps-astro"))
    (dst/".env.example").write_text(
        "# PTSCPS public origins. Set real secrets only on host and in GitHub Actions.\n"
        "WC_URL="+wp+"\nWC_URL_CLIENT="+client+"\n"
        "ENABLE_WOOCOMMERCE=true\nPUBLIC_ENABLE_MARKETING=false\n"
        "# CONTACT_FORM_7_ID= (supply only after verifying WP form ID)\n")
    (dst/"public/llms.txt").write_text(
        "# PTSCPS\n\n> Giới thiệu PTSCPS do WordPress quản lý; bản build được duyệt sẽ đồng bộ metadata.\n")
    assert "ptscps-astro" in (dst/"ecosystem.config.cjs").read_text()
elif args.project=="php":
    rename("template-unzip.php","ptscps-unzip.php")
    rename("template-unzip-v2.ready","ptscps-unzip-v2.ready")
    for n in ["ptscps-unzip.php","ptscps-unzip-v2.ready"]:
        f=dst/n;s=f.read_text();f.write_text(s.replace("TEMPLATE","PTSCPS").replace("Template","PTSCPS").replace("template","ptscps"))
    assert (dst/"ptscps-unzip-v2.ready").read_text().strip()=="PTSCPS_ASTRO_UNZIP_PROTOCOL=2"
    f=dst/"wp-content/mu-plugins/esc-github-trigger-config.php"
    s=f.read_text();f.write_text(s.replace("Template GitHub Trigger Config","PTSCPS GitHub Trigger Config"))
    f=dst/"wp-content/mu-plugins/esc-seo-files.php"
    s=f.read_text()
    s=s.replace("Plugin Name: PSE SEO Files","Plugin Name: PTSCPS SEO Files")
    s=s.replace("for PSE Astro","for PTSCPS Astro")
    s=s.replace("# PSE: cấu hình robots","# PTSCPS: cấu hình robots")
    a="        'llms' => "
    defaults=s.index("function esc_seo_files_defaults(): array")
    begin=s.index(a,defaults);end=s.index("\n    ];",begin)
    replacement=(
        '        \'llms\' => "# PTSCPS\\n\\n"\n'
        '            . "> Thông tin chính thức của PTSCPS.\\n\\n"\n'
        '            . "## Nội dung công khai\\n"\n'
        '            . "- [Trang chủ PTSCPS]({$site}/)\\n",'
    )
    f.write_text(s[:begin]+replacement+s[end:])
    f=dst/"README.md";s=generic(f.read_text())
    s=s.replace("Template PHP","PTSCPS PHP").replace("template-unzip","ptscps-unzip")
    f.write_text(s)
    (dst/"PTSCPS_DEPLOY_CONFIG.md").write_text(
        "# PTSCPS backend configuration\n\nWordPress: "+wp+
        "\nFrontend: "+client+
        "\nRepository: ngocnhanvo/ptscps-php (master)\n\n"
        "Configure per-server wp-config.php (never commit tokens):\n\n"
        "    define('VCS_GH_OWNER', 'ngocnhanvo');\n"
        "    define('VCS_GH_REPO', 'ptscps-actions');\n\n"
        "Keep VCS_GH_ACTIONS_TOKEN / VCS_GH_TOKEN in secured host configuration.\n"
        "ZIP endpoint: ptscps-unzip.php; readiness marker: ptscps-unzip-v2.ready.\n"
        "Build Astro only from WordPress > GitHub > Build Website.\n"
        "Use a separate WordPress database, users and integration settings.\n")
    for n in ["ptscps-unzip.php","wp-content/mu-plugins/esc-seo-files.php",
              "wp-content/plugins/github-trigger/vcs-build-trigger.php"]:
        subprocess.run(["php","-l",str(dst/n)],check=True)
elif args.project=="actions":
    files=[f for f in dst.rglob("*") if f.is_file()]
    assert len(files)>=8
    for f in files:
        s=f.read_text(encoding="utf-8")
        f.write_text(s.replace("TEMPLATE","PTSCPS").replace("Template","PTSCPS").replace("template","ptscps"),encoding="utf-8")
    for f in sorted(dst.rglob("*"),key=lambda z:len(z.parts),reverse=True):
        if f.name.startswith("template-"):
            f.rename(f.with_name("ptscps-"+f.name[len("template-"):]))
    for n in ["ptscps-production-deploy.yml","ptscps-php-release.yml","ptscps-shared-playwright.yml"]:
        assert (dst/".github/workflows"/n).is_file(),n
    for f in (dst/"scripts").glob("*.py"):
        subprocess.run(["python3","-m","py_compile",str(f)],check=True)
    assert "ngocnhanvo/ptscps-actions" in (dst/".github/workflows/ptscps-production-deploy.yml").read_text()
else:
    raise AssertionError("Unknown project")
for forbidden in [".env","wp-config.php"]:
    assert not (dst/forbidden).exists(),forbidden
count=sum(f.is_file() for f in dst.rglob("*"))
assert count>={"astro":270,"php":30000,"actions":8}[args.project],count
print("PTSCPS_BOOTSTRAP_SOURCE_PREPARED="+args.project+" FILES="+str(count))
