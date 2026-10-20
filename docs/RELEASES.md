# Releases and sources

## Which release is built

The `pi-bolt` input of this flake names a Pi-Bolt release, such as `bolt-v0.9.5`. The package's version is that release's
`VERSION`. A source built on its own, rather than the release, is labelled `<version>-unstable-<date>`.

Your lock pins the flake's revision, so updating it to a newer release is `nix flake update pi-bolt-nix`.

## Building a fork or a branch

To compile a fork or a branch, follow your own input:

```nix
{
  inputs.pi-bolt-nix.url = "github:Shrub24/Pi-Bolt.nix";
  inputs.my-pi-bolt = {
    url = "github:me/Pi-Bolt/my-branch";
    flake = false;
  };
  inputs.pi-bolt-nix.inputs.pi-bolt-source.follows = "my-pi-bolt";
}
```

Declared as your own input, a source with no `flake.nix` (an archive, a tarball, a plain checkout) needs `flake = false`.
Without it, Nix fetches the source as a flake and fails with `flake.nix does not exist`. The snippet does this.

You can instead override the URL of the source the flake already declares. This works with a source that has no `flake.nix`:

```nix
inputs.pi-bolt-nix.inputs.pi-bolt-source.url = "path:../Pi-Bolt";
```

For one command, without editing your flake:

```sh
nix build --override-input pi-bolt-nix/pi-bolt-source path:../Pi-Bolt
```

## The engine must match the release

Pi-Bolt's executable runs on a runtime (its patched Bun and WebKit) that the release supplies. A source builds only if its
engine is the release's. The build hashes the engine's inputs, which include the patches, and fails when the hash differs from
the runtime's, naming both:

```
pi-bolt: this source's engine is not release 0.9.5's (source stamp …, runtime stamp 34ccf3c94a5e9606) …
```

The flake builds no runtime, so a source with a different engine fails until the release that matches it is in use.

Some changes leave the Linux engine unchanged and still change the hash, such as a change to the Windows runtime script. For
such a source, `checkRuntimeStamp = false` turns the failure into a warning and builds it. Use it only when the engine is
unchanged:

```nix
pkgs.pi-bolt.override { checkRuntimeStamp = false; }
```
