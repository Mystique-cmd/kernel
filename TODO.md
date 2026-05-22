# TODO.md

- [ ] Inspect current paging code paths in `kernel.asm` (already done via review).
- [x] Implement separate user page directory/table and `setup_user_paging` routine in `kernel.asm`.
- [ ] Add `switch_to_user_space` stub that loads `CR3` with `user_page_directory`.
- [ ] Ensure kernel boot path still works without switching to user CR3 yet.
- [ ] Build/boot in QEMU and verify output (after code changes).

