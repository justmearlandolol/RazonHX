#!/usr/bin/env python3
"""Regenerate the checked-in Xcode project without third-party generators."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
objects = {}
def uid(name):
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()
def obj(name, kind, fields):
    key = uid(name)
    objects[key] = '{ isa = ' + kind + '; ' + fields + ' };'
    return key

def quote(value):
    return json.dumps(str(value))
def array(values):
    return '(' + ', '.join(values) + (',' if values else '') + ')'
def settings(values):
    return '{ ' + ' '.join(k + ' = ' + (array([quote(i) for i in v]) if isinstance(v, list) else quote(v)) + ';' for k, v in values.items()) + ' }'
def configs(name, values):
    refs = []
    for mode in ['Debug', 'Release']:
        merged = dict(values)
        merged['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone' if mode == 'Debug' else '-O'
        refs.append(obj(name + mode, 'XCBuildConfiguration', f'name = {mode}; buildSettings = {settings(merged)};'))
    return obj(name + 'Configs', 'XCConfigurationList', f'buildConfigurations = {array(refs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')

sources = []
for path in sorted((ROOT / 'Sources').rglob('*.swift')):
    relative = str(path.relative_to(ROOT))
    sources.append(obj(relative, 'PBXFileReference', f'lastKnownFileType = sourcecode.swift; path = {quote(relative)}; sourceTree = "<group>";'))
resources = []
for path in ['Resources/Logo', 'Resources/Icons/RazonHX.icns', 'Config/default.json']:
    kind = 'folder' if path.endswith('Logo') else ('image.icns' if path.endswith('icns') else 'text.json')
    resources.append(obj(path, 'PBXFileReference', f'lastKnownFileType = {kind}; path = {quote(path)}; sourceTree = "<group>";'))
extra = []
for path, kind in [('Sources/Bridge/RazonHXBridge.h', 'sourcecode.c.h'), ('Sources/App/Info.plist', 'text.plist.xml')]:
    extra.append(obj(path, 'PBXFileReference', f'lastKnownFileType = {kind}; path = {quote(path)}; sourceTree = "<group>";'))
products = []
targets = []
for arch, rust, minimum, label in [('x86_64', 'x86_64-apple-darwin', '10.13', 'Intel'), ('arm64', 'aarch64-apple-darwin', '11.0', 'AppleSilicon')]:
    name = 'RazonHX-' + label
    product = obj(name + 'Product', 'PBXFileReference', 'explicitFileType = wrapper.application; includeInIndex = 0; path = RazonHX.app; sourceTree = BUILT_PRODUCTS_DIR;')
    products.append(product)
    script = obj(name + 'Rust', 'PBXShellScriptBuildPhase', 'buildActionMask = 2147483647; files = (); inputPaths = (); outputPaths = (); runOnlyForDeploymentPostprocessing = 0; alwaysOutOfDate = 1; name = "Build Rust core"; shellPath = /bin/bash; shellScript = "bash \\\"$SRCROOT/scripts/build-rust.sh\\\"";'.replace('\\\"', '\\"'))
    phases = [script]
    for suffix, kind, refs in [('Sources', 'PBXSourcesBuildPhase', sources), ('Resources', 'PBXResourcesBuildPhase', resources)]:
        builds = [obj(name + suffix + ref, 'PBXBuildFile', f'fileRef = {ref};') for ref in refs]
        phases.append(obj(name + suffix, kind, f'buildActionMask = 2147483647; files = {array(builds)}; runOnlyForDeploymentPostprocessing = 0;'))
    phases.append(obj(name + 'Frameworks', 'PBXFrameworksBuildPhase', 'buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;'))
    build = configs(name, {
        'PRODUCT_NAME': 'RazonHX', 'PRODUCT_BUNDLE_IDENTIFIER': 'com.razonhx.desktop',
        'INFOPLIST_FILE': 'Sources/App/Info.plist', 'SWIFT_VERSION': '5.0',
        'SDKROOT': 'macosx', 'ARCHS': arch, 'ONLY_ACTIVE_ARCH': 'NO',
        'MACOSX_DEPLOYMENT_TARGET': minimum, 'RAZON_RUST_TARGET': rust,
        'CODE_SIGNING_ALLOWED': 'NO', 'ENABLE_HARDENED_RUNTIME': 'YES',
        'ENABLE_USER_SCRIPT_SANDBOXING': 'NO', 'SWIFT_STRICT_CONCURRENCY': 'minimal',
        'SWIFT_OBJC_BRIDGING_HEADER': 'Sources/Bridge/RazonHXBridge.h',
        'LIBRARY_SEARCH_PATHS': ['$(inherited)', '$(SRCROOT)/razon-core/target/$(RAZON_RUST_TARGET)/release'],
        'OTHER_LDFLAGS': ['$(inherited)', '-lrazon_core', '-liconv', '-framework', 'Security', '-framework', 'SystemConfiguration'],
        'LD_RUNPATH_SEARCH_PATHS': ['$(inherited)', '@executable_path/../Frameworks'],
        'CLANG_ENABLE_MODULES': 'YES', 'SWIFT_EMIT_LOC_STRINGS': 'NO',
        'COMBINE_HIDPI_IMAGES': 'YES', 'DEBUG_INFORMATION_FORMAT': 'dwarf-with-dsym',
    })
    target = obj(name, 'PBXNativeTarget', f'buildConfigurationList = {build}; buildPhases = {array(phases)}; buildRules = (); dependencies = (); name = {quote(name)}; productName = RazonHX; productReference = {product}; productType = "com.apple.product-type.application";')
    targets.append(target)
    scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1640" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="RazonHX.app" BlueprintName="{name}" ReferencedContainer="container:RazonHX.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="RazonHX.app" BlueprintName="{name}" ReferencedContainer="container:RazonHX.xcodeproj"/></BuildableProductRunnable></LaunchAction>
 <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
    (ROOT / f'RazonHX.xcodeproj/xcshareddata/xcschemes/{name}.xcscheme').write_text(scheme)
products_group = obj('Products', 'PBXGroup', f'children = {array(products)}; name = Products; sourceTree = "<group>";')
source_group = obj('Native Sources', 'PBXGroup', f'children = {array(sources + extra)}; name = "Native Sources"; sourceTree = "<group>";')
resource_group = obj('Resources', 'PBXGroup', f'children = {array(resources)}; name = Resources; sourceTree = "<group>";')
main = obj('Main', 'PBXGroup', f'children = {array([source_group, resource_group, products_group])}; sourceTree = "<group>";')
project_configs = configs('Project', {'CLANG_WARN_UNGUARDED_AVAILABILITY': 'YES_AGGRESSIVE', 'GCC_C_LANGUAGE_STANDARD': 'gnu11'})
project = obj('Project', 'PBXProject', f'attributes = {{ LastUpgradeCheck = 1640; }}; buildConfigurationList = {project_configs}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {main}; productRefGroup = {products_group}; projectDirPath = ""; projectRoot = ""; targets = {array(targets)};')
(ROOT / 'RazonHX.xcodeproj/project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n' + '\n'.join(k + ' = ' + v for k, v in objects.items()) + '\n}; rootObject = ' + project + '; }\n')
