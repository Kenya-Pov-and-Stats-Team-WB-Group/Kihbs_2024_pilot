*purpose: anonymize all datasets 
set more off
set seed 24202893 
set sortseed 17042355

scalar define nerr=0
capture: confirm file "${gsdDataRaw}/Anonymization/anon_ident.dta"
scalar define nerr=nerr+_rc

if nerr>0 {
	use "${gsdData}/0-RawOutput/raw_hh_valid.dta", clear
	keep a09 a10 a10_1 interview__key interview__id
	sort a09 a10 a10_1
	egen clid=group(a09)
	egen strid=group(a09 a10)
	egen hhid=group(a09 a10 a10_1)
	isid hhid
	qui save "${gsdDataRaw}/Anonymization/anon_ident.dta", replace 
}
***HOUSEHOLD***
use "${gsdData}/0-RawOutput/raw_hh_valid.dta", clear
merge m:1 a09 a10 a10_1 using "${gsdDataRaw}/Anonymization/anon_ident.dta", assert(match) keep(match) keepusing(clid strid hhid) nogen
*Assert hhid and clid are not missing
assert !mi(clid,strid,hhid)
*Drop identifying information geographical information, geo coordinates, hh head name.
keeporder interview__key interview__id clid strid hhid county resid strat doi a11_1- t02 qrt weight_hh weight_ind hhsize adq_scale
isid hhid
isid clid strid hhid
sort clid strid hhid
gen weight_pop=weight_ind*hhsize
gen weight_adq=weight_ind*adq_scale
lab var weight_hh "Household weight"
lab var weight_pop "Population (individuals) weight"
lab var weight_adq "Adult equivalent population weight"
drop weight_ind
qui save "${gsdData}/1-CleanInput/hh.dta", replace

***HOUSEHOLD MEMBER***
use "${gsdData}/0-RawOutput/raw_hhm_valid.dta", clear
merge m:1 a09 a10 a10_1 using "${gsdDataRaw}/Anonymization/anon_ident.dta", assert(match) keep(match) keepusing(clid strid hhid) nogen
drop b02 b06_dd age_cur //drop respondent name, day of birth, system age variable
drop a09 a10 a10_1 //dropping geographic information
assert !mi(clid,strid,hhid)
sort clid strid hhid hhid__id
isid hhid hhid__id
gen weight_pop=weight_ind*hhsize
gen weight_adq=weight_ind*adq_scale
lab var weight_hh "Household weight"
lab var weight_pop "Population (individuals) weight"
lab var weight_adq "Adult equivalent population weight"
drop weight_ind *_mode*
qui save "${gsdData}/1-CleanInput/hhm.dta", replace

***FOOD***
use "${gsdTemp}/food.dta", clear
merge m:1 a09 a10 a10_1 using "${gsdDataRaw}/Anonymization/anon_ident.dta", assert(match) keep(match) keepusing(clid strid hhid) nogen
drop a09 a10 a10_1
assert !mi(clid, strid, hhid)
sort clid strid hhid f2
isid hhid f2
keeporder interview__key interview__id county clid strid hhid f2 f04_qtya f04_unita f05_qtya f05_unita f05_qtyb f05_unitb f05_amnt f06_qty f06_unit f07_qty f07_unit f08_qty f08_unit f09_qty f09_unit f10_qty f10_unit hhsize adq_scale strat resid qrt weight_hh weight_ind
lab var f2 "Food item code"
gen weight_pop=weight_ind*hhsize
gen weight_adq=weight_ind*adq_scale
lab var weight_hh "Household weight"
lab var weight_pop "Population (individuals) weight"
lab var weight_adq "Adult equivalent population weight"
drop weight_ind
qui save "${gsdData}/1-CleanInput/food.dta", replace

***NON-FOOD***
use "${gsdData}/0-RawOutput/nonfood_1.dta", clear
merge m:1 a09 a10 a10_1 using "${gsdDataRaw}/Anonymization/anon_ident.dta", assert(match using) keep(match) keepusing(clid strid hhid) nogen
drop a09 a10 a10_1 //dropping geographic information
assert !mi(clid, strid, hhid)
isid hhid nf02
order clid strid hhid, after(county)
gen weight_pop=weight_ind*hhsize
gen weight_adq=weight_ind*adq_scale
lab var weight_hh "Household weight"
lab var weight_pop "Population (individuals) weight"
lab var weight_adq "Adult equivalent population weight"
drop weight_ind
qui save "${gsdData}/1-CleanInput/nonfood.dta", replace

copy "${gsdDataRaw}/calories.dta" "${gsdData}/1-CleanInput/calories.dta", replace