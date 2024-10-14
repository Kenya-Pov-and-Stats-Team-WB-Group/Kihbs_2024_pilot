use "${gsdRawOutput}/pilot/KIHBS24_pilot_fooditems.dta", clear
merge m:1 interview__id using "${gsdDataRaw}/KIHBS_2024_pilot_completed.dta", keepusing(A16 responsible prefill prefill_group) nogen keep(3)
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
gen item_count = q1__1==1 | q1__2==1
gen cons_item_count = q1__2==1
gen purch_item_count = q1__1==1

sort interview__id 
br interview__id food__id qty_kglt_2 uv fcons
encode responsible,gen(responsible1)
gcollapse (sum) fcons *item_count (mean) A16 (first) A01 A15 province responsible1 prefill prefill_group total_kcal_pp_pd, by(interview__id)

*Add food away from home 
merge m:1 interview__id using "${gsdDataRaw}/KIHBS_2024_pilot_completed.dta", keepusing( YB03a_* YB03b_*) nogen keep(3) //bring in expenditures on food away from home
egen fafh=rowtotal(YB03a_* YB03b_*) 
*Add adult equivalent scale and food expenses for hh members 
preserve 
use "${gsdRawOutput}/pilot/household_roster.dta", clear 
	// Get number of household members that consumed FAFH
		egen any_fafh = rowtotal(YB__*)
		egen num_FAFH = sum(any_fafh>0), by(interview__id)
		lab var num_FAFH "# of household membmers that consumed any FAFH"
duplicates drop interview__id, force
tempfile hhm 
qui save `hhm'
restore 
merge 1:1 interview__id using `hhm', keepusing(adq_scale fafh_hhm num_FAFH) nogen keep(3)

gen fcons_plus_fafh=fcons+fafh+fafh_hhm //include food away from home in the monthly per person consumption aggregate

gen fcons_hh_annual=fcons_plus_fafh*((365/7)) //annual consumption value all food items consumed
gen fcons_padq_pm=fcons_hh_annual/adq_scale/12

// At home food consumption only
	gen fcons_athome_annual=fcons*((365/7)) //annual consumption value all food items consumed
	gen fcons_athome_padq_pm=fcons_athome_annual/adq_scale/12
	lab var fcons_athome_padq_pm "Monthly at home food conusmption - per adult equivalent"
	
// FAFH consumption only
	gen fafh_annual=fafh*((365/7)) //annual consumption value all food items consumed
	gen fafh_padq_pm=fafh_annual/adq_scale/12
	lab var fafh_padq_pm "Monthly FAFH reported at HH level - per adult equivalent"

	gen fafh_hhm_annual=fafh_hhm*((365/7)) //annual consumption value all food items consumed
	gen fafh_hhm_padq_pm=fafh_hhm_annual/adq_scale/12
	lab var fafh_hhm_padq_pm "Monthly FAFH reported at individual level - per adult equivalent"

*mkdensity fcons_padq_pm if fcons_padq_pm<20000,by(A15)


// OVERALL COMPARISONS (ACROSS COUNTIES)
	// Number of items
		betterbarci item_count, over(A01) n v format(%9.0f) bar ytitle("# of food items") title("# of Food Items") subtitle("Consumed or Purchased") saving("${gsdOutput}/fditem_count_bycounty.gph", replace) xlab("")
		betterbarci purch_item_count cons_item_count, over(A01) n v format(%9.0f) bar ytitle("# of food items") title("# of Food Items") subtitle("Consumed vs Purchased") saving("${gsdOutput}/fditem_conspurch_count_bycounty.gph", replace) xlab(18.5 "Consumed" 57.5 "Purchased")
	// Share with zero items consumed
		gen no_items_cons = cons_item_count==0
		betterbarci no_items_cons, over(A01) n v bar ytitle("Share of households") pct title("Households with zero food items consumed") saving("${gsdOutput}/sh_nofood_bycounty.gph", replace) xlab("")
	// Consumption expenditure
		betterbarci fcons_athome_padq_pm if inrange(fcons_athome_padq_pm,1,75000), over(A01) vertical n format(%9.0f) bar ytitle("Monthly At-home Consumption Value per AdEq") title("Monthly At-home Consumption Value per AdEq")  saving("${gsdOutput}/fcons_athome_padq_pm_bycounty.gph", replace)
		betterbarci fcons_padq_pm if inrange(fcons_padq_pm,1,75000), over(A01) vertical n  format(%9.0f) bar ytitle("Monthly Food Consumption Value per AdEq") title("Monthly Food Consumption Value per AdEq")  saving("${gsdOutput}/fcons_athome_padq_pm_bycounty.gph", replace) xlab("")
	// Calories
		betterbarci total_kcal_pp_pd if total_kcal_pp_pd<10000 & total_kcal_pp_pd!=0, over(A01) vertical n format(%9.0f) bar ytitle("Calories per person per day") title("Calories per person per day")  saving("${gsdOutput}/kcal_pp_pd_bycounty.gph", replace) xlab("")
	

// Compare food expenditures and items between the 2-layer and single-layer approach
	lab def prefill 0 "Single layer" 1 "2-layered"
	lab val prefill prefill

// number of items reported consumed, purchased, or acquired
	ttest item_count, by(prefill) 
	betterbarci item_count, over(prefill) vertical n format(%9.0f) bar 
	betterbarci item_count, over(prefill) by(A15) vertical n
	betterbarci item_count, over(prefill) by(A01) n title("No. of items reported consumed") subtitle("By 2 layered vs one layered approach")
	
	ttest fcons_athome_padq_pm if inrange(fcons_athome_padq_pm,1,100000), by(prefill)
	betterbarci fcons_athome_padq_pm if inrange(fcons_athome_padq_pm,1,100000), over(prefill) vertical n
	betterbarci fcons_athome_padq_pm if inrange(fcons_athome_padq_pm,1,100000), over(prefill) by(A15) vertical n
	
	mkdensity fcons_athome_padq_pm if fcons_athome_padq_pm<20000,over(prefill)
	
// Checking incidence of household FAFH versus individual
	lab def prefill_group 0 "Individual only" 1 "Both HH and individual"
	lab val prefill_group prefill_group
	// Any FAFH
		gen any_fafh_hhm = fafh_hhm_padq_pm!=0
		
		ttest any_fafh_hhm, by(prefill_group)
		betterbarci any_fafh_hhm, over(prefill_group) vertical n xlab("")
		betterbarci any_fafh_hhm, over(prefill_group) by(A15) vertical n xlab("")
		
	// How many members report FAFH
		ttest num_FAFH, by(prefill_group)
		betterbarci num_FAFH, over(prefill_group) vertical n
		betterbarci num_FAFH, over(prefill_group) by(A15) vertical n		
		
	// Level of FAFH expenditure reported at individual level
		ttest fafh_hhm_padq_pm, by(prefill_group)
		betterbarci fafh_hhm_padq_pm, over(prefill_group) vertical n
		betterbarci fafh_hhm_padq_pm, over(prefill_group) by(A15) vertical n
	
	// Comparing household and individual reported FAFH
		betterbarci fafh_hhm_padq_pm fafh_padq_pm if prefill_group==1 & A16!=1,vertical n
		betterbarci fafh_hhm_padq_pm fafh_padq_pm if prefill_group==1 & A16!=1, over(A15) vertical n
		betterbarci fafh_hhm_padq_pm fafh_padq_pm if prefill_group==1 & A16!=1 & A16<10 & fafh_hhm_padq_pm<10000, over(A16) vertical n
		
	// Any impact on at home conusmption (just out of curiosity)
		ttest fcons_athome_padq_pm if inrange(fcons_athome_padq_pm,1,100000), by(prefill_group)
		betterbarci fcons_athome_padq_pm if inrange(fcons_athome_padq_pm,1,100000), over(prefill_group) vertical n
		betterbarci fcons_athome_padq_pm if inrange(fcons_athome_padq_pm,1,100000), over(prefill_group) by(A15) vertical n
