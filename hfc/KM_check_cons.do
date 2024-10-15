//  Open food consumption file 
	use "${gsdData}/0-RawOutput/pilot/KIHBS24_pilot_fooditems.dta", clear
	
// Check unit value outliers
	egen med_uv = median(unit_value), by(food__id)
	egen mean_uv = mean(unit_value), by(food__id)
	egen sd_uv = sd(unit_value), by(food__id)
	egen iqr_uv = iqr(unit_value), by(food__id)
	
// Deviation from median
	gen med_uv_dev = (unit_value-med_uv)/med_uv
	
// Deviation from mean according to IQR
	gen iqr_uv_dev = abs(unit_value - med_uv)/iqr_uv
	egen unit_value_out = outside(unit_value) , by(food__id A15) factor(1.5)
	
// Reorder
	order med* mean* sd*, after(unit_value)
	
	
// Inspect large deviations
	*br q2_purch_unit q3_purch_qty qty_kglt_1 q3_purch_cost unit_value med* mean* sd* interview__key food__id responsible if med_uv_dev<-0.8 & med_uv_dev!=. & food__id!=1215
	*br q2_purch_unit q3_purch_qty qty_kglt_1 q3_purch_cost unit_value med* mean* sd* interview__key food__id responsible if med_uv_dev>10 & med_uv_dev!=. & food__id!=1215
	*br q2_purch_unit q3_purch_qty qty_kglt_1 q3_purch_cost unit_value med* mean* sd* interview__key food__id responsible iqr_uv iqr_uv_dev if iqr_uv_dev>=5 & iqr_uv_dev!=. & food__id!=1215 & iqr_uv>0.01
	br q2_purch_unit q3_purch_qty qty_kglt_1 q3_purch_cost unit_value med* mean* sd* interview__key food__id responsible iqr_uv iqr_uv_dev if unit_value_out!=. & food__id!=1215
	
// Bring in household size
	preserve
		use "${gsdDataRaw}/household_roster.dta", clear 
		gen hhsize = 1
		collapse (sum) hhsize, by(interview__key)
		tempfile hhsize
		save `hhsize'
	restore
	merge m:1 interview__key using `hhsize', keep(master match)
	
// Check value of consumption 
	gen cons_value = qty_kglt_2*med_uv
	gen cons_value_pc = cons_value/hhsize
	
// Check cons value outliers
	egen med_consval = median(cons_value_pc), by(food__id)
	egen mean_consval = mean(cons_value_pc), by(food__id)
	egen sd_consval = sd(cons_value_pc), by(food__id)
	egen iqr_consval = iqr(cons_value_pc), by(food__id)
	
// Deviation from median
	gen med_consval_dev = (cons_value_pc-med_consval)/med_consval
	
// Deviation from mean according to IQR
	gen iqr_consval_dev = abs(cons_value_pc- med_consval)/iqr_consval
	egen cons_value_out = outside(cons_value_pc) , by(food__id A15) factor(1.5)

	
// Reorder
	order cons_value* *_consval*, after(qty_kglt_1)
	
// Inspect large deviations
	*br cons_value* *_consval* q3_cons_unit_tot q3_cons_qty_tot qty_kglt_2 interview__key food__id responsible calories_coeff tot_kcal_cons_fi if med_consval_dev<-0.8 & med_consval_dev!=.
	*br cons_value* *_consval* q3_cons_unit_tot q3_cons_qty_tot qty_kglt_2 interview__key food__id responsible calories_coeff tot_kcal_cons_fi if med_consval_dev>10 & med_consval_dev!=.
	*br cons_value* *_consval* q3_cons_unit_tot q3_cons_qty_tot qty_kglt_2 interview__key food__id responsible calories_coeff tot_kcal_cons_fi if iqr_consval_dev>=5 & iqr_consval_dev!=. & food__id!=1215 & iqr_consval>0.01
	br cons_value* *_consval* q3_cons_unit_tot q3_cons_qty_tot qty_kglt_2 interview__key food__id responsible calories_coeff tot_kcal_cons_fi if cons_value_out!=. & food__id!=1215
	

	
// Share of unit values and consumption value that are outliers
	gen num_uv_outlier = unit_value_out!=.
	gen num_item_purchased = q1__1==1 & unit_value!=.
	gen num_consval_outlier = cons_value_out !=. & cons_value_pc!=.
	gen num_item_cons_val= q1__2==1
	
// Collapse to household level 
	gcollapse (sum) num_uv_outlier num_item_purchased num_consval_outlier num_item_cons_val, by(interview__id interview__key  A01 A06 A09 A15 hhid_str A16 responsible)
	
	// Shares
		gen share_uv_outlier = num_uv_outlier/num_item_purchased
		gen share_consval_outlier = num_consval_outlier/num_item_cons_val
		
		betterbarci share_uv_outlier, over(A01) v n pct bar ytitle("% of reported items") title("Share of unit value outliers") saving("${gsdOutput}/sh_uv_outliers_bycounty.gph", replace) xlab("")
		betterbarci share_consval_outlier, over(A01) v n pct bar ytitle("% of reported items") title("Share of consumption value outliers") saving("${gsdOutput}/sh_consval_outliers_bycounty.gph", replace) xlab("")
