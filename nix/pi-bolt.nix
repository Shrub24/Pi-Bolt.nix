# Pi-Bolt, with the plugins a Nix expression chooses compiled in.
#
#   pi-bolt                                     this source, compiled for this system
#   pi-bolt.withPlugins (ps: [ ps.word-count ]) with plugins compiled in (from piBoltPlugins, or built anywhere)
#   pi-bolt.override { jit = true; }            the JIT build (docs/PLUGINS.md: for extensions loaded at run time)
#
# The executable is made by scripts/build-pi.sh in the source's own tree, from the workspace (nix/workspace.nix: Pi's
# build) and the runtime that nix/runtime.json names. The compiled executable is `unwrapped`; this package is a copy of it
# with a launcher that sets PATH, so a launcher change does not compile again, and the launcher and the executable it runs
# are in one store path (process.execPath is where Pi-Bolt finds its assets).
args@{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  callPackage,
  python3,
  rsync,
  patchelf,
  autoPatchelfHook,
  makeBinaryWrapper,
  writeText,
  libxcb,
  ripgrep,
  fd,
  # The release whose version selects the runtime (nix/runtime.json) and whose tag names it.
  release,
  # What gets compiled. By default the release's source; override it to build another source with the same engine.
  source,
  piBoltPlugins,

  # Plugins to compile in: buildPiBoltPlugin derivations. Each is a built-in extension, builtin:<name>.
  plugins ? [ ],
  # The JIT build: compiled code as always, and run-time loaded extensions JIT-compiled too.
  jit ? false,
  # The largest module (top-level bytecode, in bytes) the AOT compiler takes. The compiler names the module it refused; raise
  # this for it (docs/PLUGINS.md, "A large module").
  maxAotCandidateBytecodeSize ? null,
  # Programs Pi finds in PATH rather than downloading: rg and fd for its grep and find tools. Add wl-clipboard or xclip for
  # the clipboard.
  runtimeInputs ? [
    ripgrep
    fd
  ],
}:
stdenvNoCC.mkDerivation (
  finalAttrs:
  let
    releaseVersion = lib.removeSuffix "\n" (builtins.readFile "${release.outPath}/VERSION");
    runtimes = lib.importJSON ./runtime.json;
    runtimePin =
      runtimes.${releaseVersion} or (throw "pi-bolt: no runtime recorded for release ${releaseVersion}: add it to nix/runtime.json");
    system = stdenv.hostPlatform.system;
    pin =
      runtimePin.platforms.${system} or (throw "pi-bolt: no Nix build for ${system} yet");
    runtime = fetchurl {
      url = "https://github.com/opensec-git/Pi-Bolt/releases/download/bolt-v${releaseVersion}/${pin.name}";
      inherit (pin) sha256;
    };

    sources = callPackage ./source.nix { inherit source; };

    # The version of the source compiled. The derivations that make the executable are named by it alone, so that a commit which
    # changes no build input leaves their store paths, and the caches that hold them, as they were.
    version = lib.removeSuffix "\n" (builtins.readFile "${source.outPath}/VERSION");
    # The launcher alone also names the source's revision, so that a build from a branch is not labelled as the release.
    label = "${version}-${source.shortRev or "dirty"}";

    workspace = callPackage ./workspace.nix {
      src = sources.workspace;
      inherit version;
    };

    # As the release names them (scripts/build-pi.sh, CPU_VARIANT). Every build here is the baseline one: code tuned for its
    # builder's CPU could not be shared or substituted, and the derivation would have to name that CPU.
    arch = if system == "x86_64-linux" then "x64" else "arm64";
    variant =
      if jit then
        "${arch}-jit"
      else if arch == "x64" then
        "x64-baseline"
      else
        arch;

    # Deduplicate identical derivations, not names: different patched versions must not silently replace one another.
    closure = builtins.genericClosure {
      startSet = map (plugin: {
        key = toString plugin;
        inherit plugin;
      }) finalAttrs.plugins;
      operator =
        { plugin, ... }:
        map (dep: {
          key = toString dep;
          plugin = dep;
        }) plugin.piBolt.dependencies;
    };
    byName = lib.groupBy (
      { plugin, ... }:
      plugin.piBolt.name
        or (throw "pi-bolt: ${plugin.name or "a plugin"} is not a buildPiBoltPlugin derivation")
    ) closure;
    conflicts = lib.attrNames (lib.filterAttrs (_: entries: lib.length entries > 1) byName);
    checkedClosure =
      assert lib.assertMsg (
        conflicts == [ ]
      ) "pi-bolt: different plugin derivations share a name: ${lib.concatStringsSep ", " conflicts}";
      map ({ plugin, ... }: plugin) closure;

    # Every plugin in the closure is staged once, so a dependency both registered and imported is one copy.
    isRegistered = plugin: lib.elem (toString plugin) (map toString finalAttrs.plugins);
    registeredPlugins = lib.filter isRegistered checkedClosure;
    registeredNames = map (plugin: plugin.piBolt.name) registeredPlugins;

    # The manifest scripts/build-pi.sh --plugins reads: the same shape as examples/plugins/plugins.ts.
    manifest = writeText "plugins.ts" (
      ''
        // Generated by nix/pi-bolt.nix: the plugins a Nix expression compiles into Pi-Bolt.
        import type { InlineExtension } from "@earendil-works/pi-coding-agent";
      ''
      + lib.concatStrings (
        lib.imap0 (
          i: plugin:
          "import plugin_${toString i} from ${builtins.toJSON "./${plugin.piBolt.name}/${plugin.piBolt.entry}"};\n"
        ) registeredPlugins
      )
      + "\nconst plugins: InlineExtension[] = [\n"
      + lib.concatStrings (
        lib.imap0 (
          i: plugin:
          "\t{ name: ${builtins.toJSON plugin.piBolt.name}, factory: plugin_${toString i}, builtin: ${
            if plugin.piBolt.builtin then "true" else "false"
          } },\n"
        ) registeredPlugins
      )
      + "];\n\nexport default plugins;\n"
    );

    # Each plugin's tree, dereferenced into the manifest's folder. A plugin dependency is a link to its staged sibling, by a
    # path relative to the folder (the link sits in node_modules, one level per package-name part below the plugin).
    stagePlugins = lib.concatMapStrings (
      plugin:
      let
        name = plugin.piBolt.name;
        linked = lib.filter (dep: dep.piBolt.packageName != null) plugin.piBolt.dependencies;
      in
      ''
        mkdir -p plugins/${name}
        cp -r --no-preserve=mode ${plugin}/. plugins/${name}/
        chmod -R u+w plugins/${name}
      ''
      + lib.concatMapStrings (
        dep:
        let
          package = dep.piBolt.packageName;
          up = lib.concatStrings (lib.replicate (1 + lib.length (lib.splitString "/" package)) "../");
        in
        ''
          rm -rf plugins/${name}/node_modules/${package}
          mkdir -p "$(dirname plugins/${name}/node_modules/${package})"
          ln -s ${up}${dep.piBolt.name} plugins/${name}/node_modules/${package}
        ''
      ) linked
    ) checkedClosure;

    workers = lib.concatMap (
      plugin: map (worker: "--plugin-worker ${plugin.piBolt.name}/${worker}") plugin.piBolt.workers
    ) checkedClosure;

    unwrapped = stdenv.mkDerivation {
      pname = "pi-bolt-unwrapped";
      inherit version;

      dontUnpack = true;
      nativeBuildInputs = [
        python3
        rsync
        patchelf
        autoPatchelfHook
      ];
      # The native module Pi's TUI loads to read the keyboard's modifiers under X11.
      buildInputs = [ libxcb ];

      buildPhase = ''
        runHook preBuild
        # build-pi.sh writes into its tree, so the tree is a copy: the source, with the workspace's built packages over it.
        cp -a ${sources.compile}/. tree
        chmod -R u+w tree
        cp -a ${workspace}/. tree
        chmod -R u+w tree
        # The scripts start with /usr/bin/env, which the build sandbox does not have.
        # The runtime is an engine: a source that changes the engine (webkit, bun, their patches) needs a runtime of its own.
        # Checked on the store copy: patchShebangs below rewrites the scripts the stamp hashes.
        [ "$(bash ${sources.compile}/scripts/runtime-stamp.sh)" = ${runtimePin.stamp} ] || {
          echo "pi-bolt: this source's engine is not release ${releaseVersion}'s (stamp ${runtimePin.stamp}): add its runtime to nix/runtime.json" >&2
          exit 1
        }
        patchShebangs tree/scripts

        mkdir runtime
        tar -xzf ${runtime} -C runtime --strip-components=1
        chmod -R u+w runtime
        # Before compiling: rewriting the compiled executable would damage its AOT image.
        patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" runtime/bun

        ${lib.optionalString (plugins != [ ]) ''
          mkdir plugins
          ${stagePlugins}
          cp ${manifest} plugins/plugins.ts
        ''}
        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        ${lib.optionalString (maxAotCandidateBytecodeSize != null) ''
          export BUN_JSC_maximumAOTCandidateBytecodeSize=${toString maxAotCandidateBytecodeSize}
        ''}
        mkdir -p $out/lib
        PIBOLT_WORK=$TMPDIR/work \
          PIBOLT_BUN=$PWD/runtime/bun \
          PIBOLT_RUNTIME_STAMP=${runtimePin.stamp} \
          ./tree/scripts/build-pi.sh --cpu baseline --jit ${if jit then "on" else "off"} \
          ${lib.optionalString (plugins != [ ]) "--plugins $PWD/plugins/plugins.ts ${lib.concatStringsSep " " workers}"} \
          --out $out/lib/pi-bolt
        echo "Built with Nix: ${variant}${
          lib.optionalString (registeredNames != [ ]) ", plugins compiled in: ${lib.concatStringsSep ", " registeredNames}"
        }" >> $out/lib/pi-bolt/pi-bolt.txt
        runHook postInstall
      '';

      # The executable is an AOT image: stripping or patching it damages it. Only the native modules are patched.
      dontStrip = true;
      dontPatchELF = true;
      dontAutoPatchelf = true;
      postFixup = ''
        autoPatchelf $out/lib/pi-bolt/native
      '';

      doInstallCheck = true;
      installCheckPhase = ''
        runHook preInstallCheck
        # As build-pi.sh checks: it runs, as this version, from its compiled code.
        said=$(HOME=$TMPDIR BUN_STATIC_HEAP_VERBOSE=1 $out/lib/pi-bolt/pi --version 2>&1)
        printf '%s\n' "$said"
        grep -q 'image registered: true' <<< "$said"
        grep -q 'Pi-Bolt ${version},' <<< "$said"
        runHook postInstallCheck
      '';

      passthru = {
        inherit variant;
        plugins = finalAttrs.plugins;
        runtimeInputs = toolInputs;
      };
      meta = meta // {
        description = "${meta.description} (the compiled executable, without its launcher)";
      };
    };

    toolInputs = lib.unique (
      runtimeInputs ++ lib.concatMap (plugin: plugin.piBolt.runtimeInputs) finalAttrs.plugins
    );

    meta = {
      description = "Pi, the coding agent, compiled ahead of time";
      homepage = "https://github.com/opensec-git/Pi-Bolt";
      license = lib.licenses.mit;
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      # The runtime is Pi-Bolt's patched Bun, released as a binary: it is not built here from source.
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  in
  {
    pname = "pi-bolt";
    version = label;
    inherit plugins;

    dontUnpack = true;
    nativeBuildInputs = [ makeBinaryWrapper ];

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib $out/bin
      cp -r ${unwrapped}/lib/pi-bolt $out/lib/pi-bolt
      chmod -R u+w $out/lib/pi-bolt
      # A binary wrapper costs one exec and leaves process.execPath alone, so assets still resolve.
      # PATH only: the package does not touch argv, so a launch is Pi's own.
      makeBinaryWrapper $out/lib/pi-bolt/pi $out/bin/pi-bolt \
        ${lib.optionalString (toolInputs != [ ]) "--prefix PATH : ${lib.makeBinPath toolInputs}"}
      ln -s pi-bolt $out/bin/pi
      runHook postInstall
    '';

    dontStrip = true;
    dontPatchELF = true;

    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck
      said=$(HOME=$TMPDIR BUN_STATIC_HEAP_VERBOSE=1 $out/bin/pi --version 2>&1)
      grep -q 'image registered: true' <<< "$said"
      runHook postInstallCheck
    '';

    passthru = {
      inherit unwrapped;
      plugins = finalAttrs.plugins;
      runtimeInputs = toolInputs;
      # Through callPackage again, so that the result carries `override` too: `(pi-bolt.withPlugins f).override { jit = true; }`.
      withPlugins = select: callPackage ./pi-bolt.nix (args // { plugins = select piBoltPlugins; });
    };

    meta = meta // {
      mainProgram = "pi-bolt";
    };
  }
)
