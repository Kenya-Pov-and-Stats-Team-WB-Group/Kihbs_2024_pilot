use "${gsdDataRaw}/KIHBS_2024_pilot_completed.dta", clear

//Bring in adult equivalent hh members and education yearly expenses
preserve 
use "${gsdRawOutput}/pilot/household_roster.dta", clear 
duplicates drop interview__id, force
tempfile hhm 
qui save `hhm'
restore 
merge m:1 interview__id using `hhm', keepusing(adq_scale) nogen keep(3)

betterbarci J07, over(A01) n format(%9.1f) v bar ytitle("Ksh") title("Rent expenditure") xlab("")
betterbarci J07, over(J17) n v format(%9.1f)  bar ytitle("Ksh") title("Rent expenditure") subtitle("By roof material") xlab("")
betterbarci J07 if A01==47, over(interviewer) n v format(%9.1f)  bar ytitle("Ksh") title("Rent expenditure") subtitle("By roof material") xlab("")
