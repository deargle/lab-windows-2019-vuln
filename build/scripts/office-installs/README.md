# Office 2010 (Word) for the malicious-macro lab

Replaces the old `chocolatey-installs/install-word.ps1` flow (which pulled a
**Click-to-Run retail** Word from Microsoft's live CDN — floating version, and a
5-day grace that ends at a *"Sign in to set up Office"* Microsoft-account screen)
with a **pinned, offline, no-login** Microsoft Office Professional Plus 2010
install. The lab in `security-assignments.github.io/_labs/lab_social_engineering.md`
(Part 4) needs real Word **VBA** to run an msfvenom `vba-exe` meterpreter macro;
LibreOffice cannot substitute.

## Why this avoids the old pain

* **No Microsoft login.** MSI Office 2010 activates only via a 25-char product
  key / KMS / MAK — never a Microsoft account. We supply **no key at all**, so
  Word runs fully functional in its built-in **~30-day grace period**.
* **Version never floats.** We install from one frozen ISO, not a CDN.
* **No shelf-expiry surprise.** `office-rearm.ps1` (`OSPPREARM.EXE`) resets the
  grace to a fresh ~30 days; Office 2010 allows up to 5 rearms per install.

## The media

    gs://security-assignments-vagrant-boxes/lab-isos/office2010-proplus-x86-X16-52536.iso
    767,354,880 bytes
    md5  80c74952d1601690e22d461057f157df
    sha1 9f1d385a8989c4d4951b55f0edfaea9066b8f54e

Genuine Microsoft RTM Professional Plus 2010 (32-bit, English MLF, X16-52536) —
the same disc Microsoft shipped for its free public 60-day trial. Installed with
no key it uses the 30-day grace. The bucket is **private**; the ISO is not world-
readable (verify: an unauthenticated GET returns 403).

## Files

| file | role |
|---|---|
| `install-office2010.ps1` | **self-contained**: find/mount media → silent no-key, Word-only install → inline regkeys (macros + VBA on, first-run suppressed). Self-contained because Vagrant `path:` uploads only this one file. Runs at build time (normal path) and can also be triggered at lab start as a fallback. |
| `verify-office-ready.ps1` | build gate: headless Word COM runs a VBA macro that writes a file and `Shell`s a process (what the exploit does). Non-zero exit fails the build. |
| `verify-macro-lab-e2e.sh` + `w.rb` | **run-time** end-to-end check (Kali host, not guest): proves the full Part 4 chain headlessly — msfvenom `vba-exe` -> valid PE, handler binds on `192.168.56.101:7777`, Windows VM macro-ready, and the decoded payload PE **opens a meterpreter session** over the lab `.56` network. The only step left unverified is the interactive "open .docm + Enable Content" click. See its header for the `LHOST=virbr1` caveat. |
| `office-rearm.ps1` | student lab-start step: reset the Office grace, reboot. |

## Deployment: Word baked into the box

Word is installed at build time (`BAKE_OFFICE=1`) and shipped baked into the
published box; the ISO itself is never packaged (attached as a cdrom /
mounted, not copied in). Every published box is verified at build time by
`verify-office-ready.ps1`, which fails the build if Word + the VBA engine
aren't installed and macro-ready. At lab start the student just runs
`office-rearm` to reset the ~30-day grace on a possibly-shelved box —
zero in-Windows clicks, since first-run suppression is stamped in via the
Default-hive + HKLM policy regkeys in `install-office2010.ps1`.

Build it (recommended on a GCP nested-virt box so the pull is in-region/free):

    gsutil cp gs://security-assignments-vagrant-boxes/lab-isos/office2010-proplus-x86-X16-52536.iso ./office2010.iso
    cd build
    BAKE_OFFICE=1 OFFICE_ISO_PATH="$PWD/../office2010.iso" vagrant up
    BAKE_OFFICE=1 OFFICE_ISO_PATH="$PWD/../office2010.iso" vagrant provision   # installs + verifies (build fails if the macro primitive doesn't run)
    ./package.sh                                                               # ISO is attached as cdrom, NOT packaged into the box
    # then bump box_version and republish to the registry

Student, at lab start:

    vagrant provision --provision-with office-rearm

### Fallback: box built without BAKE_OFFICE=1

If a box was shipped without Office baked in, install Word at lab start
instead. The student's box has no gcloud creds, so `install-office2010.ps1`
needs the media over plain HTTPS. Supply it via `office-iso-url.txt` (see
`office-iso-url.txt.example`): a `gsutil signurl` signed URL, a public ACL on
just that one object, or a course mirror.

    vagrant provision --provision-with install-word

## Notes

* `install-word` (repo-root Vagrantfile) now points here, not at Chocolatey.
* The old `chocolatey-installs/install-word.ps1` is left in place for reference
  but is no longer referenced by any Vagrantfile.
* `office-rearm` is distinct from the existing `rearm` provisioner, which rearms
  **Windows'** eval grace (`slmgr /rearm`), not Office.
