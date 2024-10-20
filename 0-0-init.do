* ------------------------------------------------------------------
*
*
*     This file contains the initialization to run the pipeline
*     for KIHBS 2024 pilot analysis.
*
*-------------------------------------------------------------------
*Uniquely identify machines via Machine name
global suser = c(username)

*Uniquely identify machines via License serial number
//Step 1: Capture the about output
tempfile aboutlog
log using `aboutlog', text replace
about
log close
//Step 2: Extract the serial number
file open myfile using `aboutlog', read text
file read myfile line
local serial_number ""
while r(eof)==0 {
    if strpos("`line'", "Serial number:") {
        global serial_number = trim(subinstr("`line'", "Serial number:", "", .))
        break
    }
    file read myfile line
}
file close myfile
// Step 3: Display the serial number
display "Your Stata serial number is: ${serial_number}"

clear all
set more off
set maxvar 10000
set seed 24081980 
set sortseed 11041955

*Emanuel
if (inlist("${suser}","wb562201", "WB562201")) {
	local swdLocal = "C:\Users\wb562201\OneDrive - WBG\Countries\Kenya\KEN_KIHBS_2024_pilot"
}
*Kevin
else if (inlist("${suser}","wb426252", "WB426252")) {
	local swdLocal = "C:\Users\WB426252\OneDrive - WBG\WB - Kenya\KIHBS_Pilot"	
}
*Asmelash
else if (inlist("${suser}","wb412495", "WB412495")) {
	local swdLocal = "C:\Users\WB412495\OneDrive - WBG\KIHBS_2024_Pilot"	
}
*Magara
else if (inlist("${serial_number}","18461036")) {
	local swdLocal = "C:\Kihbs_2024_pilot\Kihbs_2024_pilot"	
}
*Pius
else if (inlist("${serial_number}","501806395087")) {
	local swdLocal = "C:\Users\KNBS\OneDrive - Kenya National Bureau of Statisitics\KIHBS_Pilot"
}
*Samoei
else if (inlist("${suser}","USER")) {
local swdLocal = "C:\Users\USER\OneDrive - Kenya National Bureau of Statisitics\KIHBS24\2024_KIHBS_Pilot"
}
*Silas
else if (inlist("${suser}","SILAS MULWA")) {
local swdLocal = "C:\KIHBS_2024_Pilot"
}
*Denis
else if (inlist("${serial_number}","501806395089")) {
	local swdLocal = "D:\KIHBS 24_2025\"
}
*Katra 
else if (inlist("${suser}","KNBS")) {
	local swdLocal = "C:\Users\KNBS\Documents\Research & Development\2024_25 KIHBS\"
}
*Yvonne
else if (inlist("${suser}","Yvoche")) {
local swdLocal = "C:\Users\Yvoche\Desktop\KihbsPilot"
}
else {
	di as error "Configure work environment in init.do before running the code."
	error 1
}

* Define filepaths.
global gsdData = "`swdLocal'/Data"
global gsdDo = "`swdLocal'/Do"
global gsdTemp = "`swdLocal'/Temp"
global gsdOutput = "`swdLocal'/Output"
global gsdDataRaw =  "`swdLocal'/0-RawInput"
global gsdQuestionnaire = "`swdLocal'/Questionnaire"
global gsdDocuments = "`swdLocal'/Documents"

*if needed install the necessary commands
local commands = "filelist fs matchit freqindex savesome mdesc distinct fre outdetect gtools confirmdir ralpha missings betterbar mkdensity mmerge INLIST2"
foreach c of local commands {
	qui capture which `c'
	qui if _rc!=0 {
		noisily di "This command requires '`c''. The package will now be downloaded and installed."
		ssc install `c'
	}
}
*Ipacheck is only used by users with access to raw data
qui capture which ipacheck
qui if _rc!=0 {
noisily di "This command requires ipacheck. The package will now be downloaded and installed."
net install ipacheck, all replace from("https://raw.githubusercontent.com/PovertyAction/high-frequency-checks/master")
ipacheck update
}
*Sursol is only used by users with access to raw data
qui capture which sursol
qui if _rc!=0 {
noisily di "This command requires ipacheck. The package will now be downloaded and installed."
	net install sursol , from("https://raw.githubusercontent.com/petbrueck/sursol/master/src") replace
}
*renvars 
qui capture which dm88_1
qui if _rc!=0 {
	net install dm88_1 , from("http://www.stata-journal.com/software/sj5-4/") replace
}
*tabstatxls (WB users must turn off VPN)
qui capture which github
qui if _rc!=0 {
	net install github, from("https://haghish.github.io/github/")
}
*tabstatxls (WB users must turn off VPN)
qui capture which tabstatxls
qui if _rc!=0 {
	github install NicolaTommasi8/tabstatxls
}
*Photobook
qui capture which photobook
qui if _rc!=0 {
	net install photobook, from("https://raw.githubusercontent.com/PovertyAction/photobook/master") replace 
}	
macro list

*If needed, install the directories and packages used in the process
confirmdir  "`swdLocal'/Data"
scalar define n_data=_rc
confirmdir "`swdLocal'/Do"
scalar define n_do=_rc
confirmdir "`swdLocal'/Temp"
scalar define n_temp=_rc
confirmdir "`swdLocal'/Output"
scalar define n_output=_rc

confirmdir "${gsdData}/0-RawOutput"
scalar define n_rawoutput=_rc
confirmdir "${gsdData}/Output/hfc_output"
scalar define n_hfcoutput=_rc

confirmdir "`swdLocal'/Questionnaire"
scalar define n_questionnaire=_rc
confirmdir "`swdLocal'/Documents"
scalar define n_documents=_rc
di n_data
scalar define check=n_data+n_do+n_temp+n_output +n_questionnaire +n_documents+n_rawoutput+n_hfcoutput
di check

if check==0 {
		display "No action needed"
}
else  {
	qui shell mkdir "${gsdData}"
	qui shell mkdir "${gsdData}/0-RawTemp"
	qui shell mkdir "${gsdData}/0-RawOutput"
	qui shell mkdir "${gsdData}/1-CleanOutput"
	qui shell mkdir "${gsdData}/1-CleanTemp"
	qui shell mkdir "${gsdData}/1-CleanInput"
	qui shell mkdir "${gsdDo}"
	qui shell mkdir "${gsdTemp}"
	qui shell mkdir "${gsdOutput}"
	qui shell mkdir "${gsdQuestionnaire}"
	qui shell mkdir "${gsdDocuments}"
	qui shell mkdir "${gsdOutput}/hfc_output"
}
global gsdRawOutput "${gsdData}/0-RawOutput"

qui adopath ++ "${gsdDo}/"

confirmdir "${gsdData}/0-RawOutput/pilot/"
if _rc!=0 {
	qui shell mkdir "${gsdData}/0-RawOutput/pilot/"
}
confirmdir "${gsdOutput}/hfc_output/pilot/"
if _rc!=0 {
	qui shell mkdir "${gsdOutput}/hfc_output/pilot/"
}
confirmdir "${gsdTemp}/pilot/"
if _rc!=0 {
	qui shell mkdir "${gsdTemp}/pilot/"
}