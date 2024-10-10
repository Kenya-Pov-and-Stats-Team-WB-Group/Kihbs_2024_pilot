**# Analyze paradata
qui import delimited using "${gsdDataRaw}/paradata_all.tab", clear

// ONLY KEEP INTERVIEWER ACTIONS
keep if role==1
drop if inlist(cleandur,0,.) 
replace variable=subinstr(variable,"Interview","#",.)

// Parse sections
local sections A B C D E F G H I J K L M N O P Q R S T U V W X YA YB YD YE YF YG YH YI YK YJ YL 
foreach s of local sections { 
	qui gen sect`s'_dur = cleandur/60 if (regexm(substr(variable,1,1),"`s'") & length("`s'")==1) | regexm(variable,"Sec`s'") | ((regexm(substr(variable,1,2),"`s'") & length("`s'")==2))
	lab var sect`s'_dur "Duration of interview for section `s' in minutes" 
}
// A few manual fixes for variables that did not conform to naming scheme
replace sectA_dur = cleandur/60 if regexm(variable,"consen")
replace sectYA_dur = cleandur/60 if regexm(variable,"_cons_|purch|q1_") 
egen  nmiss =rowmiss(sectA_dur- sectYL_dur)
br variable sectA_dur- sectYL_dur nmiss if nmiss>34
//Get interview level stats
collapse (firstnm) n_answer n_removed  rawdur_fstcompl cleandur_fstcompl length_pause  rawdurint  (sum) sect* cleandur , by(interview__id)
rename cleandur clean_durint

gen cleandur_min=clean_durint/60
gen rawdur_min=rawdurint/60
gen answ_pm=n_answer/cleandur_min 

local sections A B C D E F G H I J K L M N O P Q R S T U V W X YA YB YD YE YF YG YH YI YK YJ YL 
foreach s of local sections { 
	qui gen perc_dur_sec`s'=(sect`s'_dur/cleandur_min)*100 
}

graph hbar (mean) sect*_dur , blabel(bar, size(vsmall) format(%9.2g)) bargap(25) legend(size(small)) ytitle("Minutes", size(small))  ylabel(, labsize(small))  title("Average duration by section") //sections duration (absolute)
qui graph export "${gsdOutput}/section_duration.jpg", as(jpg) name("Graph") quality(100) replace

graph hbar (mean) perc_dur_sec* , blabel(bar, size(vsmall) format(%9.2g)) bargap(25) legend(size(small)) ytitle("%", size(small))  ylabel(, labsize(small))  title("Average proportion of interview time by section") //sections duration (absolute)
qui graph export "${gsdOutput}/section_relative_duration.jpg", as(jpg) name("Graph") quality(100) replace
	
lab var answ_pm "Answers per Minute"
lab var rawdurint "Raw duration of interview in seconds between first and last action" 
lab var rawdur_fstcompl "Raw duration of interview in seconds between first action and first completion"
lab var n_answer "Number of answers sets" 
lab var n_removed "Number of answers removed"
lab var clean_durint "Active time working on interview. Actions>`time' minutes & breaks are filtered out"
lab var cleandur_fstcompl"Active time betw. first act and first completion. Actions>`time' minutes & breaks filtered"
lab var length_pause  "Length in seconds interview was paused. Breaks>`pausetime' minutes are filtered out"
lab var cleandur_min "clean_durint in minutes"
lab var rawdur_min "rawdurint in minutes"

mmerge interview__id using "${gsdDataRaw}/KIHBS_2024_25_Pilot.dta", unmatched(none) ukeep(hhid_str) 
drop _merge 
qui save "${gsdDataRaw}/paradata.dta", replace

//Open raw questionnaire level data
use "${gsdDataRaw}//KIHBS_2024_25_Pilot.dta",clear

**# Dataset/variables preprocessing
qui destring version, replace //Form version
keep if inlist(version,1)
keep if !inlist(interview__status,65,125) //only retain non rejected interviews
clonevar submissiondate=tmlstact //Submissiondate
keep if consented==1

merge 1:1 interview__id using "${gsdDataRaw}//paradata.dta", nogen keep(1 3) //merge metavariables from paradata analysis

*Overall duration
qui replace interview__duration = subinstr(interview__duration,"00.","",.)
qui split interview__duration,p(":")
forval i=1/3{
	qui destring interview__duration`i', replace
}
qui gen duration_overall=(interview__duration1*60)+interview__duration2+(interview__duration3/60)
drop interview__duratio*
*Sections' duration 
local sections A B C D E F G H I J K L M N O P Q R S T U V W X YA YB YD YE YG YJ YL 
foreach s of local sections {
	qui replace InterviewStart_Sec`s' = subinstr(InterviewStart_Sec`s',"T"," ",.)
	qui replace InterviewEnd_Sec`s' = subinstr(InterviewEnd_Sec`s',"T"," ",.)
	
	qui generate double InterviewStart_Sec`s'_stata = clock(InterviewStart_Sec`s', "YMDhms")
	qui format InterviewStart_Sec`s'_stata %tc
	qui generate double InterviewEnd_Sec`s'_stata = clock(InterviewEnd_Sec`s', "YMDhms")
	qui format InterviewEnd_Sec`s'_stata %tc

	qui gen dur_sec_`s'=(InterviewEnd_Sec`s'_stata-InterviewStart_Sec`s'_stata)/60000
	qui replace dur_sec_`s'=. if dur_sec_`s'<0
}

egen duration_overall_sumsecs=rowtotal(dur_sec_*) 
summ duration_overall duration_overall_sumsecs
forval i=1/10 {
	qui replace dur`i'=dur`i'/60
}
decode A01, gen(county_name)
clonevar ea_name=A06
clonevar foname=responsible
qui decode A01,gen(county)
egen n_fitems=rowtotal(YA03_*)
isid hhid_str
qui save "${gsdDataRaw}//KIHBS_2024_pilot_completed.dta", replace

use "${gsdDataRaw}//KIHBS_2024_pilot_completed.dta", clear

gen prop_removed=(n_removed/n_answer)*100
gen prop_errors=(entities__errors/n_answer)*100

//Overall county level diagnostics
*Clean duration
betterbarci cleandur_min, over(A01) n format(%9.0f) bar ytitle("Minutes") title("Interview duration") subtitle("Active time") v saving("${gsdOutput}/cleandur_bycounty.gph", replace)
qui graph export "${gsdOutput}/cleandur_bycounty.jpg", as(jpg) name("Graph") quality(100) replace
*Raw duration
betterbarci rawdur_min, over(A01) n format(%9.0f) bar ytitle("Minutes") title("Interview duration") subtitle("Total (including lazy) time") v saving("${gsdOutput}/rawdur_bycounty.gph", replace) 
qui graph export "${gsdOutput}/rawdur_bycounty.jpg", as(jpg) name("Graph") quality(100) replace
*Number of answers per minute
betterbarci answ_pm, over(A01) n format(%9.1f) bar ytitle("N. Answers") title("Interviewer productivity") subtitle("Number of answers per minute") v 
qui graph export "${gsdOutput}/answpm_bycounty.jpg", as(jpg) name("Graph") quality(100) replace
*Proportion of answers removed
betterbarci prop_removed, over(A01) n format(%9.1f) bar ytitle("%") title("Proportion of answers removed") v pct saving("${gsdOutput}/answrem_bycounty.gph", replace) 
qui graph export "${gsdOutput}/answrem_bycounty.jpg", as(jpg) name("Graph") quality(100) replace
*Proportion of of errors
betterbarci prop_errors if entities__errors>10 & !mi(entities__errors), over(A01) n format(%9.1f) bar ytitle("%") title("Proportion of errors") v pct saving("${gsdOutput}/properrors_bycounty.gph", replace) 
qui graph export "${gsdOutput}/properrors_bycounty.jpg", as(jpg) name("Graph") quality(100) replace
*Number of unanswered questions 
betterbarci n_questions_unanswered if n_questions_unanswered>10 & !mi(n_questions_unanswered), over(A01) n format(%9.0f) bar title("Number of unanswered questions") v pct saving("${gsdOutput}/nunanswred_bycounty.gph", replace) 
qui graph export "${gsdOutput}/nunanswred_bycounty.jpg", as(jpg) name("Graph") quality(100) replace

//Enumerator level diagnostics, by county
set gr off
qui levelsof A01, loc(county)
foreach c of local county { //for each county
	qui levelsof county_name if A01==`c', loc(cname)
	dis in red "Create report for county "`cname'""

	*Clean duration
	betterbarci cleandur_min if A01==`c', over(A21) n format(%9.0f) bar ytitle("Minutes") title("Interview duration") subtitle("Active time") v saving("${gsdOutput}/cleandur_bycounty.gph", replace)
	qui graph export "${gsdOutput}/cleandur_county_`c'.jpg", as(jpg) name("Graph") quality(100) replace
	*Raw duration
	betterbarci rawdur_min if A01==`c', over(A21) n format(%9.0f) bar ytitle("Minutes") title("Interview duration") subtitle("Total (including lazy) time") v saving("${gsdOutput}/rawdur_bycounty.gph", replace) 
	qui graph export "${gsdOutput}/rawdur_county_`c'.jpg", as(jpg) name("Graph") quality(100) replace
	*Number of answers per minute
	betterbarci answ_pm if A01==`c', over(A21) n format(%9.1f) bar title("Number of answers per minute") subtitle("By enumerator") v saving("${gsdOutput}/answpm_county_`c'.gph", replace) 
	qui graph export "${gsdOutput}/answpm_county_`c'.jpg", as(jpg) name("Graph") quality(100) replace
	*Proportion of answers removed
	betterbarci prop_removed if A01==`c', over(A21) n format(%9.1f) bar ytitle("%") title("Proportion of answers removed") subtitle("By enumerator") v pct saving("${gsdOutput}/answrem_county_`c'.gph", replace) 
	qui graph export "${gsdOutput}/answrem_county_`c'.jpg", as(jpg) name("Graph") quality(100) replace
	*Proportion of of errors
	betterbarci prop_errors if  A01==`c', over(A21) n format(%9.1f) bar ytitle("%") title("Proportion of errors") v pct saving("${gsdOutput}/properrors_county_`c'.gph", replace) 
	qui graph export "${gsdOutput}/properrors_county_`c'.jpg", as(jpg) name("Graph") quality(100) replace
	*Number of unanswered questions 
	betterbarci n_questions_unanswered if  A01==`c', over(A21) n format(%9.0f) bar title("Number of unanswered questions") v pct saving("${gsdOutput}/nunanswred_county_`c'.gph", replace) 
	qui graph export "${gsdOutput}/nunanswred_county_`c'.jpg", as(jpg) name("Graph") quality(100) replace	
	
	*Create county specific workbook with diagnostics ind all pics in unit specific folder
	preserve 
	qui filelist, dir("${gsdOutput}/") //find graphs
	qui keep if regexm(filename,"_county_`c'.jpg") //retain county specific graphs
	qui gen picture=dirname+"/"+filename 
	qui photobook picture using "${gsdTemp}/Report_county_`c'.pdf", replace linebreak(3) pagesize(A4) ncol(2) title("County `c'") border(end, single, green) //create workbook
	restore
}

*Selected section durations
// H Domestic tourism	H01==1
preserve 
use "${gsdDataRaw}/household_roster.dta", clear
bys interview__key: egen H01_hh=max(H01)
duplicates drop interview__key, force
tempfile dom_tourism
qui save `dom_tourism', replace
restore 
merge 1:1 interview__key using `dom_tourism', keepusing(H01_hh) keep(1 3) nogen
betterbarci sectH_dur if H01_hh==1, over(A01) n format(%9.0f) v bar ytitle("Minutes") title("Duration Section H | Domestic tourism") 
qui graph export "${gsdOutput}/sec_H_dur.jpg", as(jpg) name("Graph") quality(100) replace	
betterbarci sectH_dur if H01_hh==1 & A16<=7, over(A16) n format(%9.0f) v bar ytitle("Minutes") title("Duration Section H | Domestic tourism") 
qui graph export "${gsdOutput}/sec_H_dubyhhsize.jpg", as(jpg) name("Graph") quality(100) replace	

// L Land ownership and tenure	L01==1
betterbarci L01, over(A01) n  v bar title("Proportion of houshold having land") pct yscale(off)
betterbarci sectH_dur if L01==1, over(A01) n format(%9.0f) v bar ytitle("Minutes") title("Duration Section L | Land ownership and tenure") 
qui graph export "${gsdOutput}/sec_L_dur.jpg", as(jpg) name("Graph") quality(100) replace	

// M	Agriculture	L01==1 & parcel_roster.Count(x=>x.L07.ContainsAny(1,2,7))
preserve 
use "${gsdDataRaw}/parcel_roster.dta", clear
gen x=L07__1==1 | L07__2==1 | L07__7==1
bys interview__key: egen L07_hh=max(x)
duplicates drop interview__key, force
tempfile climate
qui save `climate', replace
restore 
merge 1:1 interview__key using `climate', keepusing(L07_hh) keep(1 3) nogen
betterbarci sectM_dur if L07_hh==1, over(A01) n format(%9.0f) v bar ytitle("Minutes") title("Duration Section M | Land ownership and tenure") 
qui graph export "${gsdOutput}/sec_M_dur.jpg", as(jpg) name("Graph") quality(100) replace	
 
// N	Agricultural input and output	(seemingly no enabling condition?)
betterbarci sectN_dur if L01==1, over(A01) n format(%9.0f) v bar ytitle("Minutes") title("Duration Section N | Agri input/output") 

// O	Livestock	O01==1
betterbarci O01, over(A01) n  v bar title("Proportion of houshold having livestock") pct yscale(off)
betterbarci sectO_dur if O01==1, over(A01) n format(%9.0f) v bar ytitle("Minutes") title("Duration Section O | Livestock") 
qui graph export "${gsdOutput}/sec_O_dur.jpg", as(jpg) name("Graph") quality(100) replace	

// P	Enterprises	P02==1
betterbarci P02, over(A01) n  v bar title("Proportion of houshold having enterprise") pct yscale(off)
betterbarci sectP_dur if P02==1, over(A01) n format(%9.0f) v bar ytitle("Minutes") title("Duration Section P | Enterprise") 
qui graph export "${gsdOutput}/sec_P_dur.jpg", as(jpg) name("Graph") quality(100) replace	

// Q	Transfers	Q01==1 | Q08==1
betterbarci Q01, over(A01) n  v bar title("Proportion of houshold reporting transfer") pct yscale(off)
betterbarci Q08, over(A01) n  v bar title("Proportion of houshold giving enterprise") pct yscale(off)
betterbarci sectQ_dur if Q01==1 | Q08==1, over(A01) n format(%9.0f) v bar ytitle("Minutes") title("Duration Section Q | Transfers") 
qui graph export "${gsdOutput}/sec_Q_dur.jpg", as(jpg) name("Graph") quality(100) replace	

// T	Climate extremes	T03!=1
preserve 
use "${gsdDataRaw}/climate1_roster.dta", clear
gen x=T03!=1
bys interview__key: egen T03_hh=max(x)
duplicates drop interview__key, force
tempfile climate
qui save `climate', replace
restore 
merge 1:1 interview__key using `climate', keepusing(T03_hh) keep(1 3) nogen
betterbarci T03_hh, over(A01) n  v bar title("Proportion of household w/ climate shocks") pct yscale(off)
betterbarci sectT_dur if T03_hh==1, over(A01) n format(%9.0f) v bar ytitle("Minutes") title("Duration Section T | Climate shocks") 
qui graph export "${gsdOutput}/sec_T_dur.jpg", as(jpg) name("Graph") quality(100) replace	





betterbar sectF_dur dur_sec_F if A16<10, over(A16) n format(%9.2f)
betterbar sectF_dur dur_sec_F if A16<10, over(A16) n format(%9.2f)

betterbar sectF_dur dur_sec_F if A16<10, over(A16) n format(%9.2f)
















ex
*Set globals for data monitoring and cleaning
global id interview__key 
global date submissiondate
global duration duration_overall
global consent consented
global formv version
global fo foname
global sfo sprvsr 
global keepvars hhid county ea_name sprvsr interview__key

**# Progress report: coverage of households within each County
*Erase exsisting file
cap confirm file "${gsdOutput}/hfc_output/pilot/progreport_bycounty_pilot.xlsx"
if !_rc {
	qui rm "${gsdOutput}/hfc_output/pilot/progreport_bycounty_pilot.xlsx"
}
preserve 
use "${gsdData}/0-RawOutput/pilot/sample_pilot.dta", clear 
gen cty="MOMBASA" if A01=="1"
replace cty="KWALE" if A01=="2"
replace cty="GARISSA" if A01=="07"
replace cty="MARSABIT" if A01=="10"
replace cty="MAKUENI" if A01=="17"
replace cty="MURANG'A" if A01=="21"
replace cty="TURKANA" if A01=="23"
replace cty="UASIN GISHU" if A01=="27"
replace cty="NAKURU" if A01=="32"
replace cty="KAKAMEGA" if A01=="37"
replace cty="MIGORI" if A01=="44"
replace cty="NAIROBI CITY" if A01=="47"
mdesc cty
tempfile sample
qui save `sample', replace 
restore 
decode A01,gen(cty)
replace cty=upper(cty)
qui progreport, master(`sample') survey("${gsdDataRaw}//KIHBS_2024_pilot_completed.dta") id(hhid_str) sortby(cty) keepmaster(_responsible) keepsurvey(A21 A22  GEOCODE A06 A09 A10 A11 interview__status has__errors n_questions_unanswered n_fitems total_kcal_pp_pd) surveyok filename("${gsdOutput}/hfc_output/pilot/progreport_bycounty_pilot.xlsx") 

**# Enumerator dashboard with productivity statistics
capture confirm file "${gsdOutput}/hfc_output/pilot/enumdb_pilot.xlsx"
if !_rc {
	qui rm "${gsdOutput}/hfc_output/pilot/enumdb_pilot.xlsx"
}
ipacheckenumdb using "${gsdDo}/hfc/hfc_inputs_hh_pilot.xlsm", formv(version) dur(duration_overall) cons(consented, 1)  enum(responsible) team(county) date(submissiondate) outf("${gsdOutput}/hfc_output/pilot/enumdb_pilot.xlsx") sheetrep other(*_other) dontknow(-98,"know") ref(-99, "refuse")
lab var n_fitems "Number of food items reported"
lab var duration_overall "Survey duration (mins)"
lab var dur_sec_A "Duration section A (mins)"
lab var dur_sec_B "Duration section B (mins)"
lab var dur_sec_C "Duration section C (mins)"
tabstatxls duration_overall	dur_sec_A	dur_sec_B	dur_sec_C	rejections__sup	rejections__hq 	has__errors	n_questions_unanswered	n_fitems	total_kcal_pp_pd	answ_pm	consented, stat(min mean max) c(s) by(sprvsr) xlsfile("${gsdOutput}/hfc_output/pilot/enumdb_pilot.xlsx") sheetmodify cell(A40) sheet(enumstats)

**# Food consolidate
local foodtas cereals meat oil_fats fruits veges sugars alcohtobac //for each food category dataset 
foreach f of local foodtas {
	use "${gsdDataRaw}//`f'.dta",clear //open dta
	*Store the value labels for 2 variables that need a single value label
	decode q2_purch_unit_`f',gen(q2_purch_unit_`f'_s) //convert to string the label
	decode q3_cons_unit_tot_`f',gen(q3_cons_unit_tot_`f'_s)	//convert to string the label
	qui renvars, subs(_`f' ) //rename variables 
	qui renvars, subs(`f'_ food_ )
	gen original_food_data="`f'"
	tempfile `f'_dta
	qui save ``f'_dta', replace 

}
use `cereals_dta', clear 
qui append using `meat_dta' `oil_fats_dta' `fruits_dta' `veges_dta' `sugars_dta' `alcohtobac_dta'
//keep if inlist(original_food_data,"cereals", "meat", "oil_fats", "fruits",  "veges", "alcohtobac")
//keep if inlist(original_food_data,"meat", "alcohtobac")
qui duplicates drop *, force 
drop rowcode*
label drop q2_purch_unit_cereals
label drop q3_cons_unit_tot_cereals
replace q3_cons_unit_tot=q3_cons_unit_tot*food__id if q3_cons_unit_tot==5 & food__id==2105
replace q3_cons_unit_tot=q3_cons_unit_tot*food__id if q3_cons_unit_tot==5 & food__id==2106
labmask q2_purch_unit, val(q2_purch_unit_s)
labmask q3_cons_unit_tot, val(q3_cons_unit_tot_s)

drop q2_purch_unit_s q3_cons_unit_tot_s
tempfile food_1 
qui save `food_1', replace 
*Import food id labels from the category files 
local foodtas cereals_items alcohol_tobac fruits_nutsitems meats_fishitems oil_fatsitems sugars_items veges_items 
foreach f of local foodtas { 
	import excel "${gsdDataRaw}\[`f']KIHBS 2024 25 Pilot Survey", sheet("Categories") firstrow clear
	qui save "${gsdTemp}\categories_values_`f'.dta", replace 
}
use "${gsdTemp}\categories_values_cereals_items.dta", clear 
append using "${gsdTemp}\categories_values_alcohol_tobac.dta" "${gsdTemp}\categories_values_fruits_nutsitems.dta" "${gsdTemp}\categories_values_meats_fishitems.dta" "${gsdTemp}\categories_values_oil_fatsitems.dta" "${gsdTemp}\categories_values_sugars_items.dta" "${gsdTemp}\categories_values_veges_items.dta"
qui duplicates drop *, force 
isid value
gen food__id=value
labmask food__id, value(title)
tempfile food_id_labels 
qui save `food_id_labels', replace 

use `food_1', clear 
merge m:1 food__id using `food_id_labels',  keepusing(title) nogen keep(1 3) update
merge m:1 interview__id using "${gsdDataRaw}//KIHBS_2024_pilot_completed.dta", keep(3) nogen keepusing(total_kcal_* responsible YB_hh__*) //only keep validated interviews
egen a=rowtotal(YB_hh__*)
gen foodaway_hh=a>0 & !mi(a)
preserve 
use "${gsdDataRaw}//household_roster.dta", clear 
collapse (sum) YB__*,by(interview__id)
egen a=rowtotal(YB__*)
gen foodaway_hhr=a>0 & !mi(a)
tempfile foodaway
qui save `foodaway', replace 
restore 
merge m:1 interview__id using `foodaway', keep(3) nogen keepusing(foodaway_hhr) //only keep validated interviews
drop title
qui save "${gsdRawOutput}/pilot/KIHBS24_pilot_fooditems.dta", replace 
 
twoway kdensity total_kcal_pp_pd if total_kcal_pp_pd<30000 & (foodaway_hh==0 & foodaway_hhr==0),by(A15)
tabstat total_kcal_pp_pd if total_kcal_pp_pd<30000 & (foodaway_hh==0 & foodaway_hhr==0),by(A15) s(min mean median max)

**# Non-food consolidate
*Harmonize 7 days recall data
use "${gsdDataRaw}//YD_7d_expenses.dta", clear 
renvars, subs(_7d )
renvars, subs(YD nf_ )
decode nf__expenses__id, gen(nf__expenses__id_s)
gen recall=1
tempfile nf_yd
qui save `nf_yd', replace
*Harmonize 1 month recall data
local secs_m1 YE YF 
foreach s of local secs_m1 {
	use "${gsdDataRaw}//`s'_1m_expenses.dta", clear 
	renvars, subs(_1m )
	renvars, subs(`s' nf_ )
	decode nf__expenses__id, gen(nf__expenses__id_s)
	gen recall=2
	tempfile nf_`s'
	qui save `nf_`s'', replace
}
*Harmonize 6 months recall data
local secs_m6 YG YH YI 
foreach s of local secs_m6 {
	use "${gsdDataRaw}//`s'_6m_expenses.dta", clear 
	renvars, subs(_6m )
	renvars, subs(`s' nf_ )
	decode nf__expenses__id, gen(nf__expenses__id_s)
	gen recall=3
	tempfile nf_`s'
	qui save `nf_`s'', replace
}
*Harmonize 12 months recall data
local secs_m12 YJ YK  
foreach s of local secs_m12 {
	use "${gsdDataRaw}//`s'_12m_expenses.dta", clear 
	renvars, subs(_12m )
	renvars, subs(`s' nf_ )
	decode nf__expenses__id, gen(nf__expenses__id_s)
	gen recall=4
	tempfile nf_`s'
	qui save `nf_`s'', replace
}
*Put it altogether and finalize
use `nf_yd', clear 
qui append using `nf_YE' `nf_YF' `nf_YG' `nf_YH' `nf_YI' `nf_YJ' `nf_YK'
qui labmask nf__expenses__id, val(nf__expenses__id_s)
lab def recall 1 "Past 7 days" 2 "Past 1 month" 3 "Past 6 months" 4 "Past 12 months"
lab val recall recall 
qui missings dropvars *, force
drop nf__expenses__id_s
qui save "${gsdRawOutput}/pilot/KIHBS24_pilot_nfooditems.dta", replace 

**# Durables consolidate
*Harmonize 7 days recall data
use "${gsdDataRaw}//r_Durables_Expenditures.dta", clear 
qui save "${gsdRawOutput}/pilot/KIHBS24_pilot_durables.dta", replace 

**# Household member roster
use "${gsdDataRaw}//household_roster.dta", clear 
*Compute adult equivalent 
gen pre_adq_scale = .
replace pre_adq_scale=0.24   if inrange(age_years,0,4)
replace pre_adq_scale=0.65   if inrange(age_years,5,14)
replace pre_adq_scale=1.00   if inrange(age_years,15,112)
bys interview__id: egen adq_scale = sum(pre_adq_scale)
label var adq_scale "Adult Equivalent Scale"
*Compute total expenses on food away from home
egen fafh_hhmr=rowtotal(YB03a_* YB03b_*) 
bys interview__id: egen fafh_hhm = sum(fafh_hhmr)
*Compute total household expenses on education (full year)
egen edu_exp_hhmr=rowtotal(total_expenses total_expenses_assisted) 
bys interview__id: egen edu_exp = sum(edu_exp_hhmr)
qui save "${gsdRawOutput}/pilot/household_roster.dta", replace 

**# Climatic shocks 
use "${gsdDataRaw}//climate1_roster.dta", clear 
qui save "${gsdRawOutput}/pilot/climate.dta", replace 
