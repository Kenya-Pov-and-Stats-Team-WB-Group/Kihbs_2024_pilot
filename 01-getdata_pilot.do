clear all
set gr off 

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
	qui egen n_answers_sect`s'=nvals(variable) if event=="AnswerSet" & !mi(sect`s'_dur), by(interview__id)
}
// A few manual fixes for variables that did not conform to naming scheme
*Both to section duration
replace sectA_dur = cleandur/60 if regexm(variable,"consen")
replace sectYA_dur = cleandur/60 if regexm(variable,"_cons_|purch|q1_") 
*And to number of answered question per section (only sect A and sect YA have issue)
egen n_answers_sectA_1=nvals(variable) if event=="AnswerSet" & regexm(variable,"consen"), by(interview__id)
bys interview__id: egen x=mean(n_answers_sectA)
bys interview__id: egen y=mean(n_answers_sectA_1)
replace n_answers_sectA=x+y
egen n_answers_sectYA_1=nvals(variable) if event=="AnswerSet" & regexm(variable,"_cons_|purch|q1_") , by(interview__id)
bys interview__id: egen a=mean(n_answers_sectYA)
bys interview__id: egen b=mean(n_answers_sectYA_1)
replace n_answers_sectYA=a+b
drop a b x y
egen  nmiss =rowmiss(sectA_dur- sectYL_dur)
//br variable sectA_dur- sectYL_dur nmiss if nmiss>34

//Flag fertility subsection questions in section E
qui gen sectE_f_dur = cleandur/60 if regexm(variable,"E25|E26|E27|E28A|E28|E28B") 

//Flag deaths subsection questions in section E
qui gen sectE_d_dur = cleandur/60 if regexm(variable,"E59|E60B|E60_C_1|E60_C_2|E60_D|E60_E|E61a|E61b|E61b_Other|E62|E62_Other|E63|E63_Other") 

//Get interview level stats
collapse (firstnm) n_answer n_removed  rawdur_fstcompl cleandur_fstcompl length_pause  rawdurint  n_answers_sect* (sum) sect* cleandur sectE_fertility_dur=sectE_f_dur sectE_deaths_dur=sectE_d_dur, by(interview__id)
rename cleandur clean_durint

gen cleandur_min=clean_durint/60
gen rawdur_min=rawdurint/60
gen answ_pm=n_answer/cleandur_min 

local sections A B C D E F G H I J K L M N O P Q R S T U V W X YA YB YD YE YF YG YH YI YK YJ YL 
foreach s of local sections { 
	qui gen perc_dur_sec`s'=(sect`s'_dur/cleandur_min)*100 
	qui gen answ_pm_sect`s'= n_answers_sect`s'/sect`s'_dur
	lab var answ_pm_sect`s' "`s'"
}
	
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
//Bring in household id
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
betterbar consented, over(A01) n v bar title("Gross response rate") pct yscale(off) xlab("") note("Household response over total households")
qui graph export "${gsdOutput}/grossresponse_bycounty.jpg", as(jpg) name("Graph") quality(100) replace
betterbar consented if inlist(a1_visitstatus,1,2,3), over(A01) n  v bar title("Net response rate") pct yscale(off) xlab("") note("Household response over households found")
qui graph export "${gsdOutput}/netresponse_bycounty.jpg", as(jpg) name("Graph") quality(100) replace
keep if consented==1

*Code for accurately auto-rejecting interviews with validation errors
preserve 
use "${gsdDataRaw}/interview__errors.dta", clear 
gen true_error=!regexm(variable,"YA03_alcohtob|_purch_cost_")
gen error="Variables with error: "
qui levelsof interview__key,loc(household)
foreach h of local household {
	qui levelsof variable if interview__key=="`h'" & true_error==1, loc(errors)
	foreach e of local errors {
		qui replace error=error+"`e' ;  " if interview__key=="`h'"
	}
}
br variable true_error
collapse (firstnm) error (mean) true_error,by(interview__key interview__id)
gen to_reject=true_error>0
drop true_error
tempfile error_rejections 
qui save `error_rejections', replace
restore 
* Reject submissions with errors and unanswered questions
merge 1:1 interview__id using `error_rejections', keep(1 3) nogen keepusing(to_reject)
sursol rejectHQ if entities__errors>=1000000000 & !mi(entities__errors) & to_reject==1, server("https://emass1991-demo.mysurvey.solutions/primary/") user("emanuele_api") password("Emanuele_api1") id(interview__id) comment("You have at least 1 error in your form, please recheck and complete once the screen is GREEN") //more than X errors trigger rejection
sursol rejectHQ if n_questions_unanswered>=1000000000 & !mi(n_questions_unanswered), server("https://emass1991-demo.mysurvey.solutions/primary/") user("emanuele_api") password("Emanuele_api1") id(interview__id) comment("You have at least 1 unanswered field in your form, please recheck and complete once the screen is GREEN") //more than X unanswered question triggers rejection

merge 1:1 interview__id using "${gsdDataRaw}//paradata.dta", nogen keep(1 3) //merge metavariables from paradata analysis

decode A01, gen(county_name)
clonevar ea_name=A06
clonevar foname=responsible
qui decode A01,gen(county)
egen n_fitems=rowtotal(YA03_*)
recode A01 (1/6=1) (7/9=2) (10/17=3) (18/22=4) (23/36=5) (37/40=6) (41/46=7) (47=8), gen(province)
lab def province 1 "Coast" 2 "North-Eastern" 3 "Eastern" 4 "Central" 5 "Rift Valley" 6 "Western" 7 "Nyanza" 8 "Nairobi"
lab val province province

gen prop_removed=(n_removed/n_answer)*100
gen prop_errors=(entities__errors/n_answer)*100
qui outdetect answ_pm_sectS,best replace force
bys A01: egen mean_apmS=mean(answ_pm_sectS)
replace answ_pm_sectS=mean_apmS if inlist(_out,1,2)
betterbar answ_pm_sectA answ_pm_sectB answ_pm_sectC answ_pm_sectY* answ_pm_sectD-answ_pm_sectX,  n format(%9.1f) v bar title("Answers per minute") subtitle("By section") xlab("")
qui graph export "${gsdOutput}/answers_perminute_bysection.jpg", as(jpg) name("Graph") quality(100) replace

graph hbar (mean) sectA_dur sectB_dur sectC_dur sectY*_dur sectD_dur- sectX_dur , blabel(bar, size(vsmall) format(%9.2g)) bargap(25) legend(size(small)) ytitle("Minutes", size(small))  ylabel(, labsize(small))  title("Average duration by section") legend(order(1 "A: Household identification" 2 "B: Household roster" 3 "C: Education" 4 "YA: Food at home" 5 "YB: Food away from home" 6 "YD: Non-food (past 7 days)" 7 "YE: Non-food (past 1 month)" 8 "YF: Non-food (past 1 month)" 9 "YG: Non-food (past 6 monts)" 10 "YH: Non-food (past 6 monts)" 11 "YI: Non-food (past 6 monts)" 12 "YJ: Non-food (past 12 monts)" 13 "YK: Non-food (past 12 monts)" 14 "YL: Durables" 15 "D: Labour" 16 "E: Health" 17 "F: Anthropometry" 18 "G: ICT" 19 "H: Domestic tourism" 20 "I: Credit" 21 "J: Housing" 22 "K: Water/Sanitation" 23 "L: Land ownership" 24 "M: Agri holding" 25 "N: Agri input/output" 26 "O: Livestock" 27 "P: Household enterprise" 28 "Q: Transfers" 29 "R: Other incomes" 30 "S: Recent shocks" 31 "T: Climate extremes" 32 "U: Food security" 33 "V: Household justice" 34 "W: Household ICT" 35 "X: Social protection") size(vsmall)) //sections duration (absolute)
qui graph export "${gsdOutput}/section_duration.jpg", as(jpg) name("Graph") quality(100) replace
graph hbar (mean) perc_dur_sec* , blabel(bar, size(vsmall) format(%9.2g)) bargap(25) legend(size(small)) ytitle("%", size(small))  ylabel(, labsize(small))  title("Average proportion of interview time by section") //sections duration (absolute)
qui graph export "${gsdOutput}/section_relative_duration.jpg", as(jpg) name("Graph") quality(100) replace

*Import the RISSK results and merge them into survey data
preserve 
qui import delimited "${gsdDataRaw}/\output_file.csv", clear
qui save "${gsdRawOutput}/pilot/output_file.dta", replace
restore
merge 1:1 interview__id using "${gsdRawOutput}/pilot/output_file.dta", nogen keep(3) keepusing(unit_risk_score)
isid hhid_str
betterbarci unit_risk_score , over(A01) v n format(%9.1f) bar title("Risk score") subtitle("By county") xlab("") ytitle("Risk score") note(Risk score indicator ranges between 0 (no risk) to 100 (highest risk))
qui graph export "${gsdOutput}/risk_score_bycounty.jpg", as(jpg) name("Graph") quality(100) replace	

qui save "${gsdDataRaw}//KIHBS_2024_pilot_completed.dta", replace



*Selected section durations
use "${gsdDataRaw}//KIHBS_2024_pilot_completed.dta", clear 

lab var  sectA_dur "SECTION A: HOUSEHOLD IDENTIFICATION"
lab var  sectB_dur "SECTION B: HOUSEHOLD ROSTER"
lab var  sectC_dur "SECTION C: EDUCATION"
lab var  sectYA_dur "SECTION YA: WITHIN-HOUSEHOLD FOOD CONSUMPTION & EXPENDITURE OVER THE PAST 7 DAYS"
lab var  sectYB_dur "SECTION YB: MEALS TAKEN OUTSIDE THE HOUSEHOLD DURING THE LAST 7 DAYS"
lab var  sectYD_dur "SECTION YD: FREQUENTLY PURCHASED/CONSUMED NON-FOOD EXPENDITURES - 7 DAY RECALL PERIOD"
lab var  sectYE_dur "SECTION YE: NON-FOOD EXPENDITURES 1 MONTH RECALL PERIODS (P1)"
lab var  sectYF_dur "SECTION YF: NON-FOOD EXPENDITURES 1 MONTH RECALL PERIODS (P2)"
lab var  sectYG_dur "SECTION YG : NON-FOOD EXPENDITURES 6 MONTH RECALL PERIODS" 
lab var  sectYH_dur "SECTION YH: NON-FOOD EXPENDITURES 6 MONTH RECALL PERIODS" 
lab var sectYL_dur "SECTION YL: DURABLES EXPENDITURES"
lab var  sectYI_dur "SECTION YI: NON-FOOD EXPENDITURES 6 MONTH RECALL PERIODS" 
lab var sectYK_dur "SECTION YK: SEMI-DURABLES EXPENDITURE 12 MONTHS (P1)"
lab var sectYJ_dur "SECTION YJ: SEMI-DURABLES EXPENDITURE 12 MONTHS (P2)"
lab var  sectD_dur "SECTION D: LABOUR" 
lab var  sectE_dur "SECTION E: HEALTH, FERTILITY, HEALTH INSURANCE AND DISABILITY" 
lab var  sectF_dur "SECTION F: ANTHROPOMETRY" 
lab var  sectG_dur "SECTION G: ICT SERVICE BY HOUSEHOLD INDIVIDUAL MEMBERS" 
lab var  sectH_dur "SECTION H: DOMESTIC TOURISM" 
lab var  sectI_dur "SECTION I: CREDIT AND FINANCIAL INCLUSION" 
lab var  sectJ_dur "SECTION J: HOUSING" 
lab var  sectK_dur "SECTION K:  WATER, SANITATION AND ENERGY" 
lab var  sectL_dur "SECTION L: LAND OWNERSHIP AND TENURE" 
lab var  sectM_dur "SECTION M: AGRICULTURE HOLDING" 
lab var  sectN_dur "SECTION N:  AGRICULTURE INPUT AND OUTPUT" 
lab var  sectO_dur "SECTION O: LIVESTOCK" 
lab var  sectP_dur "SECTION P: HOUSEHOLD ENTERPRISES" 
lab var  sectQ_dur "SECTION Q: TRANSFERS" 
lab var  sectR_dur "SECTION R: OTHER INCOMES" 
lab var  sectS_dur "SECTION S: RECENT SHOCKS TO HOUSEHOLD WELFARE" 
lab var  sectT_dur "SECTION T: CLIMATE EXTREMES: CURRENT EXPERIENCE, PAST EXPERIENCE & FUTURE EXPECTATIONS" 
lab var  sectU_dur "SECTION U: FOOD SECURITY - LAST 12 MONTHS" 
lab var  sectV_dur "SECTION V: HOUSEHOLD JUSTICE MODULE" 
lab var  sectW_dur "SECTION W: HOUSEHOLD ICT AND E-WASTE" 
lab var sectX_dur "SECTION X: SOCIAL PROTECTION"
lab var cleandur_min "Overall interview duration"
preserve 
drop sectE_f_dur sectE_d_dur sectE_f_dur sectE_d_dur
qui tabstat2excel sect* cleandur_min, filename("C:\Users\wb562201\OneDrive - WBG\Countries\Kenya\KEN_KIHBS_2024_pilot\Temp/sections_duration.xlsx")
restore

**# Progress report (by county) 
use "${gsdDataRaw}/sample_pilot.dta", clear 
destring A09, replace
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
destring A01, replace
labmask A01,values(cty)
gcollapse (nunique) A09, by(A01)
gen target=A09*12 
merge 1:m A01 using "${gsdDataRaw}//KIHBS_2024_pilot_completed.dta",force nogen 
encode interview__id, gen(interview__idn)
lab drop interview__idn
gcollapse (nunique) interview__idn (firstnm) target, by(A01)
gen completion_rate=(interview__idn/target)*100
clonevar countyid=A01
decode A01,gen(countylabel)
qui save "${gsdTemp}/cty_completion.dta", replace


qui cd "${gsdTemp}"
shp2dta using "${gsdDataRaw}/\kenyan_counties.shp", database(state_data) coordinates(state_coordinates) genid(id) gencentroids(c) replace
use "state_coordinates.dta", clear
geo2xy _Y _X,   projection( mercator) replace
local lon0 = r(lon0)
local f = r(f)
local a = r(a)
save "state_coordinates_mercator.dta", replace
use state_data,clear
merge 1:1 countyid using "${gsdTemp}/cty_completion.dta", keepusing(completion_rate countylabel) //keep(3)
save "state_data2",replace
gen labtype  = 1
append using state_data2
replace labtype = 2 if labtype==.
replace countylabel = string(completion_rate, "%3.1f") if labtype ==2
keep x_c y_c countylabel labtype
geo2xy  y_c x_c,   projection( mercator, `a' `f' `lon0' ) replace
save maplabels, replace
use state_data2,clear
spmap completion_rate using "state_coordinates_mercator.dta", id(id) fcolor(RdYlGn) ocolor(white ..) label(data(maplabels) xcoord(x_c)  ycoord(y_c) label(countylabel) by(labtype)  size(*0.85 ..) pos(12 0) ) cln(5) legenda(off) 



**# Progress report (by cluster, within each county)

lab def prefill 0 "Single layer" 1 "2 layered"
lab val prefill prefill
gen nat=1 
bys nat: egen sectYA_dur_nat_avg=mean(sectYA_dur)
betterbarci sectYA_dur, over(prefill) by(A15) n format(%9.1f) v bar ytitle("Minutes") subtitle("By residence") saving("${gsdTemp}/g1.gph", replace) legend(off)  xlab(3.5 "Rural" 12.5 "Urban")
betterbarci sectYA_dur,  n format(%9.1f) over(prefill) v bar ytitle("Minutes")  subtitle("National") saving("${gsdTemp}/g2.gph", replace) xlab("") 
gr combine "${gsdTemp}/g1.gph" "${gsdTemp}/g2.gph", ycom title("Duration Section YA | By approach")
qui graph export "${gsdOutput}/secYA_dur_byapproach.jpg", as(jpg) name("Graph") quality(100) replace	

//Food at home section 
betterbarci sectYA_dur, over(A01) n format(%9.0f) v bar title("Food at home section duration") subtitle("By county") xlab("")
qui graph export "${gsdOutput}/secYA_duration_bycounty.jpg", as(jpg) name("Graph") quality(100) replace	

**# Fertility asked to women in age range 15-49 i.e.: inrange(B05,15,49) & B04==1
preserve 
use "${gsdDataRaw}/household_roster.dta", clear
gen Women_15_49=inrange(B05,15,49) & B04==1
bys interview__key: egen Women_15_49_hh=max(Women_15_49)
duplicates drop interview__key, force
tempfile fertility
qui save `fertility', replace
restore 
*Duration of fertility subsection for hh where it's applicable
merge 1:1 interview__key using `fertility', keepusing(Women_15_49_hh) keep(1 3) nogen
betterbarci sectE_fertility_dur if Women_15_49_hh==1, over(A01) n format(%9.1f) v bar ytitle("Minutes") title("Duration Section E | Fertility subsection") xlab("")
qui graph export "${gsdOutput}/sec_E_fertility_dur.jpg", as(jpg) name("Graph") quality(100) replace	
**# Deaths 
*Proportion of health module's time spent on fertility subsection 
gen sectE_fert_prop=sectE_fertility_dur/sectE_dur*100
betterbarci sectE_fert_prop if Women_15_49_hh==1, over(A01) n format(%9.1f) v bar ytitle("Minutes") title("Duration Section E | Fertility subsection") xlab("")
*Duration of deaths subsection for hh where it's applicable
betterbarci sectE_fertility_dur if E58==1, over(A01) n format(%9.1f) v bar ytitle("Minutes") title("Duration Section E | Fertility subsection") xlab("")
qui graph export "${gsdOutput}/sec_E_deaths_dur.jpg", as(jpg) name("Graph") quality(100) replace	
*Proportion of health module's time spent on fertility subsection
gen sectE_deaths_prop=sectE_deaths_dur/sectE_dur*100 
qui summ sectE_deaths_prop if E58==1==1, d
betterbarci sectE_deaths_prop if E58==1==1, over(A01) n format(%9.1f) v bar ytitle("Minutes") title("Duration Section E | Deaths subsection") note("Overall: mean=`r(mean)'; median=`r(p50)'") xlab("")

**# H Domestic tourism	H01==1
preserve 
use "${gsdDataRaw}/household_roster.dta", clear
bys interview__key: egen H01_hh=max(H01)
duplicates drop interview__key, force
tempfile dom_tourism
qui save `dom_tourism', replace
restore 
merge 1:1 interview__key using `dom_tourism', keepusing(H01_hh) keep(1 3) nogen
betterbarci sectH_dur if H01_hh==1, over(A01) n format(%9.0f) v bar ytitle("Minutes") title("Duration Section H | Domestic tourism") xlab("")
qui graph export "${gsdOutput}/sec_H_dur.jpg", as(jpg) name("Graph") quality(100) replace	
betterbarci sectH_dur if H01_hh==1 & A16<=7, over(A16) n format(%9.0f) v bar ytitle("Minutes") title("Duration Section H | Domestic tourism") xlab("")
qui graph export "${gsdOutput}/sec_H_dubyhhsize.jpg", as(jpg) name("Graph") quality(100) replace	

**# L Land ownership and tenure	L01==1
betterbarci L01, over(A01) n  v bar title("Proportion of houshold having land") pct yscale(off) xlab("")
betterbarci sectL_dur if L01==1, over(A01) n format(%9.0f) v bar ytitle("Minutes") title("Duration Section L | Land ownership and tenure") xlab("")
qui graph export "${gsdOutput}/sec_L_dur.jpg", as(jpg) name("Graph") quality(100) replace	

**# M	Agriculture	L01==1 & parcel_roster.Count(x=>x.L07.ContainsAny(1,2,7))
preserve 
use "${gsdDataRaw}/parcel_roster.dta", clear
drop x L07_hh
gen x=L07__1==1 | L07__2==1 | L07__7==1
bys interview__key: egen L07_hh=max(x)
duplicates drop interview__key, force
tempfile agri
qui save `agri', replace
restore 
merge 1:1 interview__key using `agri', keepusing(L07_hh) keep(1 3) nogen
betterbarci sectM_dur if L07_hh==1, over(A01) n format(%9.0f) v bar ytitle("Minutes") title("Duration Section M | Land ownership and tenure") xlab("")
qui graph export "${gsdOutput}/sec_M_dur.jpg", as(jpg) name("Graph") quality(100) replace	
 
**# N	Agricultural input and output	(seemingly no enabling condition?)
betterbarci sectN_dur if L01==1, over(A01) n format(%9.0f) v bar ytitle("Minutes") title("Duration Section N | Agri input/output") xlab("")

**# O	Livestock	O01==1
betterbarci O01, over(A01) n  v bar title("Proportion of houshold having livestock") pct yscale(off) xlab("")
betterbarci sectO_dur if O01==1, over(A01) n format(%9.0f) v bar ytitle("Minutes") title("Duration Section O | Livestock") xlab("")
qui graph export "${gsdOutput}/sec_O_dur.jpg", as(jpg) name("Graph") quality(100) replace	

**# P	Enterprises	P02==1
betterbarci P02, over(A01) n  v bar title("Proportion of houshold having enterprise") pct yscale(off)
betterbarci sectP_dur if P02==1, over(A01) n format(%9.0f) v bar ytitle("Minutes") title("Duration Section P | Enterprise") 
qui graph export "${gsdOutput}/sec_P_dur.jpg", as(jpg) name("Graph") quality(100) replace	

**# Q	Transfers	Q01==1 | Q08==1
betterbarci Q01, over(A01) n  v bar title("Proportion of houshold reporting transfer") pct yscale(off) xlab("")
betterbarci Q08, over(A01) n  v bar title("Proportion of houshold giving enterprise") pct yscale(off) xlab("")
betterbarci sectQ_dur if Q01==1 | Q08==1, over(A01) n format(%9.0f) v bar ytitle("Minutes") title("Duration Section Q | Transfers") xlab("")
qui graph export "${gsdOutput}/sec_Q_dur.jpg", as(jpg) name("Graph") quality(100) replace	

**# T Climate extremes T03!=1
preserve 
use "${gsdDataRaw}/climate1_roster.dta", clear
gen x=T03!=1
bys interview__key: egen T03_hh=max(x)
duplicates drop interview__key, force
tempfile climate
qui save `climate', replace
restore 
merge 1:1 interview__key using `climate', keepusing(T03_hh) keep(1 3) nogen
betterbarci T03_hh, over(A01) n  v bar title("Proportion of household w/ climate shocks") pct yscale(off) xlab("")
betterbarci sectT_dur if T03_hh==1, over(A01) n format(%9.0f) v bar ytitle("Minutes") title("Duration Section T | Climate shocks") xlab("")
qui graph export "${gsdOutput}/sec_T_dur.jpg", as(jpg) name("Graph") quality(100) replace	

gen Q01_Q08=(Q01==1 | Q08==1 )
gen L01_a=L01
lab var Women_15_49_hh "Fertility"
lab var E58 "Deaths"
lab var H01_hh "Domestic tourism"
lab var L01 "Agri in/output"
lab var L01_a "Land ownership/tenure"
lab var L07_hh "Agriculture"
lab var O01 "Livestock"
lab var P02 "Enterprise"
lab var Q01_Q08" Transfers"
lab var T03_hh "Climate shocks"

betterbarci Women_15_49_hh E58 H01_hh L01 L01_a L07_hh O01 P02 Q01_Q08  T03_hh, n bar pct  ytitle("% of households") title("Selected sections' relevance")
qui graph export "${gsdOutput}/sections_relevance.jpg", as(jpg) name("Graph") quality(100) replace	

local letter L H N M N O P Q T 
foreach l of local letter {
	 cap qui gen sect`l'_prop=sect`l'_dur/cleandur_min
}   
tabstat sectE_fertility_dur sectE_fert_prop if Women_15_49_hh==1,s(mean median) //fertility
tabstat sectE_deaths_dur sectE_deaths_prop if E58==1,s(mean median) //Deaths
tabstat sectH_dur sectH_prop if H01_hh==1,s(mean median) //Domestic tourism
tabstat sectL_dur sectL_prop if L01==1,s(mean median) //Land ownership/tenure
tabstat sectN_dur sectN_prop if L01==1,s(mean median) //Agriculture input/output
tabstat sectM_dur sectM_prop if L07_hh==1,s(mean median) //Agriculture
tabstat sectO_dur sectO_prop if O01==1,s(mean median) //Livestock
tabstat sectP_dur sectP_prop if P02==1,s(mean median) //Enterprise
tabstat sectQ_dur sectQ_prop if Q01_Q08==1,s(mean median) //Transfers
tabstat sectT_dur sectT_prop if T03_hh==1,s(mean median) //Climate shocks
ex

//Overall county level diagnostics
use "${gsdDataRaw}//KIHBS_2024_pilot_completed.dta", clear

*Clean duration
betterbarci cleandur_min, over(A01) n format(%9.0f) bar ytitle("Minutes") title("Interview duration") subtitle("Active time") v saving("${gsdOutput}/cleandur_bycounty.gph", replace) xlab("")
qui graph export "${gsdOutput}/cleandur_bycounty.jpg", as(jpg) name("Graph") quality(100) replace
*Raw duration
betterbarci rawdur_min, over(A01) n format(%9.0f) bar ytitle("Minutes") title("Interview duration") subtitle("Total (including lazy) time") v saving("${gsdOutput}/rawdur_bycounty.gph", replace) xlab("")
qui graph export "${gsdOutput}/rawdur_bycounty.jpg", as(jpg) name("Graph") quality(100) replace
*Number of answers per minute
betterbarci answ_pm, over(A01) n format(%9.1f) bar ytitle("N. Answers") title("Number of answers per minute") v xlab("")
qui graph export "${gsdOutput}/answpm_bycounty.jpg", as(jpg) name("Graph") quality(100) replace
*Proportion of answers removed
betterbarci prop_removed, over(A01) n format(%9.1f) bar ytitle("%") title("Proportion of answers removed") v pct saving("${gsdOutput}/answrem_bycounty.gph", replace) xlab("")
qui graph export "${gsdOutput}/answrem_bycounty.jpg", as(jpg) name("Graph") quality(100) replace
*Proportion of of errors
betterbarci prop_errors if entities__errors>10 & !mi(entities__errors), over(A01) n format(%9.1f) bar ytitle("%") title("Proportion of errors") v pct saving("${gsdOutput}/properrors_bycounty.gph", replace) xlab("")
qui graph export "${gsdOutput}/properrors_bycounty.jpg", as(jpg) name("Graph") quality(100) replace
*Number of unanswered questions 
betterbarci n_questions_unanswered if n_questions_unanswered>10 & !mi(n_questions_unanswered), over(A01) n format(%9.0f) bar title("Number of unanswered questions") v pct saving("${gsdOutput}/nunanswred_bycounty.gph", replace) xlab("")
qui graph export "${gsdOutput}/nunanswred_bycounty.jpg", as(jpg) name("Graph") quality(100) replace

//Enumerator level diagnostics, by county
set gr off
qui levelsof A01, loc(county)
foreach c of local county { //for each county
	qui levelsof county_name if A01==`c', loc(cname)
	dis in red "Create report for county "`cname'""

	*Clean duration
	betterbarci cleandur_min if A01==`c', over(A21) n format(%9.0f) bar ytitle("Minutes") title("Interview duration") subtitle("Active time") v saving("${gsdOutput}/cleandur_bycounty.gph", replace) xlab("")
	qui graph export "${gsdOutput}/cleandur_county_`c'.jpg", as(jpg) name("Graph") quality(100) replace
	*Raw duration
	betterbarci rawdur_min if A01==`c', over(A21) n format(%9.0f) bar ytitle("Minutes") title("Interview duration") subtitle("Total (including lazy) time") v saving("${gsdOutput}/rawdur_bycounty.gph", replace) xlab("")
	qui graph export "${gsdOutput}/rawdur_county_`c'.jpg", as(jpg) name("Graph") quality(100) replace
	*Number of answers per minute
	betterbarci answ_pm if A01==`c', over(A21) n format(%9.1f) bar title("Number of answers per minute") subtitle("By enumerator") v saving("${gsdOutput}/answpm_county_`c'.gph", replace) xlab("")
	qui graph export "${gsdOutput}/answpm_county_`c'.jpg", as(jpg) name("Graph") quality(100) replace
	*Proportion of answers removed
	betterbarci prop_removed if A01==`c', over(A21) n format(%9.1f) bar ytitle("%") title("Proportion of answers removed") subtitle("By enumerator") v pct saving("${gsdOutput}/answrem_county_`c'.gph", replace) xlab("")
	qui graph export "${gsdOutput}/answrem_county_`c'.jpg", as(jpg) name("Graph") quality(100) replace
	*Proportion of of errors
	betterbarci prop_errors if  A01==`c', over(A21) n format(%9.1f) bar ytitle("%") title("Proportion of errors") v pct saving("${gsdOutput}/properrors_county_`c'.gph", replace) 
	qui graph export "${gsdOutput}/properrors_county_`c'.jpg", as(jpg) name("Graph") quality(100) replace
	*Number of unanswered questions 
	betterbarci n_questions_unanswered if  A01==`c', over(A21) n format(%9.0f) bar title("Number of unanswered questions") v pct saving("${gsdOutput}/nunanswred_county_`c'.gph", replace) xlab("")
	qui graph export "${gsdOutput}/nunanswred_county_`c'.jpg", as(jpg) name("Graph") quality(100) replace	
	
	*Create county specific workbook with diagnostics ind all pics in unit specific folder
	preserve 
	qui filelist, dir("${gsdOutput}/") //find graphs
	qui keep if regexm(filename,"_county_`c'.jpg") //retain county specific graphs
	qui gen picture=dirname+"/"+filename 
	qui photobook picture using "${gsdTemp}/Report_county_`c'.pdf", replace linebreak(3) pagesize(A4) ncol(2) title("County `c'") border(end, single, green) //create workbook
	restore
}


















*Set globals for data monitoring and cleaning
global id interview__key 
global date submissiondate
global duration duration_overall
global consent consented
global formv version
global fo foname
global sfo sprvsr 
global keepvars hhid county ea_name sprvsr interview__key

// **# Progress report: coverage of households within each County
// *Erase exsisting file
// cap confirm file "${gsdOutput}/hfc_output/pilot/progreport_bycounty_pilot.xlsx"
// if !_rc {
// 	qui rm "${gsdOutput}/hfc_output/pilot/progreport_bycounty_pilot.xlsx"
// }
// preserve 
// use "${gsdDataRaw}/sample_pilot.dta", clear 
// gen cty="MOMBASA" if A01=="1"
// replace cty="KWALE" if A01=="2"
// replace cty="GARISSA" if A01=="07"
// replace cty="MARSABIT" if A01=="10"
// replace cty="MAKUENI" if A01=="17"
// replace cty="MURANG'A" if A01=="21"
// replace cty="TURKANA" if A01=="23"
// replace cty="UASIN GISHU" if A01=="27"
// replace cty="NAKURU" if A01=="32"
// replace cty="KAKAMEGA" if A01=="37"
// replace cty="MIGORI" if A01=="44"
// replace cty="NAIROBI CITY" if A01=="47"
// mdesc cty
// tempfile sample
// qui save `sample', replace 
// restore 
// decode A01,gen(cty)
// replace cty=upper(cty)
// qui progreport, master(`sample') survey("${gsdDataRaw}//KIHBS_2024_pilot_completed.dta") id(hhid_str) sortby(cty) keepmaster(_responsible) keepsurvey(A21 A22  GEOCODE A06 A09 A10 A11 interview__status has__errors n_questions_unanswered n_fitems total_kcal_pp_pd) surveyok filename("${gsdOutput}/hfc_output/pilot/progreport_bycounty_pilot.xlsx") 

// **# Enumerator dashboard with productivity statistics
// capture confirm file "${gsdOutput}/hfc_output/pilot/enumdb_pilot.xlsx"
// if !_rc {
// 	qui rm "${gsdOutput}/hfc_output/pilot/enumdb_pilot.xlsx"
// }
// ipacheckenumdb using "${gsdDo}/hfc/hfc_inputs_hh_pilot.xlsm", formv(version) dur(duration_overall) cons(consented, 1)  enum(responsible) team(county) date(submissiondate) outf("${gsdOutput}/hfc_output/pilot/enumdb_pilot.xlsx") sheetrep other(*_other) dontknow(-98,"know") ref(-99, "refuse")
// lab var n_fitems "Number of food items reported"
// lab var duration_overall "Survey duration (mins)"
// lab var dur_sec_A "Duration section A (mins)"
// lab var dur_sec_B "Duration section B (mins)"
// lab var dur_sec_C "Duration section C (mins)"
// tabstatxls duration_overall	dur_sec_A	dur_sec_B	dur_sec_C	rejections__sup	rejections__hq 	has__errors	n_questions_unanswered	n_fitems	total_kcal_pp_pd	answ_pm	consented, stat(min mean max) c(s) by(sprvsr) xlsfile("${gsdOutput}/hfc_output/pilot/enumdb_pilot.xlsx") sheetmodify cell(A40) sheet(enumstats)

**# Food consolidate
local foodtas cereals meat oil_fats fruits veges sugars alcohtobac //for each food category dataset 
foreach f of local foodtas {
	use "${gsdDataRaw}//`f'.dta",clear //open dta
	//********* TEMPORARY, TO RESOLVE PROBLEM IN KWALE, NOT NEEDED IN FUTURE
		// Establish province
			recode A01 (1/6 = 1)(7/9 = 2)(10/17 = 3)(18/22 = 4)(23/36 = 5)(37/40 = 6)(41/46 = 7)(47=8), gen(prov)
		// Bring in conversion factors
			preserve
				if "`f'" == "alcohtobac" {
					qui import delimited "${gsdDataRaw}//alcohol_convfactors.txt", clear // Special case due to inconsistent naming
				}
				else {
					qui import delimited "${gsdDataRaw}//`f'_convfactors.txt", clear
				}
				clonevar rowcode_p = rowcode
				clonevar rowcode_c = rowcode
				tempfile cfs
				qui save `cfs'
			restore
		ren rowcode_*_p rowcode_p
		ren rowcode_*_c rowcode_c
		qui merge m:1 rowcode_p using `cfs', keep(match master) keepusing(rowcode_p conv_*) nogen
		// Apply relevant conversion factors
			forvalues p = 1/7 {
				qui replace qty_kglt_1_`f' = q3_purch_qty_`f'*conv_prov`p' if prov==`p'
			}
			qui replace unit_value = q3_purch_cost_`f'/qty_kglt_1_`f'
		// Now for consumption
			drop conv_*
			qui merge m:1 rowcode_c using `cfs', keep(match master) keepusing(rowcode_c conv_*) nogen
			// Apply relevant conversion factors
				forvalues p = 1/7 {
					qui replace qty_kglt_2_`f' = q3_cons_qty_tot_`f'*conv_prov`p' if prov==`p'
				}
				qui replace tot_kcal_cons_`f'_fi = qty_kglt_2_`f'*10*calories_coeff_`f'
				drop prov conv*
	//****************** END KWALE RESOLUTION 
	*Store the value labels for 2 variables that need a single value label
	decode q2_purch_unit_`f',gen(q2_purch_unit_`f'_s) //convert to string the label
	decode q3_cons_unit_tot_`f',gen(q3_cons_unit_tot_`f'_s)	//convert to string the label
	qui renvars, subs(_`f' ) //rename variables 
	qui renvars, subs(`f'_ food_ )
	qui gen original_food_data="`f'"
	//****************** TEMPORARY FIX FOR KWALE, NOT NEEDED IN FUTURE
		// Calculate aggregated calories by group
		qui egen total_kcal_cons_`f'_temp = sum(tot_kcal_cons_fi), by(interview__id)
	//****************** END KWALE RESOLUTION 

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
local foodtas_i cereals_items alcohol_tobac fruits_nutsitems meats_fishitems oil_fatsitems sugars_items veges_items 
foreach f of local foodtas_i { 
	qui import excel "${gsdDataRaw}\[`f']KIHBS 2024 25 Pilot Survey", sheet("Categories") firstrow clear
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
qui merge m:1 food__id using `food_id_labels',  keepusing(title) nogen keep(1 3) update
qui merge m:1 interview__id using "${gsdDataRaw}//KIHBS_2024_pilot_completed.dta", keep(3) nogen keepusing(total_kcal_* responsible YB_hh__* A16) //only keep validated interviews
	//****************** TEMPORARY FIX FOR KWALE, NOT NEEDED IN FUTURE
		foreach f of local foodtas {
			qui egen  total_kcal_cons_`f'_temp2 = max(total_kcal_cons_`f'_temp),by(interview__id)
			qui replace total_kcal_cons_`f'=total_kcal_cons_`f'_temp2 if total_kcal_cons_`f'_temp2!=.
			qui replace total_kcal_pp_pd_`f' = (total_kcal_cons_`f'/7)/A16
			drop total_kcal_cons_`f'_temp*
		}
	//******************* END KWALE FIX
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
egen x=rowtotal(total_kcal_pp_pd_*)
replace total_kcal_pp_pd=x if mi(total_kcal_pp_pd) & !mi(x)
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
	qui renvars, subs(_12m )
	qui renvars, subs(`s' nf_ )
	qui decode nf__expenses__id, gen(nf__expenses__id_s)
	qui gen recall=4
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
qui replace pre_adq_scale=0.24   if inrange(age_years,0,4)
qui replace pre_adq_scale=0.65   if inrange(age_years,5,14)
qui replace pre_adq_scale=1.00   if inrange(age_years,15,112)
qui bys interview__id: egen adq_scale = sum(pre_adq_scale)
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
