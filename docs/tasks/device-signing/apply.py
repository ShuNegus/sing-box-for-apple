#!/usr/bin/env python3
"""Device-signing rename: io.nekohasekai.sfavt -> su.smd.sing-box, team 7G6756ME5J."""
import re, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
os.chdir(ROOT)

OLD_ID = "io.nekohasekai.sfavt"
NEW_ID = "su.smd.sing-box"
OLD_TEAM = "287TTNZF8L"
NEW_TEAM = "7G6756ME5J"

def rw(path, fn):
    with open(path, "r", encoding="utf-8") as f:
        s = f.read()
    s2 = fn(s)
    if s2 != s:
        with open(path, "w", encoding="utf-8") as f:
            f.write(s2)
        print(f"  updated {path}")
    else:
        print(f"  (no change) {path}")

# --- pbxproj ---
PBX = "sing-box.xcodeproj/project.pbxproj"
def fix_pbx(s):
    n0 = s.count(os.linesep)  # not used; keep line count check below
    s = s.replace(OLD_TEAM, NEW_TEAM)
    s = s.replace(OLD_ID, NEW_ID)
    s = s.replace('DEVELOPMENT_TEAM = "";', f'DEVELOPMENT_TEAM = {NEW_TEAM};')
    # Quote any not-yet-quoted assignment value that now contains the hyphenated new id.
    # (?!") => char right after "= " is not a quote (i.e. value not already quoted).
    s = re.sub(r'= (?!")([^\n;]*su\.smd\.sing-box[^\n;]*);',
               lambda m: f'= "{m.group(1)}";', s)
    return s
print("pbxproj:")
before_lines = open(PBX).read().count("\n")
rw(PBX, fix_pbx)
after_lines = open(PBX).read().count("\n")
assert before_lines == after_lines, f"line count changed {before_lines}->{after_lines}!"

# CODE_SIGN_STYLE Manual->Automatic ONLY for .system and .standalone blocks.
# Done by locating each config block via its PRODUCT_BUNDLE_IDENTIFIER.
def fix_sign_style(s):
    lines = s.split("\n")
    # find blocks: an XCBuildConfiguration block is delimited by '{' ... '};'
    # Simpler: for each line with the target bundle id, walk backwards to its CODE_SIGN_STYLE within the same block.
    targets = ('su.smd.sing-box.system;', 'su.smd.sing-box.standalone;',
               '"su.smd.sing-box.system"', '"su.smd.sing-box.standalone"')
    changed = 0
    for i, ln in enumerate(lines):
        if "PRODUCT_BUNDLE_IDENTIFIER" in ln and any(t in ln for t in targets):
            # walk backward to nearest CODE_SIGN_STYLE = Manual; stop at block start '{'
            for j in range(i, max(i-60, -1), -1):
                if "isa = XCBuildConfiguration" in lines[j]:
                    break
                if "CODE_SIGN_STYLE = Manual;" in lines[j]:
                    lines[j] = lines[j].replace("Manual", "Automatic")
                    changed += 1
                    break
    print(f"  sign-style Manual->Automatic: {changed} blocks")
    return "\n".join(lines)
rw(PBX, fix_sign_style)

# --- entitlements (all 9) ---
ENT = [
    "Extension/Extension.entitlements",
    "FileProviderExtension/FileProviderExtension.entitlements",
    "WidgetExtension/WidgetExtension.entitlements",
    "IntentsExtension/IntentsExtension.entitlements",
    "SFI/SFI.entitlements",
    "SFM/SFM.entitlements",
    "SFM.System/SFM.entitlements",
    "SFT/SFT.entitlements",
    "TVExtension/TVExtension.entitlements",
]
print("entitlements:")
for p in ENT:
    rw(p, lambda s: s.replace(OLD_ID, NEW_ID))

# remove multicast key+value from Extension.entitlements only
def drop_multicast(s):
    return re.sub(
        r'\n\t<key>com\.apple\.developer\.networking\.multicast</key>\n\t<true/>',
        "", s)
print("multicast removal (Extension only):")
rw("Extension/Extension.entitlements", drop_multicast)

# --- helper plist content (rename of file handled by git mv outside) ---
HELPER = "HelperService/LaunchDaemons/io.nekohasekai.sfavt.helper.plist"
if os.path.exists(HELPER):
    print("helper plist content:")
    rw(HELPER, lambda s: s.replace(OLD_TEAM, NEW_TEAM).replace(OLD_ID, NEW_ID))

# --- SnapshotHelper ---
print("SnapshotHelper:")
rw("SFMUITests/SnapshotHelper.swift", lambda s: s.replace(OLD_ID, NEW_ID))

print("DONE")
