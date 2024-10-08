use "${gsdRawOutput}/pilot/KIHBS24_pilot_nfooditems.dta", clear
merge m:1 interview__id using "${gsdDataRaw}/suso/pilot/KIHBS_2024_pilot_completed.dta", keepusing(A16 responsible) nogen keep(3)
recode A01 (1/6=1) (7/9=2) (10/17=3) (18/22=4) (23/36=5) (37/40=6) (41/46=7) (47=8), gen(province)
lab def province 1 "Coast" 2 "North-Eastern" 3 "Eastern" 4 "Central" 5 "Rift Valley" 6 "Western" 7 "Nyanza" 8 "Nairobi"
lab val province province

preserve 
use "${gsdRawOutput}/pilot/household_roster.dta", clear 
duplicates drop interview__id, force
tempfile hhm 
qui save `hhm'
restore 
merge m:1 interview__id using `hhm', keepusing(adq_scale) nogen keep(3)

*Standardize recall periods and values: we want all in monthly terms
egen a=rowtotal(nf_05 nf_08) //first, aggregate consumption value (purchase plus other sources)
gen nf_expense=(a*((365/7)))/12 if recall==1 //for weekly recall, annualize first then bring to month
replace nf_expense=a if recall==2 //monthly records are already ok
replace nf_expense=a/6 if recall==3 //6 months recall bring to monthly
replace nf_expense=a/12 if recall==4 //12 months recall bring to monthly

encode responsible,gen(responsible1)
gcollapse (sum) nf_expense (mean) A16 (first) adq_scale A01 A15 province responsible1, by(interview__id)

gen nfcons_padq_pm=nf_expense/adq_scale 
tabstat nfcons_padq_pm,by(A15)