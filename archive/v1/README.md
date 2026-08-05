# v1 container images (archived)

Retired 2026-08-05 per TODO.v2-1/13. These files built the
`tebako-ubuntu-20.04` / `tebako-alpine-3.17` images that served the
tebako-runtime-ruby container legs (the item-14 new build model:
`tools/build_runtime` against prebuilt libtfs packages).

They are replaced by the `tpkg-builder-<triplet>` family (see the
top-level README), which generalises the same shape to every
slice-producing repo and carries the v2 Rust/vcpkg toolchain.

Facts that do not change with this archive:

- **Published v1 images stay published.** Every
  `ghcr.io/tamatebako/tebako-{ubuntu-20.04,alpine-3.17}:<version>-<arch>`
  tag pushed before the retirement remains available and immutable, so
  tebako-runtime-ruby's container legs keep resolving their pinned tags.
- **The tag chain is retired with the workflow.** `add-tag.yml` (the
  `repository_dispatch: 'tebako release'` → repo tag → `workflow_run` →
  image rebuild chain) no longer runs: no NEW `tebako-<container>:<ver>`
  tags will be produced. The consumer rewiring (TODO.v2-1/13 steps 2–3)
  moves the factory POSIX legs and the feedstocks onto
  `tpkg-builder-<triplet>` images; the tebako-samples / tebako-runtime-ruby
  re-dispatch wiring moves with it.
- If a v1 rebuild is ever needed in the transition window, these files
  are the last known-good state; restore them onto a branch, do not
  extend them on main.
