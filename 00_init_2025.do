* ------------------------------------------------------------------
*
*
*     This file contains the initialization to run the pipeline
*     for KIHBS 2025 monitoring and analysis
*
*-------------------------------------------------------------------
clear all
set more off
set maxvar 10000
set seed 24081980 
set sortseed 11041955
set gr off 

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

**# Configure machines paths and load API credentials

*Emanuel
if (inlist("${suser}","wb562201", "WB562201")) {
	local swdLocal = "C:\//Users\/wb562201\/OneDrive - WBG\/Countries\/Kenya\/KEN_KIHBS_2024_pilot"
	local gdrive = "G:\/My Drive\/Kihbs_2025"
	
	*Store api credentials (User specific - sent via email for security)
	import delimited "`swdLocal'\0-RawInput\api_credentials_silas.csv", varnames(1) 
	qui levelsof username_api,local(username_api)
	global username_api `username_api'
	
	qui levelsof password_api,local(password_api)
	global password_api `password_api'
	
	qui levelsof username_hq,local(username_hq)
	global username_hq `username_hq'

	qui levelsof password_hq,local(password_hq)
	global password_hq `password_hq'
}
*Kevin
else if (inlist("${suser}","wb426252", "WB426252")) {
	local swdLocal = "C:\Users\WB426252\OneDrive - WBG\WB - Kenya\KIHBS_Pilot"	
	local gdrive = "C:\Users\WB426252\OneDrive - WBG\WB - Kenya\KIHBS_Pilot\Google drive\" 

	*Store api credentials (User specific - sent via email for security)
	import delimited "`swdLocal'\0-RawInput\api_credentials_silas.csv", varnames(1) 
	qui levelsof username_api,local(username_api)
	global username_api `username_api'
	
	qui levelsof password_api,local(password_api)
	global password_api `password_api'
	
	qui levelsof username_hq,local(username_hq)
	global username_hq `username_hq'

	qui levelsof password_hq,local(password_hq)
	global password_hq `password_hq'
}
*Asmelash
else if (inlist("${suser}","wb412495", "WB412495")) {
	local swdLocal = "C:\Users\WB412495\OneDrive - WBG\KIHBS_2024_Pilot"	
}
*Magara
else if (inlist("${serial_number}","18461036")) {
	local gdrive = "H:\.shortcut-targets-by-id\10IFkPhUkYxdKlqYfY3zrUo7_umTwnl1C\Kihbs_2025"
	local swdLocal = "C:\Kihbs_2025"	
	
	*Store api credentials (User specific - sent via email for security)
	import delimited "`swdLocal'\0-RawInput\api_credentials_magara.csv", varnames(1) 
	qui levelsof username_api,local(username_api)
	global username_api `username_api'
	
	qui levelsof password_api,local(password_api)
	global password_api `password_api'
	
	qui levelsof username_hq,local(username_hq)
	global username_hq `username_hq'

	qui levelsof password_hq,local(password_hq)
	global password_hq `password_hq'

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
global gsdData = "`swdLocal'/\Data"
global gsdDo = "`swdLocal'/\Do"
global gsdTemp = "`swdLocal'/\Temp"
global gsdOutput = "`swdLocal'/\Output"
global gsdDataRaw =  "`swdLocal'/\0-RawInput"
global gsdQuestionnaire = "`swdLocal'/\Questionnaire"
global gsdDocuments = "`swdLocal'/\Documents"
global gsdGdrive = "`gdrive'" 

**# Install necessary commands
*if needed install the necessary commands
local commands = "filelist fs matchit freqindex savesome mdesc distinct fre outdetect gtools confirmdir ralpha missings betterbar mkdensity mmerge inlist2 tknz shp2dta geo2xy spmap norm"
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

**# Install directories
*If needed, install the directories and packages used in the process
cap confirmdir "`swdLocal'/Data"
if _rc!=0 {
	qui shell mkdir "${gsdData}"
}
cap confirmdir "`swdLocal'/Temp"
if _rc!=0 {
	qui shell mkdir "${gsdTemp}"
}
cap confirmdir "`swdLocal'/Output"
if _rc!=0 {
	qui shell mkdir "${gsdOutput}"
}
cap confirmdir "${gsdData}/0-RawOutput"
if _rc!=0 {
	qui shell mkdir "${gsdData}/0-RawOutput"
}
cap confirmdir "${gsdData}/Output/hfc_output"
if _rc!=0 {
	qui shell mkdir "${gsdData}/Output/hfc_output"
}
cap confirmdir "${gsdQuestionnaire}"
if _rc!=0 {
	qui shell mkdir "${gsdData}/Output/hfc_output"
}
confirmdir "`swdLocal'/Documents"
if _rc!=0 {
	qui shell mkdir "${gsdDocuments}"
}
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
global gsdRawOutput "${gsdData}/0-RawOutput"

qui adopath ++ "${gsdDo}/"

**# Program to create monitoring graphs by enumerator within each team (used by supervisors)
cap program drop graphs_team
program define graphs_team 

	global input2 "`2'"
	global input3 "`3'"
	global input4 "`4'"
	global input5 "`5'"

	qui levelsof sprvsr,local(team)
	foreach t of local team {
	
		dis in red "Export graph for team `t'"

		qui betterbar`6' `1' if sprvsr=="`t'", over(A21) v ytitle("`3'") title("`4'", size(small)) xlab("") saving("${gsdOutput}/`2'_team_`t'.gph", replace) format(%9.0f) `7' `8'
		preserve 
		collapse `1', by(sprvsr A21 week)
		qui keep if sprvsr=="`t'"
		qui greshape wide `1', i(sprvsr week) j(A21)
		qui distinct week
		if `r(ndistinct)'<10 {
			local delta 1
		}
		else if inrange(`r(ndistinct)',11,20) {
			local delta 2
		}
		else if inrange(`r(ndistinct)',21,52) {
			local delta 10
		}
		qui summ week, d
		qui twoway (connect `1'* week) if sprvsr=="`t'", title("Trend", size(small)) legend(off) xlabel(1(`delta')`r(max)') saving("${gsdOutput}/${input2}_ts_team_`t'.gph", replace) 
		gr combine "${gsdOutput}/${input2}_team_`t'.gph" "${gsdOutput}/${input2}_ts_team_`t'.gph", title("${input5}")
		qui graph export "${gsdTemp}\/${input2}_team_`t'.jpg", as(jpg) name("Graph") quality(100) replace
		restore 
}
end

**# Program to create monitoring graphs by county within each province (used by HQ statisticians)
cap program drop graphs_province
program define graphs_province 

	global input2 "`2'"
	global input3 "`3'"
	global input4 "`4'"
	global input5 "`5'"

	qui levelsof province_str,local(province)
	foreach t of local province {
	
		dis in red "Export graph for province `t'"

		qui betterbar`6' `1' if province_str=="`t'", over(A01) v ytitle("`3'") title("`4'", size(small)) xlab("") saving("${gsdOutput}/`2'_province_`t'.gph", replace) format(%9.0f) `7' `8'
		preserve 
		collapse `1', by(province_str A01 week)
		qui keep if province_str=="`t'"
		qui greshape wide `1', i(province_str week) j(A01)
		qui distinct week
		if `r(ndistinct)'<10 {
			local delta 1
		}
		else if inrange(`r(ndistinct)',11,20) {
			local delta 2
		}
		else if inrange(`r(ndistinct)',21,52) {
			local delta 10
		}
		qui summ week, d
		qui twoway (connect `1'* week) if province_str=="`t'", title("Trend", size(small)) legend(off) xlabel(1(`delta')`r(max)') saving("${gsdOutput}/${input2}_ts_province_`t'.gph", replace) 
		gr combine "${gsdOutput}/${input2}_province_`t'.gph" "${gsdOutput}/${input2}_ts_province_`t'.gph", title("${input5}")
		qui graph export "${gsdTemp}\/${input2}_province_`t'.jpg", as(jpg) name("Graph") quality(100) replace
		restore 
}
end

**# Program to create monitoring graphs at national level by province (used by top management at HQ)
cap program drop graphs_national
program define graphs_national

	global input2 "`2'"
	global input3 "`3'"
	global input4 "`4'"
	global input5 "`5'"

	qui betterbar`6' `1', over(province) v ytitle("`3'") title("`4'", size(small)) xlab("") saving("${gsdOutput}/`2'_national.gph", replace) format(%9.0f) `7' `8'
	preserve
	collapse `1', by(province_str week)
	qui greshape wide `1', i(week) j(province_str)
	qui distinct week
	if `r(ndistinct)'<10 {
		local delta 1
	}
	else if inrange(`r(ndistinct)',11,20) {
		local delta 2
	}
	else if inrange(`r(ndistinct)',21,52) {
		local delta 10
	}
	qui summ week, d
	qui twoway (connect `1'* week), title("Trend", size(small)) xlabel(1(`delta')`r(max)') legend(off) saving("${gsdOutput}/${input2}_ts_national.gph", replace) 
	gr combine "${gsdOutput}/${input2}_national.gph" "${gsdOutput}/${input2}_ts_national.gph", title("${input5}")
	qui graph export "${gsdTemp}\/${input2}_national.jpg", as(jpg) name("Graph") quality(100) replace
	restore
end

**# Program to identify outliers and clean them (using stratified hierarchical approach)
cap program drop outliers_detect_fix
program define outliers_detect_fix 

	qui gen nat = 1
	qui gen replacement_level = .
	qui gen `1'_clean = .
	qui gen ln_`1'=ln(`1')
	qui replace ln_`1'=.0001 if `1'==0
	* Define levels and initial cell size threshold
	local levels "strata A01 A15 nat"
	local threshold = 2.5 //strata level starts with 5 data points (i.e. 2.5*2)
	local iteration = 1
	* Loop over each level
	foreach v of local levels {
		dis in red "Outlier detection and addressing at `v' level"
		qui egen outlier_`v' = outside(`1'), by(`2' `v') factor(`3')
		qui bys `v' `2': egen cell_size_`v' = count(`1')
		qui bys `v' `2': egen replacement_value_`v' = median(`1')
		* Set cell size threshold for current iteration
		if "`v'" == "nat" {
			local threshold = 1
		}
		else {
			local threshold = `threshold' * 2
		}
		* Replace `1'_clean and replacement_level
		qui replace `1'_clean = replacement_value_`v' if !mi(outlier_`v') & !mi(replacement_value_`v') & cell_size_`v' >= `threshold' & !mi(cell_size_`v') & mi(`1'_clean)
		qui replace `1'_clean = `1' if mi(outlier_`v') & !mi(replacement_value_`v') & cell_size_`v' >= `threshold' & !mi(cell_size_`v') & mi(`1'_clean)
		qui replace replacement_level = 99 if mi(outlier_`v') & !mi(replacement_value_`v') & cell_size_`v' >= `threshold' & !mi(cell_size_`v') & mi(replacement_level) 
		qui replace replacement_level = `iteration' if !mi(outlier_`v') & !mi(replacement_value_`v') & cell_size_`v' >= `threshold' & !mi(cell_size_`v') & mi(replacement_level)
		* Increment iteration counter
		local iteration = `iteration' + 1
	}
	lab def replacement_level 1 "Strata" 2 "County" 3 "Residence" 4 "National" 99 "No outlier detected"
	lab val replacement_level replacement_level
	qui replace `1'_clean = `1' if mi(`1'_clean) 
	qui replace replacement_level=.a if `1'==.a
	lab drop replacement_level
end

