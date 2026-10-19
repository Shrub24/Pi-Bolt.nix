# fetchNpmPackage: one package from the npm registry, unpacked: a plugin published to npm, or a library a plugin imports.
#
#   fetchNpmPackage { pname = "@narumitw/pi-tui-kit"; version = "0.65.5"; hash = "sha512-..."; }
#
# The hash is the tarball's: `npm view <pname>@<version> dist.integrity`.
{
  lib,
  fetchurl,
  stdenvNoCC,
}:
{
  pname,
  version,
  hash,
}:
stdenvNoCC.mkDerivation {
  pname = lib.strings.sanitizeDerivationName (lib.removePrefix "@" pname);
  inherit version;
  src = fetchurl {
    url = "https://registry.npmjs.org/${pname}/-/${lib.last (lib.splitString "/" pname)}-${version}.tgz";
    inherit hash;
  };
  dontBuild = true;
  dontFixup = true;
  installPhase = "cp -r . $out";
  passthru.packageName = pname;
}
