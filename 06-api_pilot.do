*This dofile imports the KIHBS 2024 Pilot data using the Surveysolutions API; NB: This requires to have R (version 4.0 and above) installed on your machine. However, no further R knowledge is required since the commands write the R scripts themselves and wraps the API R package  provided.
*In R, the required R package ("susoapi") is automatically installed.
clear all

**# Download the data via API
sursol export "KIHBS 2024 25 Pilot Survey", dir("${gsdTemp}/") server("https://kihbs.knbs.or.ke/kihbs") user(K1Hb5_Ap1) password(D1fFcu!t.in-G3tt1ng S0m3.d@ta) stata para versions(1)

**# Append versions of interest
qui sursol append "KIHBS_2024_25_Pilot", dir("${gsdTemp}/") export("${gsdDataRaw}/suso/pilot") server("https://kihbs.knbs.or.ke/kihbs") sortdesc copy(A01 A06 A09 A15 hhid_str)

**# Analyze paradata
 sursol para "KIHBS_2024_25_Pilot", directory("${gsdTemp}/") export("${gsdDataRaw}/suso/pilot") dur1(InterviewStart_SecA InterviewEnd_SecA) dur2(InterviewStart_SecB InterviewEnd_SecB) dur3(C01a C22) dur4(YA00 InterviewEnd_SecYA) dur5(InterviewStart_SecYB InterviewEnd_SecYB) dur6(InterviewStart_SecYD InterviewEnd_SecYD) dur7(YE_YF_01 InterviewEnd_SecYE_F) dur8(InterviewStart_SecYG_H_I InterviewEnd_SecYG_H_I) dur9(InterviewStart_SecYJ_YK InterviewEnd_SecYJ_K) dur10(InterviewStart_SecYL InterviewEnd_SecYL)  time(10)

// Remove supervisor questions from paradata
qui import delimited using "${gsdDataRaw}/suso/pilot/paradata_all.tab", clear

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

collapse (firstnm) n_answer n_removed  rawdur_fstcompl cleandur_fstcompl length_pause  rawdurint  (sum) sect* cleandur , by(interview__id)
rename cleandur clean_durint

g cleandur_min=clean_durint/60
g rawdur_min=rawdurint/60
g answ_pm=n_answer/cleandur_min 
	
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

mmerge interview__id using "${gsdDataRaw}/suso/pilot/KIHBS_2024_25_Pilot.dta", unmatched(none) ukeep(hhid_str) 
drop _merge 
qui save "${gsdDataRaw}/suso/pilot/paradata.dta", replace

**# Cleanup temp and raw data folder 
qui filelist, dir("${gsdTemp}") nor 
qui levelsof filename if regexm(filename,".zip"),local(filestoerase) 
foreach f of local filestoerase { 
	erase "${gsdTemp}/`f'" 
}
qui filelist, dir("${gsdDataRaw}/suso/pilot") nor 
qui levelsof filename if regexm(filename,"__"),local(filestoerase) 
foreach f of local filestoerase { 
	erase "${gsdDataRaw}/suso/pilot/`f'" 
	}

use "${gsdDataRaw}/suso/pilot/KIHBS_2024_25_Pilot.dta",clear
merge 1:1 interview__id using "${gsdDataRaw}/suso/pilot/paradata_overview.dta", nogen keep(1 3) assert(1 3) //merge metavariables from paradata analysis
merge 1:1 interview__id using "${gsdDataRaw}/suso/pilot/paradata.dta", nogen keep(1 3) assert(1 3) //merge metavariables from paradata analysis

**# Reject submissions with errors and unanswered questions 
sursol rejectHQ if entities__errors>=16 & !mi(entities__errors), server("https://kihbs.knbs.or.ke/kihbs") user("K1Hb5_Ap1") password("D1fFcu!t.in-G3tt1ng S0m3.d@ta") id(interview__id) comment("You have at least 1 error in your form, please recheck and complete once the screen is GREEN") //more than 1 errors trigger rejection
sursol rejectHQ if n_questions_unanswered>=100 & !mi(n_questions_unanswered) & consented==1, server("https://kihbs.knbs.or.ke/kihbs") user("K1Hb5_Ap1") password("D1fFcu!t.in-G3tt1ng S0m3.d@ta") id(interview__id) comment("You have at least 1 unanswered field in your form, please recheck and complete once the screen is GREEN") //more than 1 unanswered question triggers rejection

**# Dataset/variables preprocessing
qui destring version, replace //Form version
keep if inlist(version,1)
keep if !inlist(interview__status,65,125) //only retain non rejected interviews
clonevar submissiondate=tmlstact //Submissiondate
keep if consented==1

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
tabstat dur_sec_C sectC_dur dur3, s(median sd)
decode A01, gen(county_name)
clonevar ea_name=A06
clonevar foname=responsible
qui decode A01,gen(county)
egen n_fitems=rowtotal(YA03_*)
isid hhid_str
qui save "${gsdDataRaw}/suso/pilot/KIHBS_2024_pilot_completed.dta", replace

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
qui progreport, master(`sample') survey("${gsdDataRaw}/suso/pilot/KIHBS_2024_pilot_completed.dta") id(hhid_str) sortby(cty) keepmaster(_responsible) keepsurvey(A21 A22  GEOCODE A06 A09 A10 A11 interview__status has__errors n_questions_unanswered n_fitems total_kcal_pp_pd) surveyok filename("${gsdOutput}/hfc_output/pilot/progreport_bycounty_pilot.xlsx") 

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
	use "${gsdDataRaw}/suso/pilot/`f'.dta",clear //open dta
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
merge m:1 interview__id using "${gsdDataRaw}/suso/pilot/KIHBS_2024_pilot_completed.dta", keep(3) nogen keepusing(total_kcal_* responsible YB_hh__*) //only keep validated interviews
egen a=rowtotal(YB_hh__*)
gen foodaway_hh=a>0 & !mi(a)
preserve 
use "${gsdDataRaw}/suso/pilot/household_roster.dta", clear 
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
use "${gsdDataRaw}/suso/pilot/YD_7d_expenses.dta", clear 
renvars, subs(_7d )
renvars, subs(YD nf_ )
decode nf__expenses__id, gen(nf__expenses__id_s)
gen recall=1
tempfile nf_yd
qui save `nf_yd', replace
*Harmonize 1 month recall data
local secs_m1 YE YF 
foreach s of local secs_m1 {
	use "${gsdDataRaw}/suso/pilot/`s'_1m_expenses.dta", clear 
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
	use "${gsdDataRaw}/suso/pilot/`s'_6m_expenses.dta", clear 
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
	use "${gsdDataRaw}/suso/pilot/`s'_12m_expenses.dta", clear 
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
use "${gsdDataRaw}/suso/pilot/r_Durables_Expenditures.dta", clear 
qui save "${gsdRawOutput}/pilot/KIHBS24_pilot_durables.dta", replace 

**# Household member roster
use "${gsdDataRaw}/suso/pilot/household_roster.dta", clear 
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
use "${gsdDataRaw}/suso/pilot/climate1_roster.dta", clear 
qui save "${gsdRawOutput}/pilot/climate.dta", replace 
