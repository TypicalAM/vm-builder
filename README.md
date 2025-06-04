# Small VM builder for QEMU

This is an upgrade to my system mentioned at [I Love Free Software 25](https://github.com/TypicalAM/ilfs25), using flakes. I want to make this a devenv builder for qemu.

Todo:

- [ ] Do not use `/tmp/machine-config.nix`
- [ ] Deps locking
- [ ] Minimize the vm building step packages
- [ ] Place the resulting config inside of the machine
- [ ] File inclusion via zip?
