Set-PSDebug -Trace 1
cd "C:\Users\vagrant\Downloads"

wget 'https://www.libreoffice.org/donate/dl/win-x86_64/6.2.8/en-US/LibreOffice_6.2.8_Win_x64.msi' -out 'libre_office.msi'

Start-Process msiexec.exe -ArgumentList "/qb /i libre_office.msi /l* LibreOffice_install_log.txt REGISTER_NO_MSO_TYPES=1 UI_LANGS=en_GB ISCHECKFORPRODUCTUPDATES=0 REBOOTYESNO=No QUICKSTART=0 ADDLOCAL=ALL VC_REDIST=0 REMOVE=gm_o_Onlineupdate,gm_r_ex_Dictionary_Af,gm_r_ex_Dictionary_An,gm_r_ex_Dictionary_Ar,gm_r_ex_Dictionary_Be,  gm_r_ex_Dictionary_Bg, gm_r_ex_Dictionary_Bn,gm_r_ex_Dictionary_Br,gm_r_ex_Dictionary_Pt_Br,gm_r_ex_Dictionary_Pt_Pt,gm_r_ex_Dictionary_Ca,gm_r_ex_Dictionary_Cs, gm_r_ex_Dictionary_Da,gm_r_ex_Dictionary_Nl,gm_r_ex_Dictionary_Et,gm_r_ex_Dictionary_Gd,gm_r_ex_Dictionary_Gl,gm_r_ex_Dictionary_Gu, gm_r_ex_Dictionary_De,gm_r_ex_Dictionary_He,gm_r_ex_Dictionary_Hi,gm_r_ex_Dictionary_Hu,gm_r_ex_Dictionary_It,gm_r_ex_Dictionary_Lt, gm_r_ex_Dictionary_Lv,gm_r_ex_Dictionary_Ne,gm_r_ex_Dictionary_No,gm_r_ex_Dictionary_Oc,gm_r_ex_Dictionary_Pl,gm_r_ex_Dictionary_Ro, gm_r_ex_Dictionary_Ru,gm_r_ex_Dictionary_Si,gm_r_ex_Dictionary_Sk,gm_r_ex_Dictionary_Sl,gm_r_ex_Dictionary_El,gm_r_ex_Dictionary_Es, gm_r_ex_Dictionary_Sv,gm_r_ex_Dictionary_Te,gm_r_ex_Dictionary_Th,gm_r_ex_Dictionary_Vi,gm_r_ex_Dictionary_Zu" -NoNewWindow -Wait

# Set Macro options to prompt user

$RegistryKey = "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\LibreOffice\org.openoffice.Office.Common\Security\Scripting\MacroSecurityLevel"
$RegistryEntry = "Value"
Set-ItemProperty -Path $RegistryKey -Name $RegistryEntry -Value "2"
