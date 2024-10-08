*This dofile imports the KIHBS 2024 data using the Surveysolutions API; NB: This requires to have R (version 4.0 and above) installed on your machine. However, no further R knowledge is required since the commands write the R scripts themselves and wraps the API R package  provided.
*In R, the required R package ("susoapi") is automatically installed.
clear all

**# Download the data via API
//sursol export "KIHBS 2024 2025 Survey Working Copy", dir("${gsdTemp}/") server("https://emass1991-demo.mysurvey.solutions/primary/") user(${username_api}) password(${password_api}) stata para versions(1/4)
qui sursol export "KIHBS 2024 2025 Survey Working Copy", dir("${gsdTemp}/") server("https://emass1991-demo.mysurvey.solutions/primary/") user("Emanuele_api") password("Emanuele_api1") stata para versions(1/4)

**# Append versions of interest
qui sursol append "KIHBS_2024_2025_w", dir("${gsdTemp}/") export("${gsdDataRaw}/suso/") server("https://emass1991-demo.mysurvey.solutions/primary/") sortdesc copy(A01 A02 A12 A13)

**# Analyze paradata
qui sursol para "KIHBS_2024_2025_w" , directory("${gsdTemp}/") export("${gsdDataRaw}/suso/") dur1(InterviewStart_SecYB InterviewEnd_SecYB)

**# Retrieve technical specifications of the tablets used
//sursol userreport, directory("${gsdTemp}/") server("https://emass1991-demo.mysurvey.solutions/primary") hquser(${username_hq}) hqpassword(${password_hq}) xlsx 
sursol userreport, directory("${gsdTemp}/") server("https://emass1991-demo.mysurvey.solutions/primary") hquser("admin_hq") hqpassword("cY8_3veBA_hq2") xlsx 
qui import excel "${gsdTemp}/\Interviewers.xlsx", sheet("Data") firstrow clear
dropmiss *, force
clonevar responsible=i_name 
qui save "${gsdDataRaw}/suso/Interviewers.dta", replace 
 
qui filelist, dir("${gsdTemp}") nor 
qui levelsof filename if regexm(filename,".zip"),local(filestoerase) 
foreach f of local filestoerase { 
		erase "${gsdTemp}/`f'" 
}

**# Cleanup raw data folder 
qui filelist, dir("${gsdDataRaw}/suso") nor 
qui levelsof filename if regexm(filename,"__"),local(filestoerase) 
foreach f of local filestoerase { 
		erase "${gsdDataRaw}/suso/`f'" 
}

use "${gsdDataRaw}/suso/KIHBS_2024_2025_w.dta",clear
merge 1:1 interview__id using "${gsdDataRaw}/suso/\paradata_overview.dta", nogen keep(1 3) assert(1 3) //merge metavariables from paradata analysis
merge m:1 responsible using "${gsdDataRaw}/suso/Interviewers.dta", nogen keep(1 3) //merge metavariables from paradata analysis

br sprvsr responsible rawdurint clean_durint cleandur_min rawdur_min rawdur_fstcompl cleandur_fstcompl length_pause n_answer answ_pm n_removed

**# Reject submissions with errors and unanswered questions 
sursol rejectHQ if entities__errors>=1000000000 & !mi(entities__errors), server("https://emass1991-demo.mysurvey.solutions/primary/") user("emanuele_api") password("Emanuele_api1") id(interview__id) comment("You have at least 1 error in your form, please recheck and complete once the screen is GREEN") //more than 1 errors trigger rejection
sursol rejectHQ if n_questions_unanswered>=1000000000 & !mi(n_questions_unanswered), server("https://emass1991-demo.mysurvey.solutions/primary/") user("emanuele_api") password("Emanuele_api1") id(interview__id) comment("You have at least 1 unanswered field in your form, please recheck and complete once the screen is GREEN") //more than 1 unanswered question triggers rejection

**# Dataset/variables preprocessing
destring version, replace //Form version
keep if inlist(version,4)
replace interview__status=65 if interview__status!=65
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
local sections A B C D E F G H I J K L M N O P Q R S T U V W X YA YB YC YD YE
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
replace A12="123456805" if A12=="2"
destring A12, gen(hhid)
decode A01, gen(county_name)
clonevar ea_name=A06
clonevar foname=responsible
egen fitems_reported=rowtotal(YA_Cereals__* YA_Meat__*)
qui save "${gsdDataRaw}/suso/KIHBS_2024_2025_w_completed.dta", replace

*Set globals for data monitoring and cleaning
global id interview__key 
global date submissiondate
global duration duration_overall
global consent consented
global formv version
global fo foname
global sfo sprvsr 
global keepvars hhid county_name ea_name sprvsr interview__key

**# Progress report: coverage of households within each County
preserve 
qui duplicates drop hhid, force 
tempfile ids_submitted
qui save `ids_submitted', replace
restore 
preserve 
qui import excel "${gsdDataRaw}/sample/sample_2024.xlsx", sheet("Sheet1") clear first
qui save "${gsdDataRaw}/sample/sample.dta", replace 
restore 
*Erase exsisting file
cap confirm file "${gsdOutput}/hfc_output/progreport_bycounty.xlsx"
if !_rc {
	qui rm "${gsdOutput}/hfc_output/progreport_bycounty.xlsx"
}
qui progreport, master("${gsdDataRaw}/sample/sample.dta") survey(`ids_submitted') id(hhid) sortby(county_name) keepmaster(ea_name) keepsurvey(sprvsr responsible interview__status) surveyok filename("${gsdOutput}/hfc_output/progreport_bycounty.xlsx")

**# Enumerator dashboard with productivity statistics
capture confirm file "${gsdOutput}/hfc_output/enumdb.xlsx"
if !_rc {
	qui rm "${gsdOutput}/hfc_output/enumdb.xlsx"
}
ipacheckenumdb using "${gsdDo}/hfc/hfc_inputs_hh.xlsm", formv(version) dur(duration_overall) cons(consented, 1)  enum(responsible) team(county_name) date(submissiondate) outf("${gsdOutput}/hfc_output/enumdb.xlsx") sheetrep other(*_other) dontknow(-98,"know") ref(-99, "refuse")

**# Check HOUSEHOLD (i.e. Questionnaire level) dataset 
run "${gsdDo}/correct_raw_hh.do"
*a) Constraints violations 
qui ipacheckconstraints using "${gsdDo}/hfc/hfc_inputs_hh.xlsm", id($id) enum($fo) date($date) outf("${gsdOutput}/hfc_output/hfc_outputs_hh.xlsx") sheetrep 
*b) Skip pattern violations 
qui ipachecklogic using "${gsdDo}/hfc/hfc_inputs_hh.xlsm", id($id) enum($fo) date($date) outf("${gsdOutput}/hfc_output/hfc_outputs_hh.xlsx") sheetrep
qui ipacheckids hhid, key($id) enumerator($fo) date($date) outfile("${gsdOutput}/hfc_output/hfc_outputs_hh.xlsx") sheetrep
*c) Outdated questionnaire versions 
ipacheckversions version, enumerator($fo) date($date) outfile("${gsdOutput}/hfc_output/hfc_outputs_hh.xlsx") sheetrep
*d) Check outliers 
ipacheckoutliers using "${gsdDo}/hfc/hfc_inputs_hh.xlsm", sheet("outliers") enumerator($fo) date($date) id($id) outfile("${gsdOutput}/hfc_output/hfc_outputs_hh.xlsx")
*e) Other specify 
ipacheckspecify using "${gsdDo}/hfc/hfc_inputs_hh.xlsm", sheet("other specify") id($id) enumerator($fo) date($date) outfile("${gsdOutput}/hfc_output/hfc_outputs_hh.xlsx")

**# Consolidate and check HOUSEHOLD MEMBER dataset 
use "${gsdDataRaw}/suso/household_roster.dta", clear 

**# Consolidate and check FOOD dataset 
*1) First consolidate
local fdtas cereals meat 
foreach d of local fdtas {
	use "${gsdDataRaw}/suso/`d'.dta", clear 
	renvars, subs(_`d' )
	rename `d'__id foodid
	gen macrocategory="`d'"
	tempfile food_`d'
	qui save `food_`d'', replace
}
use `food_cereals', clear
rename total_q_cons_cereal total_q_cons
append using `food_meat'
merge m:1 interview__key interview__id using "${gsdDataRaw}/suso/KIHBS_2024_2025_w_completed.dta", keep(3) assert(3) nogen keepusing(A01 version foname sprvsr dur_sec_YA InterviewEnd_SecYA_stata submissiondate county_name)
*Apply corrections based on a) and b) [see below]
run "${gsdDo}/correct_raw_durables.do"
qui save "${gsdTemp}/fooditems.dta", replace
*2) Then check for:
*a) Constraints violations 
qui ipacheckconstraints using "${gsdDo}/hfc/hfc_inputs_food.xlsm", id($id) enum($fo) date($date) outf("${gsdOutput}/hfc_output/hfc_outputs_food.xlsx") sheetrep 
*b) Skip pattern violations 
qui ipachecklogic using "${gsdDo}/hfc/hfc_inputs_food.xlsm", id($id) enum($fo) date($date) outf("${gsdOutput}/hfc_output/hfc_outputs_food.xlsx") sheetrep

**# Consolidate and check NON-FOOD dataset 
*1) First consolidate
local nfdtas 7d 1m 6m 12m
foreach d of local nfdtas {
	use "${gsdDataRaw}/suso/r_`d'_expenses.dta", clear 
	renvars, subs(_`d' )
	qui rename *_expenses__id expenses__id
	qui renvars, presub(*_expenses__id expenses__id)
	//rename `d'__id foodid
	qui gen rp="`d'"
	decode expenses__id, gen(expenses__id_s)
	tempfile nfood_`d'
	qui save `nfood_`d'', replace
}
use `nfood_7d', clear
append using `nfood_1m' `nfood_6m' `nfood_12m'
gen reference=1 if rp=="7d"
replace reference=2 if rp=="1m"
replace reference=3 if rp=="6m"
replace reference=4 if rp=="12m"
labmask reference,val(rp)
label var reference "Reference period"
label drop r_7days_expenses__id
labmask expenses__id,val(expenses__id_s)
drop rp expenses__id_s
merge m:1 interview__key interview__id using "${gsdDataRaw}/suso/KIHBS_2024_2025_w_completed.dta", keep(3) assert(3) nogen keepusing(A01 version responsible sprvsr dur_sec_YC InterviewEnd_SecYC_stata dur_sec_YD InterviewEnd_SecYD_stata)
*Apply corrections based on a) and b) [see below]
run "${gsdDo}/correct_raw_nfood.do"
qui save "${gsdTemp}/nfooditems.dta", replace
*2) Then check for:
*a) Constraints violations 
qui ipacheckconstraints using "${gsdDo}/hfc/hfc_inputs_nfood.xlsm", id($id) enum($fo) date($date) outf("${gsdOutput}/hfc_output/hfc_outputs_nfood.xlsx") sheetrep 
*b) Skip pattern violations 
qui ipachecklogic using "${gsdDo}/hfc/hfc_inputs_nfood.xlsm", id($id) enum($fo) date($date) outf("${gsdOutput}/hfc_output/hfc_outputs_nfood.xlsx") sheetrep

**# Consolidate and check DURABLES dataset 
*1) First consolidate
use "${gsdDataRaw}/suso/r_Durables_Expenditures.dta", clear 
dropmiss *, force
merge m:1 interview__key interview__id using "${gsdDataRaw}/suso/KIHBS_2024_2025_w_completed.dta", keep(3) assert(3) nogen keepusing(A01 version responsible sprvsr dur_sec_YE InterviewEnd_SecYE_stata)
*Apply corrections based on a) and b)
run "${gsdDo}/correct_raw_durables.do"
qui save "${gsdTemp}/durables.dta", replace
*2) Then check for:
*a) Constraints violations 
qui ipacheckconstraints using "${gsdDo}/hfc/hfc_inputs_durables.xlsm", id($id) enum($fo) date($date) outf("${gsdOutput}/hfc_output/hfc_outputs_durables.xlsx") sheetrep 
*b) Skip pattern violations 
qui ipachecklogic using "${gsdDo}/hfc/hfc_inputs_durables.xlsm", id($id) enum($fo) date($date) outf("${gsdOutput}/hfc_output/hfc_outputs_durables.xlsx") sheetrep
