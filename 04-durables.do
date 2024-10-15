use "${gsdDataRaw}/r_Durables_Expenditures.dta", clear
merge m:1 interview__id using "${gsdDataRaw}/KIHBS_2024_pilot_completed.dta", keepusing(A16 responsible) nogen keep(3)
clonevar durableid=r_Durables_Expenditures__id

//Bring in adult equivalent hh members and education yearly expenses
preserve 
use "${gsdRawOutput}/pilot/household_roster.dta", clear 
duplicates drop interview__id, force
tempfile hhm 
qui save `hhm'
restore 
merge m:1 interview__id using `hhm', keepusing(adq_scale) nogen keep(3)

***********************************************
**# 2 | CALCULATE AND CLEAN DEPRECIATION RATES
***********************************************

*Set key parameters for cash flow calculation: inflation rate (1%) & nominal interest rate (2%)
local pi = 0.04
local i = 0.13

*Estimate a similar formula to that in Deaton and Zaidi (2002) (3.2)
gen drate= 1 -(((YL07/YL06))^(1/YL05)*(1/(1+`pi')))

***********************************************
**# 3 | CALCULATE CONSUMPTION FLOW
***********************************************
bys durableid: egen drate_median=median(drate)
gen cons_flow = YL07*(1+`i')-YL07*(1+`pi')*(1-drate_median)
gen cons_flow_simplified = YL07*(`i' - `pi' + drate_median) //assuming that depriciation times inflation is close to 0
summ cons_flow cons_flow_simplified
label var cons_flow "Consumption flow"
label var cons_flow_simplified "Consumption flow simplified"

*Check depreciation rate and consumption flow for each item
tabstat drate_median cons_flow, s(median  mean) by(durableid) 

*Consumption for each asset 
gen cons_d=cons_flow*YL04

**************************************************
**# 4 | OBTAIN THE FLOW OF DURABLES 
**************************************************

*Transform annual consumption into monthly consumption 
replace cons_d=cons_d/12

*Save a cleaned file by item
keeporder interview__id cons_d A01 A06 A09 A15
label var cons_d "Consumption of durables, monthly"
qui saveold "${gsdTemp}/assets_clean_byitem.dta", replace v(11) 

*Now the data is collapsed at the household level and saved
collapse (sum) cons_d (firstnm) A01 A06 A09 A15, by(interview__id)
label var cons_d "Consumption of durables, monthly"
qui saveold "${gsdTemp}/hh_assets_clean.dta", replace v(11) 

*Check the aggregate
sum cons_d,d
graph box cons_d
kdensity cons_d if cons_d<80000

