*Process raw datasets 

*HOUSEHOLDS
use "${gsdTemp}/hh_valid.dta", clear
drop a02- a08 a10_4_1 a11 a12 a13 *esult *alidation g03__1906-qf2_02__9996 name1 name2
*Other specify
//dwelling type
replace e04=5 if inlist(e04_Other,"AT THE BACK OF A SHOP","IRON SHEET MADE HOUSE","AT THE BACK OF A SHOP","CARETAKER", "ONE PERMANENT ROOM")
replace e04=6 if e04_Other=="SMALL MUD HOUSE"
rename e04_Other e04_other
replace e06=8 if e06_other=="HARD METAL SHEETS"
//floor material
replace e07=3 if inlist(e07_other,"LAMINENT","TIMBER","WOOD","WOOD PLANKS")
//wall material
replace e08=4 if regexm(e08_other,"MUD")
replace e08=5 if regexm(e08_other,"WOOD")
replace e08=6 if regexm(e08_other,"STONE")
replace e08=10 if regexm(e08_other,"IRON")
replace e08=8 if regexm(e08_other,"POLYTHENE")
//drinking water source
replace e09=11 if regexm(e09_other,"TAP") | regexm(e09_other,"PIPE") | regexm(e09_other,"NEIGH")
replace e09=4 if regexm(e09_other,"BOREH") | regexm(e09_other,"RIVER") | regexm(e09_other,"POND")
bys strat: egen mode_e09=mode(e09)
replace e09=mode_e09 if e09==96
drop mode_e09
//main toilet facility
replace e10=8 if regexm(e10_other,"NO") | regexm(e10_other,"DON") | regexm(e10_other,"BUSH")
replace e10=6 if regexm(e10_other,"PIT") 
replace e10=3 if regexm(e10_other,"FLUS") 
bys strat: egen mode_e10=mode(e10)
replace e10=mode_e10 if e10==96
drop mode_e10
//lighting source
replace e11=7 if regexm(e11_other,"SOLAR") 
replace e11=8 if regexm(e11_other,"TORCH") |  regexm(e11_other,"BATTER")
replace e11=6 if regexm(e11_other,"WOOD") 
bys strat: egen mode_e11=mode(e11)
replace e11=mode_e11 if e11==96
drop mode_e11
ren e0* e*
forval i=4/11 {
	cap confirm variable e`i'_other e`i'
	if !_rc { 
		replace e`i'_other="" if e`i'!=96
	}
}
merge 1:m interview__key using "${gsdTemp}/hhsize_adq.dta", nogen keep(match) assert(match) keepusing(adq_scale hhsize)
dropmiss *, force
qui save "${gsdData}/0-RawOutput/raw_hh_valid.dta", replace 

*HOUSEHOLD MEMBERS
use "${gsdTemp}/hhm_valid.dta", clear
*Other specify
rename (b03_Other b13_Otherspecify c07_other d17_Other d19_Other d21_Other d21_botherspecify d35_Other d37_Other d58_Other t13_1other) (b03_o b13_o c07_o d17_o d19_o d21_o d21_b_o d35_o d37_o d58_o t13_1_o)
foreach v of varlist b03 b13 c07 d17 d19 d21 d21_b d35 d37 d58 t13_1 {
	qui bys a09: egen `v'_mode_clid=mode(`v')
	dis in red "Below the number of other specify values replaced with clid mode for variable `v'"
	replace `v'=`v'_mode_clid if `v'==96 & !mi(`v'_mode_clid)

	qui bys strat: egen `v'_mode_str=mode(`v')
	dis in red "Below the number of other specify values replaced with stratum mode for variable `v'"
	replace `v'=`v'_mode_str if `v'==96 & !mi(`v'_mode_str)
	replace `v'_o="" if `v'!=96
}
replace b05_years=. if inlist(b05_years,998,999)
replace b05_years=2022-b05_years if b05_years>150 & !mi(b05_years)
dropmiss *, force
qui save "${gsdData}/0-RawOutput/raw_hhm_valid.dta", replace 

*FOOD
use "${gsdData}/0-RawOutput/food_1.dta", clear
*Other specify
//Harmonize the other specified non std units
replace f05_unita_other="PACKET" if regexm(f05_unita_other,"PACK") | regexm(f05_unita_other,"PKT")
replace f05_unita_other="BAG" if regexm(f05_unita_other,"BAG") 
replace f05_unita_other="SACHET" if regexm(f05_unita_other,"SAC") | regexm(f05_unita_other,"SAT")
replace f05_unita_other="SLICE" if regexm(f05_unita_other,"SLIC") 
replace f05_unita_other="PIECE" if regexm(f05_unita_other,"PIE") 
replace f05_unita_other="TIN" if regexm(f05_unita_other,"TIN") 
replace f05_unita_other="BOTTLE" if regexm(f05_unita_other,"BOT") 
replace f05_unita_other="CRATE" if regexm(f05_unita_other,"CRA") | regexm(f05_unita_other,"TRAY") 
replace f05_unita_other="LOAF" if regexm(f05_unita_other,"LOA") 
*In some cases it is straightforward to map to original categories
replace f05_unita=14 if regexm(f05_unita_other,"CUP")
replace f05_unita=16 if regexm(f05_unita_other,"TIN")
replace f05_unita=17 if regexm(f05_unita_other,"GLASS")
replace f05_unita=5 if regexm(f05_unita_other,"DEBE") | regexm(f05_unita_other,"BUCKET")
*In all the other cases, the piece option will apply. In the conversion table, the amounts will average/median out such instances
replace f05_unita=18 if f05_unita==96
drop f05_unita_other
preserve 
decode f2, gen(product_name)
duplicates drop f2, force
replace product_name=upper(product_name)
replace product_name=trim(product_name)
qui savesome f2 product_name a09 using "${gsdTemp}/foodnames.dta", replace
restore 
qui save "${gsdTemp}/food.dta", replace 

qui import excel "${gsdDataRaw}/Poverty prices request 2016-2020.xlsx", firstrow clear
rename (G H I J K) (yr2016 yr2017 yr2018 yr2019 yr2020)
*Standardize all prices to kg/lt 
foreach v of varlist yr2016 yr2017 yr2018 yr2019 yr2020 {
	qui replace `v'=`v'/2 if qnty==2 & uom=="Kilogram"
	qui replace `v'=`v'*2.5 if qnty==400 & uom=="Gram"
	qui replace `v'=`v'*2 if qnty==500 & inlist(uom,"Milliliter","Gram")
	qui replace `v'=`v'*4 if qnty==250 & uom=="Gram"
	qui replace `v'=`v'*10 if qnty==100 & uom=="Gram"
	qui replace `v'=`v'*15 if qnty==1 & uom=="Piece"
}
replace product_name=upper(product_name)
preserve
qui matchit Sno product_name using "${gsdTemp}/foodnames.dta", idu(f2) txtu(product_name) override
qui savesome f2 product_name Sno if similscore==1 | f2==701 using "${gsdTemp}/foodcodes.dta", replace
restore 
qui merge 1:1 product_name Sno using "${gsdTemp}/foodcodes.dta", keep(match master) nogen keepusing(f2)
qui savesome f2 yr2016 yr2017 yr2018 yr2019 yr2020 using "${gsdTemp}/uv_cpi_20162020.dta", replace

qui import excel "${gsdDataRaw}/Data request Pius.xlsx", firstrow clear
egen yr2022=rowmean(F- Q)
qui replace yr2022=yr2022/2 if qnty==2 & uom=="Kilogram"
qui replace yr2022=yr2022*2.5 if qnty==400 & uom=="Gram"
qui replace yr2022=yr2022*2 if qnty==500 & inlist(uom,"Milliliter","Gram")
qui replace yr2022=yr2022*4 if qnty==250 & uom=="Gram"
qui replace yr2022=yr2022*10 if qnty==100 & uom=="Gram"
qui replace yr2022=yr2022*10.5 if qnty==95 & uom=="Gram"
qui replace yr2022=yr2022*15 if qnty==1 & uom=="Piece"
replace product_name=upper(product_name)
drop F- Q qnty uom
preserve
qui matchit Sno product_name using "${gsdTemp}/foodnames.dta", idu(f2) txtu(product_name) override
qui savesome f2 product_name Sno if similscore==1 using "${gsdTemp}/foodcodes2022.dta", replace
restore 
qui merge 1:1 product_name Sno using "${gsdTemp}/foodcodes2022.dta", keep(match master) nogen keepusing(f2)
replace f2=1005 if product_name=="FOOD SEASONING (E.G. ROYCO, KNORR, ETC), VINEGAR, YEAST, CHILLI,PILAU MASALA" 
replace f2=1007 if product_name=="GINGER-TANGAWIZI/MUSTARD/SPICES" 
replace f2=905 if product_name=="JAM,MARMALADE,HONEY" 
replace f2=410 if product_name=="MILK SOUR -  MALA" 
replace f2=123 if product_name=="MIXED  AND FORTIFIED PORRIDGE FLOUR JOINED" 
replace f2=211 if product_name=="OFFALS (MATUMBO, LIVER AND KIDNEY)" 
replace f2=701 if product_name=="ONION -LEEKS AND BULBS" 
replace f2=120 if product_name=="SORGHUM (GRAIN AND FLOUR)" 
replace f2=117 if product_name=="WIMBI (GRAIN AND FLOUR)" 
merge 1:1 f2 using "${gsdTemp}/uv_cpi_20162020.dta", keep(1 3) assert(1 3)
keeporder f2 yr2016 yr2017 yr2018 yr2019 yr2020 yr2022
qui save "${gsdTemp}/uv_cpi_20162022.dta", replace

*For 2015, compute the UV distribution
use "${gsdDataRaw}/kihbs_1516/food_kihbs1516.dta", clear 
merge m:1 clid hhid using "${gsdDataRaw}/kihbs_1516/kihbs15_consagg.dta", keepusing(weight resid) keep(match) assert(match) nogen 
gen nat=1
collapse (sum) N=nat (min) min= kl_uprice (p10) p10=kl_uprice (p25) p25= kl_uprice (p50) p50= kl_uprice (mean) mean= kl_uprice (p75) p75= kl_uprice (p90) p90= kl_uprice (p95) p95= kl_uprice (p99) p99= kl_uprice (max) max= kl_uprice weight [aw=weight],by (item_code resid)
rename * kihbs15_* 
rename (kihbs15_item_code kihbs15_resid) (f2 resid)
sort f2 resid
qui savesome f2 resid kihbs15_p50 kihbs15_mean using "${gsdTemp}/uv_2015.dta", replace 

use "${gsdDataRaw}/kihbs_1516/wasay1516_r.dta",clear
gen resid=1
append using "${gsdDataRaw}/kihbs_1516/wasay1516_u.dta"
replace resid=2 if mi(resid)
lab def resid 1 "Rural" 2 "Urban"
lab val resid resid
qui save "${gsdDataRaw}/kihbs_1516/wasay1516.dta", replace 

use "${gsdDataRaw}/2020/rural_uv.dta",clear
gen resid=1
append using "${gsdDataRaw}/2020/urban_uv.dta"
replace resid=2 if mi(resid)
rename (item_code p50) (f2  p50_2020)
qui save "${gsdDataRaw}/2020/uv_2020.dta", replace 

qui copy "${gsdDataRaw}/kihbs_1516/wasay1516_u.dta" "${gsdData}/1-CleanInput/wasay1516_u.dta", replace
qui copy "${gsdDataRaw}/kihbs_1516/wasay1516_r.dta" "${gsdData}/1-CleanInput/wasay1516_r.dta", replace