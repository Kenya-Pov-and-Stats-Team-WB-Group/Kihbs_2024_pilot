//  Open food consumption file 
	use "${gsdData}/0-RawOutput/pilot/KIHBS24_pilot_fooditems.dta", clear
	
// Check unit value outliers
	egen med_uv = median(unit_value), by(food__id)
	egen mean_uv = mean(unit_value), by(food__id)
	egen sd_uv = sd(unit_value), by(food__id)
	
// Deviation from median
	gen med_uv_dev = (unit_value-med_uv)/med_uv
	
	
// Reorder
	order med* mean* sd*, after(unit_value)
	
	
// Inspect large deviations
	br if med_uv_dev<-0.8 & med_uv_dev!=.
	br if med_uv_dev>10 & med_uv_dev!=.
	
// Bring in household size
	preserve
		use "${gsdDataRaw}/suso/pilot/household_roster.dta", clear 
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
	
// Deviation from median
	gen med_consval_dev = (cons_value_pc-med_consval)/med_consval
	
// Reorder
	order cons_value* *_consval*, after(qty_kglt_1)

	
// Inspect large deviations
	br if med_consval_dev<-0.8 & med_consval_dev!=.
	br if med_consval_dev>10 & med_consval_dev!=.