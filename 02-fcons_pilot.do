use "${gsdRawOutput}/pilot/KIHBS24_pilot_fooditems.dta", clear
merge m:1 interview__id using "${gsdDataRaw}/KIHBS_2024_pilot_completed.dta", keepusing(A16 responsible prefill prefill_group) nogen keep(3)

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
		lab var num_FAFH "# of household members that consumed any FAFH"
		lab var any_fafh "Flag for hh that have any FAFH expenditures (member level only)"
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
	lab var fcons_athome_annual "Annual total at home food conusmption"
	lab var fcons_athome_padq_pm "Monthly at home food conusmption - per adult equivalent"
	
// FAFH consumption only
	gen fafh_annual=fafh*((365/7)) //annual consumption value all food items consumed
	gen fafh_padq_pm=fafh_annual/adq_scale/12
	lab var fafh_annual "Annual total FAFH reported at HH level"
	lab var fafh_padq_pm "Monthly FAFH reported at HH level - per adult equivalent"

	gen fafh_hhm_annual=fafh_hhm*((365/7)) //annual consumption value all food items consumed
	gen fafh_hhm_padq_pm=fafh_hhm_annual/adq_scale/12
	lab var fafh_hhm_annual "Annual total FAFH reported at individual level"
	lab var fafh_hhm_padq_pm "Monthly FAFH reported at individual level - per adult equivalent"

*mkdensity fcons_padq_pm if fcons_padq_pm<20000,by(A15)


// OVERALL COMPARISONS (ACROSS COUNTIES)
	// Number of items
		betterbarci item_count, over(A01) n v format(%9.0f) bar ytitle("# of food items") title("# of Food Items") subtitle("Consumed or Purchased") saving("${gsdOutput}/fditem_count_bycounty.gph", replace) xlab("")
		betterbarci purch_item_count cons_item_count, over(A01) n v format(%9.0f) bar ytitle("# of food items") title("# of Food Items") subtitle("Consumed vs Purchased") saving("${gsdOutput}/fditem_conspurch_count_bycounty.gph", replace) xlab(18.5 "Consumed" 57.5 "Purchased")
	// Share with zero items consumed
		gen no_items_cons = cons_item_count==0
		lab var no_items_cons "Household has zero food items consumed (at home)"
		betterbarci no_items_cons, over(A01) n v bar ytitle("Share of households") pct title("Households with zero food items consumed") saving("${gsdOutput}/sh_nofood_bycounty.gph", replace) xlab("")
	// Consumption expenditure
		betterbarci fcons_athome_padq_pm if inrange(fcons_athome_padq_pm,1,75000), over(A01) vertical n format(%9.0f) bar ytitle("Monthly At-home Consumption Value per AdEq") title("Monthly At-home Consumption Value per AdEq")  saving("${gsdOutput}/fcons_athome_padq_pm_bycounty.gph", replace)
		betterbarci fcons_padq_pm if inrange(fcons_padq_pm,1,75000), over(A01) vertical n  format(%9.0f) bar ytitle("Monthly Food Consumption Value per AdEq") title("Monthly Food Consumption Value per AdEq")  saving("${gsdOutput}/fcons_athome_padq_pm_bycounty.gph", replace) xlab("")
	// Calories
		betterbarci total_kcal_pp_pd if total_kcal_pp_pd<10000 & total_kcal_pp_pd!=0, over(A01) vertical n format(%9.0f) bar ytitle("Calories per person per day") title("Calories per person per day")  saving("${gsdOutput}/kcal_pp_pd_bycounty.gph", replace) xlab("")
		// Include zeros
			betterbarci total_kcal_pp_pd if total_kcal_pp_pd<10000, over(A01) vertical n format(%9.0f) bar ytitle("Calories per person per day") title("Calories per person per day") subtitle("Including zero calories") saving("${gsdOutput}/kcal_pp_pd_wzeros_bycounty.gph", replace) xlab("")
	

// Compare food expenditures and items between the 2-layer and single-layer approach
	lab def prefill 0 "Single layer" 1 "2-layered"
	lab val prefill prefill

	// number of items reported consumed, purchased, or acquired
		ttest item_count, by(prefill) 
		// Consumed or purchased
			betterbarci item_count, over(prefill) vertical n format(%9.0f) bar ytitle("# of food items") title("# of Food Items by Layered Approach") subtitle("Consumed or Purchased") saving("${gsdOutput}/fditem_count_by2layer.gph", replace) xlab("")	
			// Urban Rural
				betterbarci item_count, over(prefill) by(A15) vertical n format(%9.0f) bar ytitle("# of food items") title("# of Food Items by Layered Approach") subtitle("by Urban/Rural") saving("${gsdOutput}/fditem_count_by2layer_urban_rual.gph", replace) xlab(3.5 "Rural" 12.5 "Urban")
		// Consumption vs purchased
			betterbarci purch_item_count cons_item_count, over(prefill) n v format(%9.0f) bar ytitle("# of food items") title("# of Food Items by Layered Approach") subtitle("Consumed vs Purchased") saving("${gsdOutput}/fditem_conspurch_count_bycounty.gph", replace) xlab(3.5 "Consumed" 12.5 "Purchased")
		// Share with zero items consumed
			betterbarci no_items_cons, over(prefill) n v bar ytitle("Share of households") pct title("Households with zero food items consumed") subtitle("By Layered Approach") saving("${gsdOutput}/sh_nofood_by2layer.gph", replace) xlab("")
	
	// At home expenditures
		ttest fcons_athome_padq_pm if inrange(fcons_athome_padq_pm,1,100000), by(prefill)
		betterbarci fcons_athome_padq_pm if inrange(fcons_athome_padq_pm,1,75000), over(prefill) vertical n format(%9.0f) bar ytitle("Monthly At-home Consumption Value per AdEq") title("Monthly At-home Consumption Value per AdEq")  xlab("") saving("${gsdOutput}/fcons_athome_padq_pm_by2layer.gph", replace)
		// Urban Rural
		betterbarci fcons_athome_padq_pm if inrange(fcons_athome_padq_pm,1,75000), over(prefill) by(A15) vertical n format(%9.0f) bar ytitle("Monthly At-home Consumption Value per AdEq") title("Monthly At-home Consumption Value per AdEq") xlab(3.5 "Rural" 12.5 "Urban") saving("${gsdOutput}/fcons_athome_padq_pm_by2layer_rururb.gph", replace)
		
	mkdensity fcons_athome_padq_pm if fcons_athome_padq_pm<20000,over(prefill)
	
// Checking incidence of household FAFH versus individual
	lab def prefill_group 0 "Individual only" 1 "Both HH and individual"
	lab val prefill_group prefill_group
	// Any FAFH
		gen any_fafh_hhm = fafh_hhm_padq_pm!=0
		lab var any_fafh_hhm "Household has any FAFH from member level"
		
		ttest any_fafh_hhm, by(prefill_group)
		betterbarci any_fafh_hhm, over(prefill_group) n v bar ytitle("Share of households") pct title("Households with any FAFH at member level") subtitle("By Approach") saving("${gsdOutput}/sh_anyfafh_byapproach.gph", replace) xlab("")
		betterbarci any_fafh_hhm, over(prefill_group) by(A15) n v bar ytitle("Share of households") pct title("Households with any FAFH at member level") subtitle("By Approach") saving("${gsdOutput}/sh_anyfafh_byapproach_urbrur.gph", replace) 
		
	// How many members report FAFH
		ttest num_FAFH, by(prefill_group)
		betterbarci num_FAFH, over(prefill_group) v n format(%9.2f) bar ytitle("# of HH members") title("# of HH members reporting any FAFH") subtitle("By approach") saving("${gsdOutput}/nummem_fafh_byappraoch.gph", replace)
		betterbarci num_FAFH, over(prefill_group) by(A15) v n format(%9.2f) bar ytitle("# of HH members") title("# of HH members reporting any FAFH") subtitle("By approach and urban rural") saving("${gsdOutput}/nummem_fafh_byappraoch.gph", replace) xlab(3.5 "Rural" 12.5 "Urban")		
		
	// Level of FAFH expenditure reported at individual level
		ttest fafh_hhm_padq_pm, by(prefill_group)
		betterbarci fafh_hhm_padq_pm, over(prefill_group) v n format(%9.0f) bar ytitle("Monthly FAFH Expenditures") title("Monthly FAFH Expenditures per AdEq") subtitle("From HH Member Version") saving("${gsdOutput}/fafh_exp_member_byappraoch.gph", replace) xlab("")		
		betterbarci fafh_hhm_padq_pm, over(prefill_group) by(A15) v n format(%9.0f) bar ytitle("Monthly FAFH Expenditures") title("Monthly FAFH Expenditures per AdEq") subtitle("From HH Member Version") saving("${gsdOutput}/fafh_exp_member_byappraoch_urbrur.gph", replace) xlab(3.5 "Rural" 12.5 "Urban")		
	
	// Comparing household and individual reported FAFH
		betterbarci fafh_hhm_padq_pm fafh_padq_pm if prefill_group==1 & A16!=1, v n format(%9.0f) bar ytitle("Monthly FAFH Expenditures") title("Monthly FAFH Expenditures per AdEq") subtitle("HH vs Member version") saving("${gsdOutput}/fafh_exp_member_v_hh.gph", replace) xlab(2 "HH Level" 8 "Member level")	
		betterbarci fafh_hhm_padq_pm fafh_padq_pm if prefill_group==1 & A16!=1, over(A15) v n format(%9.0f) bar ytitle("Monthly FAFH Expenditures") title("Monthly FAFH Expenditures per AdEq") subtitle("HH vs Member version") saving("${gsdOutput}/fafh_exp_member_v_hh_yurbrur.gph", replace) xlab(3.5 "HH Level" 12.5 "Member level")	
		*betterbarci fafh_hhm_padq_pm fafh_padq_pm if prefill_group==1 & A16!=1 & A16<10 & fafh_hhm_padq_pm<10000, over(A16) vertical n
		
	// Any impact on at home conusmption (just out of curiosity)
		/*ttest fcons_athome_padq_pm if inrange(fcons_athome_padq_pm,1,100000), by(prefill_group)
		betterbarci fcons_athome_padq_pm if inrange(fcons_athome_padq_pm,1,100000), over(prefill_group) vertical n
		betterbarci fcons_athome_padq_pm if inrange(fcons_athome_padq_pm,1,100000), over(prefill_group) by(A15) vertical n
		*/
		
		
// Save household level version of processed consumption data
	save "${gsdRawOutput}/pilot/KIHBS24_pilot_foodcons.dta", replace
	

**# FOOD ITEM LEVEL ANALYSIS 

	//  Open item-level food consumption file 
		use "${gsdData}/0-RawOutput/pilot/KIHBS24_pilot_fooditems.dta", clear	
	// Bring in household size
		merge m:1 interview__id using "${gsdRawOutput}/pilot/KIHBS24_pilot_foodcons.dta", keepusing(A16) keep(master matched) nogen
	// Set by vars and iqr factor for outlier identification
		global byvars "food__id A15"
		global iqr_fac 1.5
	// Check unit value outliers
		egen med_uv = median(unit_value), by(${byvars})
		egen mean_uv = mean(unit_value), by(${byvars})
		egen sd_uv = sd(unit_value), by(${byvars})
		egen iqr_uv = iqr(unit_value), by(${byvars})			
		// Deviation from mean according to IQR
			gen iqr_uv_dev = abs(unit_value - med_uv)/iqr_uv
			egen unit_value_out = outside(unit_value) , by(${byvars}) factor(${iqr_fac})		
		// Reorder
			order med* mean* sd*, after(unit_value)				
		// Inspect large deviations
			br q2_purch_unit q3_purch_qty qty_kglt_1 q3_purch_cost unit_value med* mean* sd* interview__key food__id responsible iqr_uv iqr_uv_dev if unit_value_out!=. & food__id!=1215 & iqr_uv>0.01
				
	// Value of consumption (at item-level)
		gen cons_value = qty_kglt_2*med_uv
		gen cons_value_pc = cons_value/A16		
		// Check cons value outliers
			egen med_consval = median(cons_value_pc), by(${byvars})
			egen mean_consval = mean(cons_value_pc), by(${byvars})
			egen sd_consval = sd(cons_value_pc), by(${byvars})
			egen iqr_consval = iqr(cons_value_pc), by(${byvars})	
		// Deviation from mean according to IQR
			gen iqr_consval_dev = abs(cons_value_pc- med_consval)/iqr_consval
			egen cons_value_out = outside(cons_value_pc) , by(${byvars}) factor(${iqr_fac})		
		// Reorder
			order cons_value* *_consval*, after(qty_kglt_1)		
		// Inspect large deviations
			br cons_value* *_consval* q3_cons_unit_tot q3_cons_qty_tot qty_kglt_2 interview__key food__id responsible calories_coeff tot_kcal_cons_fi if cons_value_out!=. & food__id!=1215 & iqr_consval>0.01
				
	// Calories per person per day
		gen kcal_cons_pc = tot_kcal_cons_fi/A16/7		
		// Check cons value outliers
			egen med_kcal = median(kcal_cons_pc), by(${byvars})
			egen mean_kcal = mean(kcal_cons_pc), by(${byvars})
			egen sd_kcal = sd(kcal_cons_pc), by(${byvars})
			egen iqr_kcal = iqr(kcal_cons_pc), by(${byvars})		
		// Deviation from mean according to IQR
			gen iqr_kcal_dev = abs(kcal_cons_pc- med_kcal)/iqr_kcal
			egen kcal_out = outside(kcal_cons_pc) , by(${byvars}) factor(${iqr_fac})		
		// Reorder
			order kcal* *_kcal iqr_kcal_dev , after(tot_kcal_cons_fi)		
		// Inspect large deviations
			br kcal* *_kcal iqr_kcal_dev q3_cons_unit_tot q3_cons_qty_tot qty_kglt_2 interview__key food__id responsible calories_coeff tot_kcal_cons_fi A16 if kcal_out!=. & food__id!=1215 & iqr_kcal>0.01	
		
	// Share of unit values, consumption value, and calories that are outliers
		gen num_uv_outlier = unit_value_out!=.
		gen num_item_purchased = q1__1==1 & unit_value!=.
		gen num_consval_outlier = cons_value_out !=. & cons_value_pc!=.
		gen num_item_cons_val= q1__2==1	& cons_value_pc!=.
		gen num_kcal_outlier = kcal_out !=. & kcal_cons_pc!=.
		gen num_item_kcal= q1__2==1	& kcal_cons_pc!=.
		// Collapse to household level 
			gcollapse (sum) num*, by(interview__id interview__key  A01 A06 A09 A15 hhid_str A16 responsible)		
		// Shares
			gen share_uv_outlier = num_uv_outlier/num_item_purchased
			gen share_consval_outlier = num_consval_outlier/num_item_cons_val
			gen share_kcal_outlier = num_kcal_outlier/num_item_kcal
		// Charts
			// Unit values
				// By county
					betterbarci share_uv_outlier, over(A01) v n pct bar ytitle("% of reported items") title("Share of unit value outliers") subtitle("by county") saving("${gsdOutput}/sh_uv_outliers_bycounty.gph", replace) xlab("")
				// By interviewer
				encode responsible, gen(interviewer)
				betterbarci share_uv_outlier, over(interviewer) v n pct bar ytitle("% of reported items") title("Share of unit value outliers") subtitle("by interviewer") saving("${gsdOutput}/sh_uv_outliers_byinterviewer.gph", replace) xlab("")
			// Value of consumption 
				// By county
					betterbarci share_consval_outlier, over(A01) v n pct bar ytitle("% of reported items") title("Share of consumption value outliers") subtitle("by county") saving("${gsdOutput}/sh_consval_outliers_bycounty.gph", replace) xlab("")
				// By interviewer
					betterbarci share_consval_outlier, over(interviewer) v n pct bar ytitle("% of reported items") title("Share of consumption value outliers") subtitle("by interviewer") saving("${gsdOutput}/sh_consval_outliers_byinterviewer.gph", replace) xlab("")
			// Calories
				// By county
					betterbarci share_kcal_outlier, over(A01) v n pct bar ytitle("% of reported items") title("Share of calorie outliers") subtitle("by county") saving("${gsdOutput}/sh_consval_outliers_bycounty.gph", replace) xlab("")
				// By interviewer
					betterbarci share_kcal_outlier, over(interviewer) v n pct bar ytitle("% of reported items") title("Share of calorie outliers") subtitle("by interviewer") saving("${gsdOutput}/sh_consval_outliers_byinterviewer.gph", replace) xlab("")