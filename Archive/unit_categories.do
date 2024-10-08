**# Cereals

*Preliminarly, retrieve names of all the food items we asked about in the NSU 
use "${gsdDataRaw}/suso/nsu/KIHBS_NSU.dta",clear
keep interview__key YA03_cereals__*
greshape long YA03_cereals__, i( interview__key ) j(cereals__id) 
destring cereals__id, force replace
duplicates drop cereals__id, force
tempfile all_cereals_nsu
qui save `all_cereals_nsu', replace

*Then, retrieve names of all the food items we plan to ask in the  KIHBS questionnaire 
import excel "${gsdDataRaw}/[cereals_items]KIHBS 2024 2025 Survey Working Copy.xlsx", sheet("Categories") firstrow clear
rename value cereals__id
tempfile all_cereals_kihbs
qui save `all_cereals_kihbs', replace

*Then, preliminarly, save the caloric conversion factors and the old codes from KCHS/KIHBS
qui import excel "${gsdDataRaw}/items_calories_oldcodes.xlsx", sheet("cereals") firstrow clear
destring Fat_g, replace force
rename Energy_kcal calories
tempfile calories_oldcodes_cereals
qui save `calories_oldcodes_cereals', replace

use "${gsdTemp}/cereals_conversion_wide.dta", clear
merge m:1 cereals__id using `all_cereals_nsu'
rename _merge _merge_conv_nsu 
merge m:1 cereals__id using `all_cereals_kihbs'
merge m:1 cereals__id using `calories_oldcodes_cereals', nogen keep(1 3)

*Fix issue with rice types (in nsu survey combined into a single item, now need to unpack)
expand 5 if cereals__id==1102, g(a)
bys cereals__id units_cereals__id cereals_size__id: egen b=seq() if a==1, from(1) to(4)
replace cereals__id=1103 if a==1 & b==1
replace cereals__id=1104 if a==1 & b==2
replace cereals__id=1105 if a==1 & b==3
replace cereals__id=11051 if a==1 & b==4
sort cereals__id units_cereals__id cereals_size__id
drop if inlist(cereals__id,1103,1104,1105,11051) & mi(units_cereals__id)
lab def cereals__id 1102 "Aromatic Unbroken Rice (Pishori/Basmati e.t.c)" 1103 "Non Aromatic (Unbroken) White Rice" 1104 "Broken white rice (Aromatic or Non Aromatic)" 1105 "Brown Rice" 11051 "Other Rice", modify add

*Fix issue with flour types (in nsu survey combined into a single item, now need to unpack)
drop a b
expand 4 if cereals__id==1201, g(a)
bys cereals__id units_cereals__id cereals_size__id: egen b=seq() if a==1, from(1) to(3)
replace cereals__id=1202 if a==1 & b==1
replace cereals__id=1203 if a==1 & b==2
replace cereals__id=12031 if a==1 & b==3
sort cereals__id units_cereals__id cereals_size__id
drop if inlist(cereals__id,1202,1203,12031) & mi(units_cereals__id)
lab def cereals__id 1201 "Flour of wheat (white)" 1202 "Flour of wheat (white-fortified)" 1203 "Flour of wheat (brown)" 12031 "Other Flour of wheat" , modify add

*Fix issue with flour types (in nsu survey combined into a single item, now need to unpack)
drop a b
expand 5 if cereals__id==1210, g(a)
bys cereals__id units_cereals__id cereals_size__id: egen b=seq() if a==1, from(1) to(4)
replace cereals__id=1211 if a==1 & b==1
replace cereals__id=1212 if a==1 & b==2
replace cereals__id=1213 if a==1 & b==3
replace cereals__id=1214 if a==1 & b==4
sort cereals__id units_cereals__id cereals_size__id
drop if inlist(cereals__id,1211,1212,1213,1214) & mi(units_cereals__id)
lab def cereals__id 1210 "Flour of maize-loose (white)" 1211 "Flour of maize-sifted (white)" 1212 "Flour or maize (yellow)" 1213 "Flour of maize (fortified)" 1214 "Other flour (oats,oats, quinoa)" 1215 "Cost of milling" , modify add

*Fix issue with bread types (in nsu survey combined into a single item, now need to unpack)
drop a b
expand 3 if cereals__id==1302, g(a)
bys cereals__id units_cereals__id cereals_size__id: egen b=seq() if a==1, from(1) to(2)
replace cereals__id=1301 if a==1 & b==1
replace cereals__id=1304 if a==1 & b==2
sort cereals__id units_cereals__id cereals_size__id
drop if inlist(cereals__id,1301,1304) & mi(_merge_conv_nsu)
lab def cereals__id 1301 "Bread, brown" 1302 "Bread, white" 1304 "Other Bread", modify add

*Fix issue with other bakery products types (in nsu survey combined into a single item, now need to unpack)
drop a b
expand 2 if cereals__id==1407, g(a)
replace cereals__id=1408 if a==1 
sort cereals__id units_cereals__id cereals_size__id
lab def cereals__id 1408 "Other bakery products", modify add
drop if inlist(cereals__id,1408) & mi(units_cereals__id)

*Fix issue with other raw cereals (in nsu survey combined into a single item, now need to unpack)
drop a 
expand 2 if cereals__id==1109, g(a)
replace cereals__id=1111 if a==1 
sort cereals__id units_cereals__id cereals_size__id
lab def cereals__id 1111 "Other raw cereals", modify add
drop if inlist(cereals__id,1111) & mi(units_cereals__id)

*Fix issue with samosas (apply same factors of donuts)
drop a 
expand 2 if cereals__id==1403, g(a)
replace cereals__id=1404 if a==1 
sort cereals__id units_cereals__id cereals_size__id
lab def cereals__id 1404 "Samosas", modify add
drop if inlist(cereals__id,1404) & mi(units_cereals__id)

lab def cereals__id 1602 "Other pasta products", modify add
lab def cereals__id 1505 "Other breakfast cereals", modify add

drop if cereals__id==13031

*Create the unique identifier for the combination of item-unit-size
qui decode units_cereals__id,gen( units_cereals__ids)
qui decode cereals_size__id,gen( cereals_size__ids)
qui gen unitsize=units_cereals__ids+" "+cereals_size__ids
drop a title parentvalue attachmentname _merge _merge_conv_nsu 

*For each county
forval c=1/47 {
	 confirm e weight_kg`c' //ensure that a conversion factor is available
	if _rc!=0 {
		gen weight_kg`c'=. //if not, create a county specific variable
	}
 	 confirm e weight_kg`c'
 	if _rc==0 { //and enter the conversion factors for the SUs
		qui replace weight_kg`c'=1 if unitsize=="Kilo"
		qui replace weight_kg`c'=.001 if unitsize=="Gram"
 	}
}
*Generate conversion factors at province level, for lookup tables
order weight_kg*, sequential
egen conv_prov1=rowmean(weight_kg1-weight_kg6)
egen conv_prov2=rowmean(weight_kg7-weight_kg9)
egen conv_prov3=rowmean(weight_kg10-weight_kg17)
egen conv_prov4=rowmean(weight_kg18-weight_kg22)
egen conv_prov5=rowmean(weight_kg23-weight_kg36)
egen conv_prov6=rowmean(weight_kg37-weight_kg40)
egen conv_prov7=rowmean(weight_kg41-weight_kg46)
egen conv_prov8=rowmean(weight_kg47)

*Create category excel for the NSU available for cereals
gen unit_size_code=(units_cereals__id*100)+cereals_size__id
preserve
duplicates drop unit_size_code,force
drop if mi(unit_size_code)
insobs 2,after(_N)
br unit_size_code  unitsize
egen b=seq() if mi(unitsize) , from(1) to(2)
replace unit_size_code=b if mi(unit_size_code) & !mi(b) 
replace unitsize="Gram" if unit_size_code==1
replace unitsize="Kilogram" if unit_size_code==2
clonevar value=unit_size_code
gen title=unitsize
gen parentvalue=.
gen attachmentname=.
qui export excel value title parentvalue attachmentname using "${gsdTemp}/unit_size_cereals.xlsx", firstrow(variables) nolabel replace
restore

*Create lookup table for units to be filtered
gen itmcd=cereals__id
gen untcd=unit_size_code
insobs 2,after(_N)
br itmcd untcd
egen b=seq() if mi(untcd) & mi(itmcd), from(1) to(2)
replace untcd=b if mi(untcd) & !mi(b) 
levelsof itmcd if untcd!=2 | mi(untcd), loc(item) 
foreach i of local item {
	qui expand 2 if inlist(untcd,1,2) & mi(itmcd),gen(exp_`i')
	qui replace itmcd=`i' if exp_`i'==1 
	drop exp_`i'
}
drop if mi(itmcd) 
drop if mi(untcd)
sort itmcd untcd
gen rowcode=_n 
forval p=1/8 {
	qui replace conv_prov`p'=.001 if untcd==1
	qui replace conv_prov`p'=1 if untcd==2
}
br rowcode itmcd untcd 
qui export delimited rowcode itmcd untcd using "${gsdTemp}/cereals_NSU.txt", delimiter(tab) replace

*Create lookup table for conversion factors
drop rowcode
gen rowcode=itmcd*10000+untcd
recast int rowcode
format %13.0f rowcode
duplicates drop rowcode,force
qui export delimited rowcode conv_prov* using "${gsdTemp}/cereals_convfactors.txt", delimiter(tab) replace

*Create lookup table for caloric factors
duplicates drop cereals__id, force 
drop if mi(cereals__id)
drop rowcode 
gen rowcode=cereals__id
gen newcode=cereals__id
qui export delimited rowcode newcode calories using "${gsdTemp}/calories_cereals.txt", delimiter(tab) replace

**# Meat
use "${gsdDataRaw}/suso/nsu/KIHBS_NSU.dta",clear
keep interview__key YA03_meats_fish__*
greshape long YA03_meats_fish__, i( interview__key ) j(meat__id) 
destring meat__id, force replace
duplicates drop meat__id, force
tempfile all_meat
qui save `all_meat', replace

qui import excel "${gsdDataRaw}/items_calories_oldcodes.xlsx", sheet("meat") firstrow clear
destring Fat_g, replace force
tempfile calories_oldcodes_meat
qui save `calories_oldcodes_meat', replace

use "${gsdTemp}/meat_conversion_wide.dta", clear
merge m:1 meat__id using `all_meat', nogen keepusing(YA03_meats_fish__) keep(2 3) assert(2 3)
drop YA03_meats_fish__
merge m:1 meat__id using `calories_oldcodes_meat', nogen keepusing(Edible_conversion_factor- oldcode) keep(1 3) //merge them in
rename Energy_kcal calories

qui decode units_meat__id,gen( units_meat__ids)
qui decode meat_size__id,gen( meat_size__ids)
qui gen unitsize=units_meat__ids+" "+meat_size__ids
qui insobs 4
qui egen a=seq() if mi(units_meat__id), from(1) to(4)
qui replace unitsize="Kilo" if a==1
qui replace unitsize="Liter" if a==2
qui replace unitsize="Gram" if a==3
qui replace unitsize="Milliliter" if a==4
forval c=1/47 {
	 confirm e weight_kg`c'
	if _rc!=0 {
		gen weight_kg`c'=.
	}
 	 confirm e weight_kg`c'
 	if _rc==0 {
		qui replace weight_kg`c'=1 if unitsize=="Kilo"
		qui replace weight_kg`c'=1 if unitsize=="Liter"
		qui replace weight_kg`c'=.01 if unitsize=="Gram"
		qui replace weight_kg`c'=.01 if unitsize=="Milliliter"
 	}
}

qui bys meat__id: gen fitem_unit_size_code=_n
qui replace fitem_unit_size_code=fitem_unit_size_code+4 if !inlist(unitsize,"Kilo","Liter","Gram","Milliliter")
qui replace fitem_unit_size_code=1 if unitsize=="Kilo"
qui replace fitem_unit_size_code=2 if unitsize=="Liter"
qui replace fitem_unit_size_code=3 if unitsize=="Gram"
qui replace fitem_unit_size_code=4 if unitsize=="Milliliter"
qui gen code_fitem_unit_size_code=(meat__id*1000)+fitem_unit_size_code
qui format %19.0g code_fitem_unit_size_code 

qui bys unitsize: gen x=_n
qui tostring x, replace 
qui replace unitsize=unitsize+" "+"(#" + x +"#)" if code_fitem_unit_size_code> 1000 & !mi(code_fitem_unit_size_code)

qui replace code_fitem_unit_size_code=fitem_unit_size_code if mi(code_fitem_unit_size_code) & !mi(fitem_unit_size_code)

keeporder meat__id units_meat__id meat_size__id unitsize code_fitem_unit_size_code weight_kg* calories oldcode
qui clonevar value=code_fitem_unit_size_code
qui clonevar title=unitsize
qui clonevar parentvalue=meat__id
replace parentvalue=code_fitem_unit_size_code if inrange(code_fitem_unit_size_code,1,4)
qui gen attachmentname=.
sort meat__id value

//Export units for each meat type
qui export excel value title parentvalue attachmentname using "${gsdTemp}/unit_size_meat.xlsx", firstrow(variables) nolabel replace
qui save "${gsdTemp}/unit_size_meat.dta",replace

clonevar rowcode=code_fitem_unit_size_code

qui export delimited rowcode weight_kg1-weight_kg10 using "${gsdTemp}/unit_size_meat_counties1to10.txt", replace  delimiter(tab)
qui export delimited rowcode weight_kg11-weight_kg20 using "${gsdTemp}/unit_size_meat_counties11to20.txt", replace  delimiter(tab)
qui export delimited rowcode weight_kg21-weight_kg30 using "${gsdTemp}/unit_size_meat_counties21to30.txt", replace  delimiter(tab)
qui export delimited rowcode weight_kg31-weight_kg40 using "${gsdTemp}/unit_size_meat_counties31to40.txt", replace  delimiter(tab)
qui export delimited rowcode weight_kg41-weight_kg47 using "${gsdTemp}/unit_size_meat_counties41to47.txt", replace  delimiter(tab)

duplicates drop meat__id,force

drop rowcode 
gen rowcode=meat__id
gen newcode=rowcode
drop if mi(rowcode)
qui export delimited rowcode newcode oldcode calories using "${gsdTemp}/oldcodes_calories_meat.txt", replace  delimiter(tab)

**# Oil and fats 
use "${gsdDataRaw}/suso/nsu/KIHBS_NSU.dta",clear
keep interview__key YA03_oil_fats__*
greshape long YA03_oil_fats__, i( interview__key ) j(oil_fats__id) 
destring oil_fats__id, force replace
duplicates drop oil_fats__id, force
tempfile all_oil_fats
qui save `all_oil_fats', replace

qui import excel "${gsdDataRaw}/items_calories_oldcodes.xlsx", sheet("oil_fats") firstrow clear
destring Fat_g, replace force
tempfile calories_oldcodes_oil_fats
qui save `calories_oldcodes_oil_fats', replace

use "${gsdTemp}/oil_fats_conversion_wide.dta", clear
merge m:1 oil_fats__id using `all_oil_fats', nogen keepusing(YA03_oil_fats__) keep(2 3) assert(2 3)
drop YA03_oil_fats__
merge m:1 oil_fats__id using `calories_oldcodes_oil_fats', nogen keepusing(Edible_conversion_factor- oldcode) keep(1 3) //merge them in
rename Energy_kcal calories

qui decode units_oil_fats__id,gen( units_oil_fats__ids)
qui decode oil_fats_size__id,gen( oil_fats_size__ids)
qui gen unitsize=units_oil_fats__ids+" "+oil_fats_size__ids
qui insobs 4
qui egen a=seq() if mi(units_oil_fats__id), from(1) to(4)
qui replace unitsize="Kilo" if a==1
qui replace unitsize="Liter" if a==2
qui replace unitsize="Gram" if a==3
qui replace unitsize="Milliliter" if a==4
forval c=1/47 {
	cap gen weight_kg`c'=.	
	confirm e weight_kg`c'
	if _rc==0 {
	qui replace weight_kg`c'=1 if unitsize=="Kilo"
	qui replace weight_kg`c'=1 if unitsize=="Liter"
	qui replace weight_kg`c'=.01 if unitsize=="Gram"
	qui replace weight_kg`c'=.01 if unitsize=="Milliliter"
	 }
}
order weight_kg*, sequential
egen median_prov1=rowmedian(weight_kg1-weight_kg6)
egen median_prov2=rowmedian(weight_kg7-weight_kg9)
egen median_prov3=rowmedian(weight_kg10-weight_kg17)
egen median_prov4=rowmedian(weight_kg18-weight_kg22)
egen median_prov5=rowmedian(weight_kg23-weight_kg36)
egen median_prov6=rowmedian(weight_kg37-weight_kg40)
egen median_prov7=rowmedian(weight_kg41-weight_kg46)
egen median_prov8=rowmedian(weight_kg47)

forval c=1/6 {
	replace weight_kg`c'=median_prov1 if mi(weight_kg`c')
}
forval c=7/9 {
	replace weight_kg`c'=median_prov2 if mi(weight_kg`c')
}
forval c=10/17 {
	replace weight_kg`c'=median_prov3 if mi(weight_kg`c')
} 
forval c=18/22 {
	replace weight_kg`c'=median_prov4 if mi(weight_kg`c')
} 
forval c=23/36 {
	replace weight_kg`c'=median_prov5 if mi(weight_kg`c')
} 
forval c=37/40 {
	replace weight_kg`c'=median_prov6 if mi(weight_kg`c')
} 
forval c=41/46 {
	replace weight_kg`c'=median_prov7 if mi(weight_kg`c')
} 
replace weight_kg47=median_prov8 if mi(weight_kg47)

qui bys oil_fats__id: gen fitem_unit_size_code=_n
qui replace fitem_unit_size_code=fitem_unit_size_code+4 if !inlist(unitsize,"Kilo","Liter","Gram","Milliliter")
qui replace fitem_unit_size_code=1 if unitsize=="Kilo"
qui replace fitem_unit_size_code=2 if unitsize=="Liter"
qui replace fitem_unit_size_code=3 if unitsize=="Gram"
qui replace fitem_unit_size_code=4 if unitsize=="Milliliter"
qui gen code_fitem_unit_size_code=(oil_fats__id*1000)+fitem_unit_size_code
qui format %19.0g code_fitem_unit_size_code 

qui bys unitsize: gen x=_n
qui tostring x, replace 
qui replace unitsize=unitsize+" "+"(#" + x +"#)" if code_fitem_unit_size_code> 1000 & !mi(code_fitem_unit_size_code)

qui replace code_fitem_unit_size_code=fitem_unit_size_code if mi(code_fitem_unit_size_code) & !mi(fitem_unit_size_code)

keeporder oil_fats__id units_oil_fats__id oil_fats_size__id unitsize code_fitem_unit_size_code weight_kg* calories oldcode
qui clonevar value=code_fitem_unit_size_code
qui clonevar title=unitsize
qui clonevar parentvalue=oil_fats__id
replace parentvalue=code_fitem_unit_size_code if inrange(code_fitem_unit_size_code,1,4)
qui gen attachmentname=.
sort oil_fats__id value

//Export units for each cereal type
qui export excel value title parentvalue attachmentname using "${gsdTemp}/unit_size_oil_fats.xlsx", firstrow(variables) nolabel replace
qui save "${gsdTemp}/unit_size_oil_fats.dta",replace

clonevar rowcode=code_fitem_unit_size_code

qui export delimited rowcode weight_kg1-weight_kg10 using "${gsdTemp}/unit_size_oil_fats_counties1to10.txt", replace  delimiter(tab)
qui export delimited rowcode weight_kg11-weight_kg20 using "${gsdTemp}/unit_size_oil_fats_counties11to19.txt", replace  delimiter(tab)
qui export delimited rowcode weight_kg21-weight_kg30 using "${gsdTemp}/unit_size_oil_fats_counties21to30.txt", replace  delimiter(tab)
qui export delimited rowcode weight_kg31-weight_kg40 using "${gsdTemp}/unit_size_oil_fats_counties31to40.txt", replace  delimiter(tab)
qui export delimited rowcode weight_kg41-weight_kg47 using "${gsdTemp}/unit_size_oil_fats_counties41to47.txt", replace  delimiter(tab)

duplicates drop oil_fats__id,force

drop rowcode 
gen rowcode=oil_fats__id
gen newcode=rowcode
drop if mi(rowcode)
qui export delimited rowcode newcode oldcode calories using "${gsdTemp}/oldcodes_calories_oil_fats.txt", replace  delimiter(tab)

**# Veges 1
use "${gsdDataRaw}/suso/nsu/KIHBS_NSU.dta",clear
keep interview__key YA03_veges_tubers__*
qui greshape long YA03_veges_tubers__, i( interview__key ) j(veges__id) 
destring veges__id, force replace
duplicates drop veges__id, force
tempfile all_veges_tubers
qui save `all_veges_tubers', replace

qui import excel "${gsdDataRaw}/items_calories_oldcodes.xlsx", sheet("veges1") firstrow clear
destring Fat_g, replace force
tempfile calories_oldcodes_veges1
qui save `calories_oldcodes_veges1', replace

use "${gsdTemp}/veges_conversion_wide.dta", clear
merge m:1 veges__id using `all_veges_tubers', nogen keepusing(YA03_veges_tubers__) keep(2 3) assert(2 3)
drop YA03_veges_tubers__
keep if inlist(veges__id, 2701,	2702,	2703,	2705,	2706,	2707,	2708,	2709,	2712,	2713,	2714,	2715,	2716,	2717,	2718,	2719,	2720,	2721,	2722,	2723,	2724,	2725,	2726,	2727,	2728)
merge m:1 veges__id using `calories_oldcodes_veges1', nogen keepusing(Edible_conversion_factor- oldcode) keep(1 3) //merge them in
rename Energy_kcal calories 

qui decode units_veges__id,gen( units_veges__ids)
qui decode veges_size__id,gen( veges_size__ids)
qui gen unitsize=units_veges__ids+" "+veges_size__ids
qui insobs 4
qui egen a=seq() if mi(units_veges__id), from(1) to(4)
qui replace unitsize="Kilo" if a==1
qui replace unitsize="Liter" if a==2
qui replace unitsize="Gram" if a==3
qui replace unitsize="Milliliter" if a==4
forval c=1/47 {
	 confirm e weight_kg`c'
	if _rc!=0 {
		gen weight_kg`c'=.
	}
 	 confirm e weight_kg`c'
 	if _rc==0 {
		qui replace weight_kg`c'=1 if unitsize=="Kilo"
		qui replace weight_kg`c'=1 if unitsize=="Liter"
		qui replace weight_kg`c'=.01 if unitsize=="Gram"
		qui replace weight_kg`c'=.01 if unitsize=="Milliliter"
 	}
}

qui bys veges__id: gen fitem_unit_size_code=_n
qui replace fitem_unit_size_code=fitem_unit_size_code+4 if !inlist(unitsize,"Kilo","Liter","Gram","Milliliter")
qui replace fitem_unit_size_code=1 if unitsize=="Kilo"
qui replace fitem_unit_size_code=2 if unitsize=="Liter"
qui replace fitem_unit_size_code=3 if unitsize=="Gram"
qui replace fitem_unit_size_code=4 if unitsize=="Milliliter"
qui gen code_fitem_unit_size_code=(veges__id*1000)+fitem_unit_size_code
qui format %19.0g code_fitem_unit_size_code 

qui bys unitsize: gen x=_n
qui tostring x, replace 
qui replace unitsize=unitsize+" "+"(#" + x +"#)" if code_fitem_unit_size_code> 1000 & !mi(code_fitem_unit_size_code)

qui replace code_fitem_unit_size_code=fitem_unit_size_code if mi(code_fitem_unit_size_code) & !mi(fitem_unit_size_code)

keeporder veges__id units_veges__id veges_size__id unitsize code_fitem_unit_size_code weight_kg* calories oldcode
qui clonevar value=code_fitem_unit_size_code
qui clonevar title=unitsize
qui clonevar parentvalue=veges__id
replace parentvalue=code_fitem_unit_size_code if inrange(code_fitem_unit_size_code,1,4)
qui gen attachmentname=.
sort veges__id value

//Export units for each veges type
qui export excel value title parentvalue attachmentname using "${gsdTemp}/unit_size_veges1.xlsx", firstrow(variables) nolabel replace
qui save "${gsdTemp}/unit_size_veges.dta",replace

clonevar rowcode=code_fitem_unit_size_code

qui export delimited rowcode weight_kg1-weight_kg10 using "${gsdTemp}/unit_size_veges1_counties1to10.txt", replace  delimiter(tab)
qui export delimited rowcode weight_kg11-weight_kg20 using "${gsdTemp}/unit_size_veges1_counties11to20.txt", replace  delimiter(tab)
qui export delimited rowcode weight_kg21-weight_kg30 using "${gsdTemp}/unit_size_veges1_counties21to30.txt", replace  delimiter(tab)
qui export delimited rowcode weight_kg31-weight_kg40 using "${gsdTemp}/unit_size_veges1_counties31to40.txt", replace  delimiter(tab)
qui export delimited rowcode weight_kg41-weight_kg47 using "${gsdTemp}/unit_size_veges1_counties41to47.txt", replace  delimiter(tab)

duplicates drop veges__id,force

drop rowcode 
gen rowcode=veges__id
gen newcode=rowcode
drop if mi(rowcode)
qui export delimited rowcode newcode oldcode calories using "${gsdTemp}/oldcodes_calories_veges1.txt", replace  delimiter(tab)

**# Veges 2
use "${gsdDataRaw}/suso/nsu/KIHBS_NSU.dta",clear
keep interview__key YA03_veges_tubers__*
greshape long YA03_veges_tubers__, i( interview__key ) j(veges__id) 
destring veges__id, force replace
duplicates drop veges__id, force
tempfile all_veges_tubers
qui save `all_veges_tubers', replace

qui import excel "${gsdDataRaw}/items_calories_oldcodes.xlsx", sheet("veges2") firstrow clear
destring Fat_g, replace force
tempfile calories_oldcodes_veges2
qui save `calories_oldcodes_veges2', replace

use "${gsdTemp}/veges_conversion_wide.dta", clear
merge m:1 veges__id using `all_veges_tubers', nogen keepusing(YA03_veges_tubers__) keep(2 3) assert(2 3)
drop YA03_veges_tubers__
keep if inlist(veges__id, 2731,	2732,	2733,	2734,	2735,	2736,	2737,	2738,	2741,	2742,	2743,	2744,	2745,	2746,	2747,	2749,	2761,	2762,	27051,	27071,	27072,	27073,	27151,	27161)
merge m:1 veges__id using `calories_oldcodes_veges2', nogen keepusing(Edible_conversion_factor- oldcode) keep(1 3) //merge them in
rename Energy_kcal calories 

qui decode veges__id,gen( veges__ids)
qui decode units_veges__id,gen( units_veges__ids)
qui decode veges_size__id,gen( veges_size__ids)
qui tostring veges__id,gen(a)
qui tostring units_veges__id,gen(b)
qui tostring veges_size__id,gen(c)
gen fitem_unit_size_code= a+ b+ c
destring fitem_unit_size_code, replace 
drop a b c

isid fitem_unit_size_code
qui gen unitsize=units_veges__ids+" "+veges_size__ids
qui insobs 4
qui egen a=seq() if mi(units_veges__id), from(1) to(4)
qui replace unitsize="Kilo" if a==1
qui replace unitsize="Liter" if a==2
qui replace unitsize="Gram" if a==3
qui replace unitsize="Milliliter" if a==4
replace fitem_unit_size_code=a if !mi(a)

isid fitem_unit_size_code
forval c=1/47 {
	cap confirm e weight_kg`c'
	if _rc!=0 {
		gen weight_kg`c'=.
	}
 	 confirm e weight_kg`c'
 	if _rc==0 {
		qui replace weight_kg`c'=1 if unitsize=="Kilo"
		qui replace weight_kg`c'=1 if unitsize=="Liter"
		qui replace weight_kg`c'=.01 if unitsize=="Gram"
		qui replace weight_kg`c'=.01 if unitsize=="Milliliter"
 	}
}

qui bys unitsize: gen x=_n
qui tostring x, replace 
qui replace unitsize=unitsize+" "+"(#" + x +"#)" if fitem_unit_size_code> 1000 & !mi(fitem_unit_size_code)
mdesc fitem_unit_size_code unitsize
isid fitem_unit_size_code
isid unitsize

keeporder veges__id units_veges__id veges_size__id unitsize fitem_unit_size_code weight_kg* calories oldcode
qui clonevar value=fitem_unit_size_code
qui clonevar title=unitsize
qui clonevar parentvalue=veges__id
replace parentvalue=fitem_unit_size_code if inrange(fitem_unit_size_code,1,4)
qui gen attachmentname=.
sort veges__id value
isid fitem_unit_size_code
isid unitsize

//Export units for each veges type
qui export excel value title parentvalue attachmentname using "${gsdTemp}/unit_size_veges2.xlsx", firstrow(variables) nolabel replace
qui save "${gsdTemp}/unit_size_veges.dta",replace

clonevar rowcode=fitem_unit_size_code

qui export delimited rowcode weight_kg1-weight_kg10 using "${gsdTemp}/unit_size_veges2_counties1to10.txt", replace  delimiter(tab)
qui export delimited rowcode weight_kg11-weight_kg20 using "${gsdTemp}/unit_size_veges2_counties11to20.txt", replace  delimiter(tab)
qui export delimited rowcode weight_kg21-weight_kg30 using "${gsdTemp}/unit_size_veges2_counties21to30.txt", replace  delimiter(tab)
qui export delimited rowcode weight_kg31-weight_kg40 using "${gsdTemp}/unit_size_veges2_counties31to40.txt", replace  delimiter(tab)
qui export delimited rowcode weight_kg41-weight_kg47 using "${gsdTemp}/unit_size_veges2_counties41to47.txt", replace  delimiter(tab)

duplicates drop veges__id,force

drop rowcode 
gen rowcode=veges__id
gen newcode=rowcode
drop if mi(rowcode)
qui export delimited rowcode newcode oldcode calories using "${gsdTemp}/oldcodes_calories_veges2.txt", replace  delimiter(tab)

**# Fruits
use "${gsdDataRaw}/suso/nsu/KIHBS_NSU.dta",clear
keep interview__key YA03_fruits_nuts__*
greshape long YA03_fruits_nuts__, i( interview__key ) j(fruits__id) 
destring fruits__id, force replace
duplicates drop fruits__id, force
tempfile all_fruits
qui save `all_fruits', replace

qui import excel "${gsdDataRaw}/items_calories_oldcodes.xlsx", sheet("fruits") firstrow clear
destring Fat_g, replace force
tempfile calories_oldcodes_fruits
qui save `calories_oldcodes_fruits', replace

use "${gsdTemp}/fruits_conversion_wide.dta", clear
merge m:1 fruits__id using `all_fruits', nogen keepusing(YA03_fruits_nuts__) keep(2 3) assert(2 3)
drop YA03_fruits_nuts__
merge m:1 fruits__id using `calories_oldcodes_fruits', nogen keepusing(Edible_conversion_factor- oldcode) keep(1 3) //merge them in
rename Energy_kcal calories 

qui decode units_fruits__id,gen( units_fruits__ids)
qui decode fruits_size__id,gen( fruits_size__ids)
qui gen unitsize=units_fruits__ids+" "+fruits_size__ids
qui insobs 4
qui egen a=seq() if mi(units_fruits__id), from(1) to(4)
qui replace unitsize="Kilo" if a==1
qui replace unitsize="Liter" if a==2
qui replace unitsize="Gram" if a==3
qui replace unitsize="Milliliter" if a==4
forval c=1/47 {
	 confirm e weight_kg`c'
	if _rc!=0 {
		gen weight_kg`c'=.
	}
 	 confirm e weight_kg`c'
 	if _rc==0 {
		qui replace weight_kg`c'=1 if unitsize=="Kilo"
		qui replace weight_kg`c'=1 if unitsize=="Liter"
		qui replace weight_kg`c'=.01 if unitsize=="Gram"
		qui replace weight_kg`c'=.01 if unitsize=="Milliliter"
 	}
}

qui bys fruits__id: gen fitem_unit_size_code=_n
qui replace fitem_unit_size_code=fitem_unit_size_code+4 if !inlist(unitsize,"Kilo","Liter","Gram","Milliliter")
qui replace fitem_unit_size_code=1 if unitsize=="Kilo"
qui replace fitem_unit_size_code=2 if unitsize=="Liter"
qui replace fitem_unit_size_code=3 if unitsize=="Gram"
qui replace fitem_unit_size_code=4 if unitsize=="Milliliter"
qui gen code_fitem_unit_size_code=(fruits__id*1000)+fitem_unit_size_code
qui format %19.0g code_fitem_unit_size_code 

qui bys unitsize: gen x=_n
qui tostring x, replace 
qui replace unitsize=unitsize+" "+"(#" + x +"#)" if code_fitem_unit_size_code> 1000 & !mi(code_fitem_unit_size_code)

qui replace code_fitem_unit_size_code=fitem_unit_size_code if mi(code_fitem_unit_size_code) & !mi(fitem_unit_size_code)

keeporder fruits__id units_fruits__id fruits_size__id unitsize code_fitem_unit_size_code weight_kg* calories oldcode
qui clonevar value=code_fitem_unit_size_code
qui clonevar title=unitsize
qui clonevar parentvalue=fruits__id
replace parentvalue=code_fitem_unit_size_code if inrange(code_fitem_unit_size_code,1,4)
qui gen attachmentname=.
sort fruits__id value

//Export units for each fruit type
qui export excel value title parentvalue attachmentname using "${gsdTemp}/unit_size_fruits.xlsx", firstrow(variables) nolabel replace
qui save "${gsdTemp}/unit_size_fruits.dta",replace

clonevar rowcode=code_fitem_unit_size_code

qui export delimited rowcode weight_kg1-weight_kg10 using "${gsdTemp}/unit_size_fruits_counties1to10.txt", replace  delimiter(tab)
qui export delimited rowcode weight_kg11-weight_kg20 using "${gsdTemp}/unit_size_fruits_counties11to20.txt", replace  delimiter(tab)
qui export delimited rowcode weight_kg21-weight_kg30 using "${gsdTemp}/unit_size_fruits_counties21to30.txt", replace  delimiter(tab)
qui export delimited rowcode weight_kg31-weight_kg40 using "${gsdTemp}/unit_size_fruits_counties31to40.txt", replace  delimiter(tab)
qui export delimited rowcode weight_kg41-weight_kg47 using "${gsdTemp}/unit_size_fruits_counties41to47.txt", replace  delimiter(tab)

duplicates drop fruits__id,force

drop rowcode 
gen rowcode=fruits__id
gen newcode=rowcode
drop if mi(rowcode)
qui export delimited rowcode newcode oldcode calories using "${gsdTemp}/oldcodes_calories_fruits.txt", replace  delimiter(tab)

**# Sugars
use "${gsdDataRaw}/suso/nsu/KIHBS_NSU.dta",clear
keep interview__key YA03_sugars_bev__*
greshape long YA03_sugars_bev__, i( interview__key ) j(sugars__id) 
destring sugars__id, force replace
duplicates drop sugars__id, force
tempfile all_sugars
qui save `all_sugars', replace

qui import excel "${gsdDataRaw}/items_calories_oldcodes.xlsx", sheet("sugars") firstrow clear
destring Fat_g, replace force
tempfile calories_oldcodes_sugars
qui save `calories_oldcodes_sugars', replace

use "${gsdTemp}/sugars_conversion_wide.dta", clear
merge m:1 sugars__id using `all_sugars', nogen keepusing(YA03_sugars_bev__) keep(2 3) assert(2 3)
drop YA03_sugars_bev__
merge m:1 sugars__id using `calories_oldcodes_sugars', nogen keepusing(Edible_conversion_factor- oldcode) keep(1 3) //merge them in
rename Energy_kcal calories 

qui decode units_sugars__id,gen( units_sugars__ids)
qui decode sugars_size__id,gen( sugars_size__ids)
qui gen unitsize=units_sugars__ids+" "+sugars_size__ids
qui insobs 4
qui egen a=seq() if mi(units_sugars__id), from(1) to(4)
qui replace unitsize="Kilo" if a==1
qui replace unitsize="Liter" if a==2
qui replace unitsize="Gram" if a==3
qui replace unitsize="Milliliter" if a==4
forval c=1/47 {
	 confirm e weight_kg`c'
	if _rc!=0 {
		gen weight_kg`c'=.
	}
 	 confirm e weight_kg`c'
 	if _rc==0 {
		qui replace weight_kg`c'=1 if unitsize=="Kilo"
		qui replace weight_kg`c'=1 if unitsize=="Liter"
		qui replace weight_kg`c'=.01 if unitsize=="Gram"
		qui replace weight_kg`c'=.01 if unitsize=="Milliliter"
 	}
}

qui bys sugars__id: gen fitem_unit_size_code=_n
qui replace fitem_unit_size_code=fitem_unit_size_code+4 if !inlist(unitsize,"Kilo","Liter","Gram","Milliliter")
qui replace fitem_unit_size_code=1 if unitsize=="Kilo"
qui replace fitem_unit_size_code=2 if unitsize=="Liter"
qui replace fitem_unit_size_code=3 if unitsize=="Gram"
qui replace fitem_unit_size_code=4 if unitsize=="Milliliter"
qui gen code_fitem_unit_size_code=(sugars__id*1000)+fitem_unit_size_code
qui format %19.0g code_fitem_unit_size_code 

qui bys unitsize: gen x=_n
qui tostring x, replace 
qui replace unitsize=unitsize+" "+"(#" + x +"#)" if code_fitem_unit_size_code> 1000 & !mi(code_fitem_unit_size_code)

qui replace code_fitem_unit_size_code=fitem_unit_size_code if mi(code_fitem_unit_size_code) & !mi(fitem_unit_size_code)

keeporder sugars__id units_sugars__id sugars_size__id unitsize code_fitem_unit_size_code weight_kg* calories oldcode
qui clonevar value=code_fitem_unit_size_code
qui clonevar title=unitsize
qui clonevar parentvalue=sugars__id
replace parentvalue=code_fitem_unit_size_code if inrange(code_fitem_unit_size_code,1,4)
qui gen attachmentname=.
sort sugars__id value

//Export units for each cereal type
qui export excel value title parentvalue attachmentname using "${gsdTemp}/unit_size_sugars.xlsx", firstrow(variables) nolabel replace
qui save "${gsdTemp}/unit_size_sugars.dta",replace

clonevar rowcode=code_fitem_unit_size_code

*Export lookup table for conversion factors
qui export delimited rowcode weight_kg1-weight_kg10 using "${gsdTemp}/unit_size_sugars_counties1to10.txt", replace  delimiter(tab)
qui export delimited rowcode weight_kg11-weight_kg20 using "${gsdTemp}/unit_size_sugars_counties11to20.txt", replace  delimiter(tab)
qui export delimited rowcode weight_kg21-weight_kg30 using "${gsdTemp}/unit_size_sugars_counties21to30.txt", replace  delimiter(tab)
qui export delimited rowcode weight_kg31-weight_kg40 using "${gsdTemp}/unit_size_sugars_counties31to40.txt", replace  delimiter(tab)
qui export delimited rowcode weight_kg41-weight_kg47 using "${gsdTemp}/unit_size_sugars_counties41to47.txt", replace  delimiter(tab)

*Export lookup table for calories and oldcodes
duplicates drop sugars__id,force
drop rowcode 
gen rowcode=sugars__id
gen newcode=rowcode
drop if mi(rowcode)
qui export delimited rowcode newcode oldcode calories using "${gsdTemp}/oldcodes_calories_sugars.txt", replace  delimiter(tab)
