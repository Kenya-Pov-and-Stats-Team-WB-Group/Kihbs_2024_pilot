*Append all files
qui filelist, dir("${gsdDataRaw}/KIHBS_2023_q1/") pat("*.dta") //list files in a monthly folder
qui levelsof filename,local(filestoappend) //store their names in local
foreach f of local filestoappend { //for each monthly file
		dis in red "Appending file `f'"
		use "${gsdDataRaw}/KIHBS_2023_q1/`f'", clear //open first month
		gen qrt=1 //mark the month
		forval i=2/4 {
		confirm file "${gsdDataRaw}/KIHBS_2023_q`i'/`f'" //for all subsequent months, chech that file exist
		if !_rc  { //if yes
			qui append using "${gsdDataRaw}/KIHBS_2023_q`i'/`f'" //append all subsequent months for each particular file
			qui replace qrt=`i' if mi(qrt) //earmark the month
			dis "appended file `f' in quarter `i'"
		}
		 qui save "${gsdDataRaw}/`f'", replace //save all different raw Sursol generated files for all months
	}
}
use "${gsdDataRaw}/KIHBS_2023_q2/perception_roster.dta", clear
forval i=3/4 {
	qui append using "${gsdDataRaw}/KIHBS_2023_q`i'/perception_roster.dta"
	qui save "${gsdDataRaw}/perception_roster.dta", replace //save all the appended files
}

*Import weights
qui import excel "${gsdDataRaw}/weights_kihbs2023.xlsx", sheet("hhwights") cellrange(A2:C1500) firstrow clear
qui save "${gsdTemp}/weights_kihbs2023_hh.dta", replace 
qui import excel "${gsdDataRaw}/weights_kihbs2023.xlsx", sheet("indweights") cellrange(A2:C1500) firstrow clear
rename Weight weight_ind
qui save "${gsdTemp}/weights_kihbs2023_ind.dta", replace 
use "${gsdTemp}/weights_kihbs2023_hh.dta", clear 
merge 1:1 Sno Clu using "${gsdTemp}/weights_kihbs2023_ind.dta", nogen assert(match) keep(match) keepusing(weight_ind)
rename (Clu Weight) (a09 weight_hh)
lab var weight_hh "Weight for household level estimations"
lab var weight_ind "Weight for individual level estimations"
qui save "${gsdDataRaw}/weights_kihbs2023.dta", replace
erase "${gsdTemp}/weights_kihbs2023_hh.dta"
erase "${gsdTemp}/weights_kihbs2023_ind.dta"

*HOUSEHOLD  
use "${gsdDataRaw}/KIHBS_2023.dta", clear
*Bring in county codes/names
replace a01="NAIROBI" if a01=="NAIROBI CITY"
replace a01="THARAKA NITHI" if a01=="THARAKA-NITHI"
replace a01="TAITA TAVETA" if a01=="TAITA-TAVETA"
replace a01="ELGEYO MARAKWET" if a01=="ELGEYO-MARAKWET"
merge m:1 a01 using "${gsdDataRaw}/county_codes.dta",keep(match) keepusing(county) assert(match) nogen
drop a01 
keep if inlist(interview__status,65,100,120) //valid households were either completed or approved by supervisors one rejected by supervisor has been included since the interview was completed only that the interviewer was to make a certain correction
*GPS - Variable for whether GPS was collected
gen gps_collected = (!mi(Gps1__Latitude) & !mi(Gps1__Longitude) & !mi(Gps1__Altitude)) | (!mi(Gps0__Latitude) & !mi(Gps0__Longitude) & !mi(Gps0__Altitude))
*GPS - Generating GPS variables (latitude, longitude and altitude)
gen latitude = Gps1__Latitude
replace latitude = Gps0__Latitude if mi(Gps1__Latitude)
gen longitude = Gps1__Longitude
replace longitude = Gps0__Longitude if mi(Gps1__Longitude)
gen altitude = Gps1__Altitude
replace altitude = Gps0__Altitude if mi(Gps1__Altitude)
label var latitude "latitude"
label var longitude "longitude"
label var altitude "altitude"
label var gps_collected "GPS location collected" 
drop Gps1__Latitude Gps1__Longitude Gps1__Accuracy Gps1__Altitude Gps1__Timestamp Gps0__Latitude Gps0__Accuracy Gps0__Timestamp Gps0__Longitude Gps0__Altitude
*Compute section duration and full interview duration
local sections A B C D E F G H I J K L M N O P Q T W //for all the sections
foreach s of local sections {
	cap confirm variable start_time`s' //if the start timestamp variable exists
	if !_rc { 
		 qui replace start_time`s'=subinstr(start_time`s',"T","",.)
		 qui gen double datetimestart_`s'=clock(start_time`s', "YMDhms")
		format %tc datetimestart_`s' //convert the timestamp in readeable stata clock format
		drop start_time`s'
	}	
	cap confirm variable end_time`s' //if the end timestamp variable exists 
	if !_rc { 
		 qui replace end_time`s'=subinstr(end_time`s',"T","",.)
		 qui gen double datetimeend_`s'=clock(end_time`s', "YMDhms")
		format %tc datetimeend_`s' //convert the timestamp in readeable stata clock format
		drop end_time`s'
	}	
	cap confirm variable datetimeend_`s' datetimestart_`s'
	if !_rc { 
		qui gen dur_sec_`s'= (datetimeend_`s' - datetimestart_`s')/60000 //the section's duration is the time elapsed (in minutes)
		qui replace dur_sec_`s'=. if dur_sec_`s'<0 //address non linear form navigation (if the FO started a subsequent section first, the elapsed time would be negative, hence invalid)
		lab var dur_sec_`s' "Duration section `s' (minutes)"
		drop datetimeend_`s' datetimestart_`s'
	}
}
egen intw_dur=rowtotal(dur_sec_*) //sum of sections' durations
lab var intw_dur "Full interview duration (minutes)"
split b_date, parse(T)
gen doi = date(b_date1, "YMD")
format doi %td
gen month = month(doi)
label var doi "Date of interview"
order doi ,before(a11)
*6500 households have no household size nor any info on household member/other sections. such interviews have an almost null survey duration
tab county qrt if mi(a12),chi //almost all counties affected, but definitely a problem in wajir
drop if mi(a12) 
egen tot_fitems_acquired=rowtotal( Sectionlistf_a__101- sectionflistf_e__1905)
tab county qrt if tot_fitems_acquired==0,chi
tabstat tot_fitems_acquired,by(county) s(min mean p50 max)
drop if tot_fitems_acquired==0
drop datetimestart_M b_date b02__* Sectionlistf_a__101- sectionflistf_e__1905 b_date* datetimeend_B
dropmiss *, force
*Bring in residence info
preserve
qui import excel "${gsdDataRaw}/2023 Sample.xlsx", sheet("2023_KIHBS_EA_Sample_Rev") firstrow clear
rename (ClusterNumber Residence) (a09 resid)
sort a09
qui save "${gsdDataRaw}/sample.dta", replace 
restore
sort a09
merge m:1 a09 using "${gsdDataRaw}/sample.dta", keepusing(resid) keep(match master) nogen
lab define resid 1 "Rural" 2 "Urban", replace
lab val resid resid
egen strat=group(county resid)
lab var strat "Stratum (county x residence)"
qui compress
drop if interview__key=="45-85-94-46" // this household has all hh member info missing. It is invalid
*Clean string variables (apart from the unique keys)
qui ds *, has(type string) 
local vars `r(varlist)'
local omit interview__key interview__id
local want : list vars - omit
foreach v of local want {
    qui replace `v' = strtrim(stritrim(`v'))
    qui replace `v'= upper(`v')
}
duplicates drop a09 a10 a10_1,force
isid a09 a10 a10_1
merge m:1 a09 using "${gsdDataRaw}/weights_kihbs2023.dta",  keepusing(weight_hh weight_ind) keep(match master) nogen  //there are 32 clusters with no valid interviews
qui save "${gsdTemp}/hh_valid.dta", replace 

*HOUSEHOLD MEMBER
use "${gsdDataRaw}/hhid.dta", clear 
merge m:1 interview__id interview__key using "${gsdTemp}/hh_valid.dta", keep(match) keepusing(county a13 a12 strat a09 a10 a10_1 resid weight_hh weight_ind) nogen
*A dummy variable is generated to drop households with no (or too many) head.
replace b03=3 if b03==1 & interview__id=="66eb280acfb846ad9bee0c9a82c635b2" & hhid__id==5 // in one household there are 2 hh head (one is a 5 years old kid)
gen pre_hh_head = (b03==1)
bys interview__id: egen hh_head = sum(pre_hh_head)
assert hh_head==1 //all households have one household head
drop pre_hh_head hh_head a13
*Generating new hhsize and adult equivalent scale variable after dropping invalid individuals
bys interview__id: gen hhsize = _N
cap assert hhsize==a12 //for 1 household there is double counting of the respondent. in all other cases, consistency between reported hh size and actual number of individuals recorded in each household.
label var hhsize "Total persons in the Household"
gen pre_adq_scale = .
replace pre_adq_scale=0.24   if inrange(b05_years,0,4)
replace pre_adq_scale=0.65   if inrange(b05_years,5,14)
replace pre_adq_scale=1.00   if inrange(b05_years,15,112)
bys interview__id: egen adq_scale = sum(pre_adq_scale)
label var adq_scale "Adult Equivalent Scale"
order hhsize adq_scale, after(interview__id)
*Clean string variables (apart from the unique keys)
qui ds *, has(type string) 
local vars `r(varlist)'
local omit interview__key interview__id
local want : list vars - omit
foreach v of local want {
     qui replace `v' = strtrim(stritrim(`v'))
     qui replace `v'= upper(`v')
}
qui dropmiss *,force
drop pre_adq_scale w1
isid a09 a10 a10_1 hhid__id
qui save "${gsdTemp}/hhm_valid.dta", replace 
decode county, gen(countystr)
collapse county a09 a10 a10_1 strat resid adq_scale hhsize weight_hh weight_ind (first) countystr,by(interview__key interview__id)
labmask county,val(countystr)
qui save "${gsdTemp}/hhsize_adq.dta", replace 

*Consolidate FOOD
use "${gsdDataRaw}/Sectionf_a.dta", clear
gen itemcode=Sectionf_a__id
decode Sectionf_a__id,gen(labvalue)
local i=1 
local let b c d e 
foreach l of local let {
	preserve
	use "${gsdDataRaw}/Sectionf_`l'.dta", clear
	gen itemcode=Sectionf_`l'__id 
	decode Sectionf_`l'__id,gen(labvalue)
	gen section= "`l'"
	ren *`i' *
	drop Sectionf_`l'__id 
	qui save "${gsdTemp}/Sectionf_`l'.dta", replace 
	local i=`i'+1
	restore
	append using "${gsdTemp}/Sectionf_`l'.dta"
}
replace section="a" if mi(section)
labmask itemcode,val(labvalue)
rename itemcode f2
merge m:1 interview__id using "${gsdTemp}/hhsize_adq.dta", nogen keep(match) keepusing(resid county hhsize adq_scale strat a09 a10 a10_1 weight_hh weight_ind)
*Clean string variables (apart from the unique keys)
qui ds *, has(type string) 
local vars `r(varlist)'
local omit interview__key interview__id
local want : list vars - omit
foreach v of local want {
     qui replace `v' = strtrim(stritrim(`v'))
     qui replace `v'= upper(`v')
}
qui dropmiss *,force
keeporder interview__key interview__id a09 a10 a10_1 f2 f04_qtya f04_unita f05_qtya f05_unita f05_unita_other f05_qtyb f05_unitb f05_amnt f06_qty f06_unit f07_qty f07_unit f08_qty f08_unit f09_qty f09_unit f10_qty f10_unit qrt county resid hhsize adq_scale strat weight_hh weight_ind
qui compress
isid a09 a10 a10_1 f2
qui save "${gsdData}/0-RawOutput/food_1.dta", replace 

*Consolidate NONFOOD
run "${gsdDo}/0-1-1-append_nonfood.do"
use "${gsdData}/1-CleanTemp/nonfood_2.dta", clear
rename  interview_id interview__id
merge m:1 interview__id using "${gsdTemp}/hhsize_adq.dta", nogen keep(match) keepusing(county resid hhsize adq_scale strat a09 a10 a10_1 weight_hh weight_ind)
*Clean string variables (apart from the unique keys)
qui ds *, has(type string) 
local vars `r(varlist)'
local omit interview__key interview__id
local want : list vars - omit
foreach v of local want {
     qui replace `v' = strtrim(stritrim(`v'))
     qui replace `v'= upper(`v')
}
qui dropmiss *,force
labmask nf02 ,val(Itemname)
keeporder interview__id interview__key sect recall a09 a10 a10_1 nf02 nf03 nf04 nf05 nf06 nf07 nf08 qrt hhsize adq_scale county resid strat weight_hh weight_ind
qui compress
isid nf02 a09 a10 a10_1
qui save "${gsdData}/0-RawOutput/nonfood_1.dta", replace 
