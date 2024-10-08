use "${gsdRawOutput}/pilot/KIHBS24_pilot_fooditems.dta", clear
merge m:1 interview__id using "${gsdDataRaw}/suso/pilot/KIHBS_2024_pilot_completed.dta", keepusing(A16 responsible) nogen keep(3)
recode A01 (1/6=1) (7/9=2) (10/17=3) (18/22=4) (23/36=5) (37/40=6) (41/46=7) (47=8), gen(province)
lab def province 1 "Coast" 2 "North-Eastern" 3 "Eastern" 4 "Central" 5 "Rift Valley" 6 "Western" 7 "Nyanza" 8 "Nairobi"
lab val province province

bys A01 food__id: egen uv_p50_county=median(unit_value)
bys province food__id: egen uv_p50_prov=median(unit_value)
bys food__id: egen uv_p50_nat=median(unit_value)
gen uv=unit_value if !mi(unit_value) //if a item was purchased and price is available, use that info
*Otherwise, compute median unit values at hierarchical level as feasible
replace uv=uv_p50_county if mi(uv) & !mi(uv_p50_county)
replace uv=uv_p50_prov if mi(uv) & !mi(uv_p50_prov)
replace uv=uv_p50_nat if mi(uv) & !mi(uv_p50_nat)
mdesc uv qty_kglt_2
gen fcons=qty_kglt_2*uv

sort interview__id 
br interview__id food__id qty_kglt_2 uv fcons
encode responsible,gen(responsible1)
gcollapse (sum) fcons (mean) A16 (first) A01 A15 province responsible1, by(interview__id)

*Add food away from home 
merge m:1 interview__id using "${gsdDataRaw}/suso/pilot/KIHBS_2024_pilot_completed.dta", keepusing( YB03a_* YB03b_*) nogen keep(3) //bring in expenditures on food away from home
egen fafh=rowtotal(YB03a_* YB03b_*) 
*Add adult equivalent scale and food expenses for hh members 
preserve 
use "${gsdRawOutput}/pilot/household_roster.dta", clear 
duplicates drop interview__id, force
tempfile hhm 
qui save `hhm'
restore 
merge 1:1 interview__id using `hhm', keepusing(adq_scale fafh_hhm) nogen keep(3)

gen fcons_plus_fafh=fcons+fafh+fafh_hhm //include food away from home in the monthly per person consumption aggregate

gen fcons_hh_annual=fcons_plus_fafh*((365/7)) //annual consumption value all food items consumed
gen fcons_padq_pm=fcons_hh_annual/adq_scale/12

mkdensity fcons_padq_pm if fcons_padq_pm<20000,by(A15)