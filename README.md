# Small VM builder for QEMU

This is an upgrade to my system mentioned at [I Love Free Software 25](https://github.com/TypicalAM/ilfs25), using flakes. I want to make this a devenv builder for qemu.

Todo:

- [x] Do not use `/tmp/machine-config.nix`
- [x] Place the resulting config inside of the machine
- [ ] Deps locking
- [ ] Minimize the vm building step packages
- [ ] File inclusion via zip?
