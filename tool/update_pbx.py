from __future__ import annotations

import re
import uuid
from pathlib import Path
from textwrap import dedent

path = Path('ios/Runner.xcodeproj/project.pbxproj')
text = path.read_text()
if 'Debug-dev.xcconfig' in text:
    raise SystemExit('Flavors already configured')


def new_id() -> str:
    return uuid.uuid4().hex[:24].upper()


def insert_after(source: str, pattern: str, addition: str) -> str:
    match = re.search(pattern, source, re.MULTILINE)
    if not match:
        raise RuntimeError(f'Pattern not found: {pattern}')
    idx = match.end()
    return source[:idx] + addition + source[idx:]


flavors = {
    'dev': {'bundle_suffix': '.dev', 'plist_suffix': 'Dev'},
    'stg': {'bundle_suffix': '.stg', 'plist_suffix': 'Stg'},
    'prod': {'bundle_suffix': '.prod', 'plist_suffix': 'Prod'},
}

xcconfig_ids = {(kind, flavor): new_id() for flavor in flavors for kind in ('debug', 'release')}
plist_ids = {flavor: new_id() for flavor in flavors}
shell_phase_id = new_id()
proj_debug_ids = {flavor: new_id() for flavor in flavors}
proj_release_ids = {flavor: new_id() for flavor in flavors}
target_debug_ids = {flavor: new_id() for flavor in flavors}
target_release_ids = {flavor: new_id() for flavor in flavors}

# PBXFileReference additions for xcconfig files
xcconfig_entries = ''.join(
    (
        f"                {xcconfig_ids['debug', flavor]} /* Debug-{flavor}.xcconfig */ = {{isa = PBXFileReference; lastKnownFileType = text.xcconfig; name = Debug-{flavor}.xcconfig; path = Flutter/Debug-{flavor}.xcconfig; sourceTree = \"<group>\"; }};\n"
        f"                {xcconfig_ids['release', flavor]} /* Release-{flavor}.xcconfig */ = {{isa = PBXFileReference; lastKnownFileType = text.xcconfig; name = Release-{flavor}.xcconfig; path = Flutter/Release-{flavor}.xcconfig; sourceTree = \"<group>\"; }};\n"
    )
    for flavor in flavors
)
text = insert_after(
    text,
    r"\s*9740EEB31CF90195004384FC /\* Generated.xcconfig \*/ = \{[^\n]*\};\n",
    xcconfig_entries,
)

# Flutter group children
flutter_children = ''.join(
    (
        f"                                {xcconfig_ids['debug', flavor]} /* Debug-{flavor}.xcconfig */,\n"
        f"                                {xcconfig_ids['release', flavor]} /* Release-{flavor}.xcconfig */,\n"
    )
    for flavor in flavors
)
text = insert_after(
    text,
    r"\s+9740EEB31CF90195004384FC /\* Generated.xcconfig \*/,\n",
    flutter_children,
)

# GoogleService file references
plist_entries = ''.join(
    f"                {plist_ids[flavor]} /* GoogleService-Info-{meta['plist_suffix']}.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; name = GoogleService-Info-{meta['plist_suffix']}.plist; path = Runner/GoogleService-Info-{meta['plist_suffix']}.plist; sourceTree = \"<group>\"; }};\n"
    for flavor, meta in flavors.items()
)
text = insert_after(
    text,
    r"\s+97C147021CF9000F007C117D /\* Info.plist \*/ = \{[^\n]*\};\n",
    plist_entries,
)

# Runner group children update
plist_children = ''.join(
    f"                                {plist_ids[flavor]} /* GoogleService-Info-{meta['plist_suffix']}.plist */,\n"
    for flavor, meta in flavors.items()
)
text = insert_after(
    text,
    r"\s+97C147021CF9000F007C117D /\* Info.plist \*/,\n",
    plist_children,
)

# Firebase config shell script
shell_block = dedent(f"""
                {shell_phase_id} /* Firebase Config */ = {{
                        isa = PBXShellScriptBuildPhase;
                        buildActionMask = 2147483647;
                        files = (
                        );
                        inputPaths = (
                                \"${{PROJECT_DIR}}/${{GOOGLE_SERVICE_INFO_PLIST}}\",
                        );
                        name = \"Firebase Config\";
                        outputPaths = (
                                \"${{BUILT_PRODUCTS_DIR}}/${{PRODUCT_NAME}}.app/GoogleService-Info.plist\",
                        );
                        runOnlyForDeploymentPostprocessing = 0;
                        shellPath = /bin/sh;
                        shellScript = \"if [ -f \\\"${{PROJECT_DIR}}/${{GOOGLE_SERVICE_INFO_PLIST}}\\\" ]; then\\n  cp \\\"${{PROJECT_DIR}}/${{GOOGLE_SERVICE_INFO_PLIST}}\\\" \\\"${{BUILT_PRODUCTS_DIR}}/${{PRODUCT_NAME}}.app/GoogleService-Info.plist\\\"\\nelse\\n  echo 'warning: GoogleService-Info file not found for ${{FLAVOR:-default}} flavor'\\nfi\";
                }};
""")
text = insert_after(
    text,
    r"/\* Begin PBXShellScriptBuildPhase section \*/\n",
    shell_block,
)

# Attach new shell phase to Runner target
phase_addition = f"                                {shell_phase_id} /* Firebase Config */,\n"
text = insert_after(
    text,
    r"\s+buildPhases = \(\n\s+9740EEB61CF901F6004384FC /\* Run Script \*/,\n",
    phase_addition,
)

# Prepare configuration templates
proj_debug_template = re.search(r"^\s+97C147031CF9000F007C117D /\* Debug \*/ = \{[\s\S]*?^\s+\};", text, re.MULTILINE).group(0)
proj_release_template = re.search(r"^\s+97C147041CF9000F007C117D /\* Release \*/ = \{[\s\S]*?^\s+\};", text, re.MULTILINE).group(0)
target_debug_template = re.search(r"^\s+97C147061CF9000F007C117D /\* Debug \*/ = \{[\s\S]*?^\s+\};", text, re.MULTILINE).group(0)
target_release_template = re.search(r"^\s+97C147071CF9000F007C117D /\* Release \*/ = \{[\s\S]*?^\s+\};", text, re.MULTILINE).group(0)

proj_config_blocks = []
target_config_blocks = []
for flavor, meta in flavors.items():
    debug_block = proj_debug_template.replace('97C147031CF9000F007C117D /* Debug */', f"{proj_debug_ids[flavor]} /* Debug-{flavor} */", 1)
    debug_block = debug_block.replace('name = Debug;', f'name = Debug-{flavor};')
    proj_config_blocks.append('\n' + debug_block)

    release_block = proj_release_template.replace('97C147041CF9000F007C117D /* Release */', f"{proj_release_ids[flavor]} /* Release-{flavor} */", 1)
    release_block = release_block.replace('name = Release;', f'name = Release-{flavor};')
    proj_config_blocks.append('\n' + release_block)

    target_debug_block = target_debug_template.replace('97C147061CF9000F007C117D /* Debug */', f"{target_debug_ids[flavor]} /* Debug-{flavor} */", 1)
    target_debug_block = target_debug_block.replace('baseConfigurationReference = 9740EEB21CF90195004384FC /* Debug.xcconfig */;', f"baseConfigurationReference = {xcconfig_ids['debug', flavor]} /* Debug-{flavor}.xcconfig */;")
    target_debug_block = target_debug_block.replace('name = Debug;', f'name = Debug-{flavor};')
    target_debug_block = target_debug_block.replace('PRODUCT_BUNDLE_IDENTIFIER = com.example.restaurantAppFinal;', f"PRODUCT_BUNDLE_IDENTIFIER = com.example.restaurantAppFinal{meta['bundle_suffix']};")
    target_config_blocks.append('\n' + target_debug_block)

    target_release_block = target_release_template.replace('97C147071CF9000F007C117D /* Release */', f"{target_release_ids[flavor]} /* Release-{flavor} */", 1)
    target_release_block = target_release_block.replace('baseConfigurationReference = 7AFA3C8E1D35360C0083082E /* Release.xcconfig */;', f"baseConfigurationReference = {xcconfig_ids['release', flavor]} /* Release-{flavor}.xcconfig */;")
    target_release_block = target_release_block.replace('name = Release;', f'name = Release-{flavor};')
    target_release_block = target_release_block.replace('PRODUCT_BUNDLE_IDENTIFIER = com.example.restaurantAppFinal;', f"PRODUCT_BUNDLE_IDENTIFIER = com.example.restaurantAppFinal{meta['bundle_suffix']};")
    target_config_blocks.append('\n' + target_release_block)

# Insert new configuration blocks before end of XCBuildConfiguration section
text = text.replace('/* End XCBuildConfiguration section */', ''.join(proj_config_blocks + target_config_blocks) + '\n/* End XCBuildConfiguration section */', 1)

# Update configuration lists
proj_debug_lines = ''.join(f"                                {proj_debug_ids[flavor]} /* Debug-{flavor} */\n" for flavor in flavors)
proj_release_lines = ''.join(f"                                {proj_release_ids[flavor]} /* Release-{flavor} */\n" for flavor in flavors)
target_debug_lines = ''.join(f"                                {target_debug_ids[flavor]} /* Debug-{flavor} */\n" for flavor in flavors)
target_release_lines = ''.join(f"                                {target_release_ids[flavor]} /* Release-{flavor} */\n" for flavor in flavors)
text = text.replace(
    '                                97C147031CF9000F007C117D /* Debug */\n',
    '                                97C147031CF9000F007C117D /* Debug */\n' + proj_debug_lines,
    1,
)
text = text.replace(
    '                                97C147041CF9000F007C117D /* Release */\n',
    '                                97C147041CF9000F007C117D /* Release */\n' + proj_release_lines,
    1,
)
text = text.replace(
    '                                97C147061CF9000F007C117D /* Debug */\n',
    '                                97C147061CF9000F007C117D /* Debug */\n' + target_debug_lines,
    1,
)
text = text.replace(
    '                                97C147071CF9000F007C117D /* Release */\n',
    '                                97C147071CF9000F007C117D /* Release */\n' + target_release_lines,
    1,
)

path.write_text(text)
