use "${gsdRawOutput}/pilot/KIHBS24_pilot_nfooditems.dta", clear
merge m:1 interview__id using "${gsdDataRaw}/KIHBS_2024_pilot_completed.dta", keepusing(A16 responsible) nogen keep(3)
recode A01 (1/6=1) (7/9=2) (10/17=3) (18/22=4) (23/36=5) (37/40=6) (41/46=7) (47=8), gen(province)
lab def province 1 "Coast" 2 "North-Eastern" 3 "Eastern" 4 "Central" 5 "Rift Valley" 6 "Western" 7 "Nyanza" 8 "Nairobi"
lab val province province

//Combine first hand and second hand clothes
replace nf_05=nf_05+nf_05a+nf_05b if mi(nf_05)

//Bring in adult equivalent hh members and education yearly expenses
preserve 
use "${gsdRawOutput}/pilot/household_roster.dta", clear 
gen educ_expense=total_expenses+total_expenses_assisted
egen outlier_educ_nat=outside(educ_expense), by(C13 ) factor(1.5)
bys interview__id: egen educ_expense_hh=total(educ_expense)
duplicates drop interview__id, force
tempfile hhm 
qui save `hhm'
restore 
merge m:1 interview__id using `hhm', keepusing(adq_scale educ_expense_hh) nogen keep(3)

*Standardize recall periods and values: we want all in monthly terms
egen a=rowtotal(nf_05 nf_08) //first, aggregate consumption value (purchase plus other sources)
gen nf_expense=(a*((365/7)))/12 if recall==1 //for weekly recall, annualize first then bring to month
replace nf_expense=a if recall==2 //monthly records are already in monthly terms
replace nf_expense=a/6 if recall==3 //6 months recall bring to monthly
replace nf_expense=a/12 if recall==4 //12 months recall bring to monthly
replace nf_expense=nf_expense+(educ_expense_hh/12) if !mi(educ_expense_hh) //12 months recall for education to be made monthly and added to monthly expenditure

egen outlier_nat=outside(nf_expense), by(nf__expenses__id ) factor(1.5)
egen outlier_cty=outside(nf_expense), by( A01 nf__expenses__id ) factor(1.5)

fre nf__expenses__id if !mi(outlier_nat), des 

encode responsible,gen(responsible1)
gcollapse (sum) nf_expense (mean) A16 (first) adq_scale A01 A15 province responsible1, by(interview__id)

gen nfcons_padq_pm=nf_expense/adq_scale

betterbarci nfcons_padq_pm, over(A01) n v format(%9.0f) bar ytitle("Ksh") title("Non food monthly per adult equivalent expense") subtitle("By county") saving("${gsdOutput}/nfcons_padq_pm_bycounty.gph", replace) xlab("")
betterbarci nfcons_padq_pm, over(A15) n v format(%9.0f) bar ytitle("Ksh") title("Non food monthly per adult equivalent expense") subtitle("By residence") saving("${gsdOutput}/nfcons_padq_pm_byresid.gph", replace) xlab("")
betterbarci nfcons_padq_pm, over(province) n v format(%9.0f) bar ytitle("Ksh") title("Non food monthly per adult equivalent expense") subtitle("By enumerator") saving("${gsdOutput}/nfcons_padq_pm_byenum.gph", replace) xlab("")

 
tabstat nfcons_padq_pm,by(A15)