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
| `config-word-only.xml` | setup answer file: silent, no key, **Word only**. |
| `install-office2010.ps1` | mount/find media → silent install → apply regkeys. Build-time (Path A) and student lab-start (Path B). |
| `office-lab-regkeys.ps1` | zero-click readiness: suppress first-run, enable all macros + VBA object model, for the Labuser profile and machine-wide. |
| `verify-office-macro.ps1` | build gate: headless Word COM runs a VBA macro that writes a file and `Shell`s a process (what the exploit does). Non-zero exit fails the build. |
| `office-rearm.ps1` | student lab-start step for Path A: reset the Office grace, reboot. |

## Two paths (both wired; pick after testing)

**Path A — bake Word into the box; student rearms.**
Least clicks at lab time (Word already installed; one `office-rearm`; zero
in-Windows clicks if suppression holds) and every published box is verified at
build. Cost: requires a **box rebuild + republish**, and correctness depends on
`OSPPREARM` reviving a *cloned, possibly-expired* box — the main thing to test.

Build it (recommended on a GCP nested-virt box so the pull is in-region/free):

    gsutil cp gs://security-assignments-vagrant-boxes/lab-isos/office2010-proplus-x86-X16-52536.iso ./office2010.iso
    cd build
    BAKE_OFFICE=1 OFFICE_ISO_PATH="$PWD/../office2010.iso" vagrant up
    BAKE_OFFICE=1 OFFICE_ISO_PATH="$PWD/../office2010.iso" vagrant provision   # installs + verifies (build fails if the macro primitive doesn't run)
    ./package.sh                                                               # ISO is attached as cdrom, NOT packaged into the box
    # then bump box_version and republish to the registry

Student, at lab start:

    vagrant provision --provision-with office-rearm

**Path B — ship a box with no Office; student installs at lab start.**
**No box rebuild needed** — just this repo's script plus a reachable media URL,
so it's the cheap way to ship/iterate. Cost: a ~5–10 min silent install at lab
start (measure it — that was the open question). The student's box has no gcloud
creds, so `install-office2010.ps1` needs the media over plain HTTPS. Supply it via
`office-iso-url.txt` (see `office-iso-url.txt.example`): a `gsutil signurl`
signed URL, a public ACL on just that one object, or a course mirror.

    vagrant provision --provision-with install-word

## Test checklist (open questions to close when a build is run)

1. **Install time (Path B).** How long is the silent Word-only install on the
   2-vCPU/2 GB box? If it's short and unattended, Path B may be good enough.
2. **Zero clicks.** First launch of Word as **Labuser** must show no first-run,
   privacy, or activation dialog. Confirm `office-lab-regkeys.ps1` fully
   suppresses them (the Default-hive stamping is the uncertain part).
3. **Verify gate.** `verify-office-macro.ps1` exits 0 on a fresh install.
4. **Rearm-from-expired (Path A).** Package a box, let its grace expire (or fast-
   forward the clock), clone it, boot, run `office-rearm` → Word is fully
   functional again. This is the make-or-break test for Path A; if `OSPPREARM`
   won't recover a fully-expired clone, fall back to Path B.
5. **Clone/CMID.** Confirm the packaged grace state behaves on a fresh clone
   (Vagrant `package` is not a sysprep generalize).

## Notes

* `install-word` (repo-root Vagrantfile) now points here, not at Chocolatey.
* The old `chocolatey-installs/install-word.ps1` is left in place for reference
  but is no longer referenced by any Vagrantfile.
* `office-rearm` is distinct from the existing `rearm` provisioner, which rearms
  **Windows'** eval grace (`slmgr /rearm`), not Office.
