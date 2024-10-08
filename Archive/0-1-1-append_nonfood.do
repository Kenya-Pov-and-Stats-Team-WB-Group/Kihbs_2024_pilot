clear all
set more off
set maxvar 10000
set seed 23081980 
set sortseed 11041955

*-------------------------------------------------------------------------------------------------------------------------------------------------
*************Section G ***************
*-------------------------------------------------------------------------------------------------------------------------------------------------
use "${gsdDataRaw}/SectionG.dta", clear
gen nf02=SectionG__id
decode SectionG__id,gen(labvalue)
ren (g04_quantity g04_unit g04_value g05) (g04_q g04_u g04_v nf05)
sort interview__id nf02
preserve
collapse (sum) g04_v, by(interview__id nf02)
gen nf03=1
ren g04_v nf04
gen sect=2
gen recall=1
drop if nf04==0 | nf04==.
isid interview__id nf02
qui save "${gsdData}/1-CleanTemp/g1.dta", replace
restore
*.................................................
collapse (sum) nf05, by(interview__id nf02)
gen nf03=2
gen sect=2
gen recall=1
drop if nf05==0 | nf05==.
qui save "${gsdData}/1-CleanTemp/g2.dta", replace
*.................................................
use "${gsdData}/1-CleanTemp/g1.dta", clear
append using "${gsdData}/1-CleanTemp/g2.dta"
forval i=4/5 {
bys interview__id nf02: egen max_nf0`i'=max(nf0`i')
replace nf0`i'=max_nf0`i' if mi(nf0`i') & !mi(max_nf0`i')
drop max_nf0`i'
}
duplicates drop interview__id nf02,force
isid interview__id nf02 
qui save "${gsdData}/1-CleanTemp/g.dta", replace
*.................................................
erase "${gsdData}/1-CleanTemp/g1.dta"
erase "${gsdData}/1-CleanTemp/g2.dta"
*-------------------------------------------------------------------------------------------------------------------------------------------------
*************Section H***************
*-------------------------------------------------------------------------------------------------------------------------------------------------
use "${gsdDataRaw}/SectionHA.dta", clear
gen nf02=SectionHA__id
decode SectionHA__id,gen(labvalue)
ren (SectionHA__id   h04_a h05_a) (h01 h04 h05)
isid interview__id h01
keeporder interview__id interview__key nf02 h01 h04 h05 qrt labvalue
qui save "${gsdData}/1-CleanTemp/ha_data.dta", replace
merge m:1 interview__key using "${gsdTemp}/hh_valid.dta",  keepusing(a12 a13 )

use "${gsdDataRaw}/SectionHB.dta", clear
gen nf02=SectionHB__id
decode SectionHB__id,gen(labvalue)
ren (SectionHB__id h04_b h05_b) (h01 h04 h05)
isid interview__id h01
keeporder interview__key interview__id nf02 h01 h04 h05 qrt labvalue
qui save "${gsdData}/1-CleanTemp/hb_data.dta", replace

use "${gsdData}/1-CleanTemp/ha_data.dta", clear
append using "${gsdData}/1-CleanTemp/hb_data.dta"
isid interview__id h01
qui save "${gsdData}/1-CleanTemp/h.dta", replace
erase "${gsdData}/1-CleanTemp/ha_data.dta"
erase "${gsdData}/1-CleanTemp/hb_data.dta"

*-------------------------------------------------------------------------------------------------------------------------------------------------
*.................................................
use "${gsdData}/1-CleanTemp/h.dta", clear
preserve
collapse (sum) h04, by(interview__id h01)
ren h01 nf02
gen nf03=1
ren h04 nf04
gen sect=3
gen recall=2
drop if nf04==0 | nf04==.
qui save "${gsdData}/1-CleanTemp/h1.dta", replace
restore
*.................................................
use "${gsdData}/1-CleanTemp/h.dta", clear
collapse (sum) h05, by(interview__id h01)
ren h01 nf02
gen nf03=2
ren h05 nf05
gen sect=3
gen recall=2
drop if nf05==0 | nf05==.
qui save "${gsdData}/1-CleanTemp/h2.dta", replace
*.................................................
use "${gsdData}/1-CleanTemp/h1.dta", clear
append using "${gsdData}/1-CleanTemp/h2.dta"
forval i=4/5 {
bys interview__id nf02: egen max_nf0`i'=max(nf0`i')
replace nf0`i'=max_nf0`i' if mi(nf0`i') & !mi(max_nf0`i')
drop max_nf0`i'
}
duplicates drop interview__id nf02,force
isid interview__id nf02 
qui save "${gsdData}/1-CleanTemp/h.dta", replace
*.................................................
erase "${gsdData}/1-CleanTemp/h1.dta"
erase "${gsdData}/1-CleanTemp/h2.dta"
*-------------------------------------------------------------------------------------------------------------------------------------------------
************************************************************* Section I ***************************************************
*-------------------------------------------------------------------------------------------------------------------------------------------------
local letter a b c 
foreach l of local letter {
	use "${gsdDataRaw}/SectionI_`l'.dta", clear
	gen nf02=SectionI_`l'__id
	decode SectionI_`l'__id,gen(labvalue)
	ren (SectionI_`l'__id i03_`l'1__1 i03_`l'1__2 i04_`l' i05_`l') (i01 i03_1 i03_2 i04 i05)
	isid interview__id i01
	qui save "${gsdData}/1-CleanTemp/i`l'_data.dta", replace
}
use "${gsdData}/1-CleanTemp/ia_data.dta", clear
append using "${gsdData}/1-CleanTemp/ib_data.dta" "${gsdData}/1-CleanTemp/ic_data.dta" 
isid interview__id i01
qui save "${gsdData}/1-CleanTemp/i.dta", replace
erase "${gsdData}/1-CleanTemp/ia_data.dta"
erase "${gsdData}/1-CleanTemp/ib_data.dta"
erase "${gsdData}/1-CleanTemp/ic_data.dta"
*-------------------------------------------------------------------------------------------------------------------------------------------------
*.................................................
use "${gsdData}/1-CleanTemp/i.dta", clear
isid interview__id i01
gen nf03=1
ren i04 nf04
gen sect=4
gen recall=2
drop if nf04==0 | nf04==.
isid interview__id nf02
qui save "${gsdData}/1-CleanTemp/i1.dta", replace
*.................................................
use "${gsdData}/1-CleanTemp/i.dta", clear
isid interview__id i01
gen nf03=2
ren i05 nf05
gen sect=4
gen recall=2
drop if nf05==0 | nf05==.
isid interview__id nf02
qui save "${gsdData}/1-CleanTemp/i2.dta", replace
*.................................................
use "${gsdData}/1-CleanTemp/i1.dta", clear
append using "${gsdData}/1-CleanTemp/i2.dta"
duplicates tag  interview__id nf02,gen(d)
foreach v of varlist i04 nf05 {
bys interview__id nf02 : egen max_`v'=max(`v')
replace `v'=max_`v' if mi(`v') & !mi(max_`v')
drop max_`v'
}
duplicates drop interview__id nf02,force
isid interview__id nf02
qui save "${gsdData}/1-CleanTemp/i.dta", replace
*.................................................
erase "${gsdData}/1-CleanTemp/i1.dta"
erase "${gsdData}/1-CleanTemp/i2.dta"
*-------------------------------------------------------------------------------------------------------------------------------------------------
*************Section J***************
*-------------------------------------------------------------------------------------------------------------------------------------------------
qui copy  "${gsdDataRaw}/SectionJ_A.dta" "${gsdTemp}/SectionJ_a.dta", replace pub
qui copy "${gsdDataRaw}/SectionJ_B.dta" "${gsdTemp}/SectionJ_b.dta", replace pub
local letter a b 
foreach l of local letter {
	use "${gsdTemp}/SectionJ_`l'.dta", clear
	ren ( j04_`l' j05_`l') ( j04 j05)
	qui save "${gsdData}/1-CleanTemp/j`l'_data.dta", replace
}
use "${gsdData}/1-CleanTemp/ja_data.dta", clear
append using "${gsdData}/1-CleanTemp/jb_data.dta" 
decode SectionJ_A__id,gen(labvaluea)
decode SectionJ_B__id,gen(labvalueb)
gen labval=labvaluea if !mi(labvaluea)
replace labval=labvalueb if mi(labval) & !mi(labvalueb)
local vars j01 nf02
foreach v of local vars  {
	qui gen `v'=SectionJ_A__id if !mi(SectionJ_A__id)
	qui replace `v'=SectionJ_B__id if mi(`v') & !mi(SectionJ_B__id)
}
isid interview__id j01
keeporder interview__key interview__id j01 nf02 j04 j05 qrt labval SectionJ_B__id
qui save "${gsdData}/1-CleanTemp/j.dta", replace
erase "${gsdData}/1-CleanTemp/ja_data.dta"
erase "${gsdData}/1-CleanTemp/jb_data.dta"
*-------------------------------------------------------------------------------------------------------------------------------------------------
*.................................................
use "${gsdData}/1-CleanTemp/j.dta", clear
gen nf03=1
ren j04 nf04
gen sect=5
gen recall=3
drop if nf04==0 | nf04==.
qui save "${gsdData}/1-CleanTemp/j1.dta", replace
*.................................................
use "${gsdData}/1-CleanTemp/j.dta", clear
gen nf03=2
ren j05 nf05
gen sect=5
gen recall=3
drop if nf05==0 | nf05==.
qui save "${gsdData}/1-CleanTemp/j2.dta", replace
*.................................................
use "${gsdData}/1-CleanTemp/j1.dta", clear
append using "${gsdData}/1-CleanTemp/j2.dta"
duplicates tag interview__id nf02,gen(d)
sort interview__id nf02
forval i=4/5 {
bys interview__id nf02: egen max_nf0`i'=max(nf0`i')
replace nf0`i'=max_nf0`i' if mi(nf0`i') & !mi(max_nf0`i')
drop max_nf0`i'
}
duplicates drop interview__id nf02,force
isid interview__id nf02 
qui save "${gsdData}/1-CleanTemp/j.dta", replace
*.................................................
erase "${gsdData}/1-CleanTemp/j1.dta"
erase "${gsdData}/1-CleanTemp/j2.dta"
*-------------------------------------------------------------------------------------------------------------------------------------------------
*************Section K L M and N ***************
*-------------------------------------------------------------------------------------------------------------------------------------------------
*Section K
use "${gsdDataRaw}/SectionK.dta", clear
ren SectionK__id k01
qui save "${gsdData}/1-CleanTemp/k_`i'.dta", replace
isid interview__id k01
qui save "${gsdData}/1-CleanTemp/k_data.dta", replace
*Section L
use "${gsdDataRaw}/SectionL.dta", clear
ren (SectionL__id  l04 l06 l07 l08)(k01   k04 k06 k07 k08)
isid interview__id k01
qui save "${gsdData}/1-CleanTemp/l_data.dta", replace
*Section M
use "${gsdDataRaw}/SectionM.dta", clear
ren (SectionM__id m04 m06 m07 m08) (k01 k04 k06 k07 k08)
isid interview__id k01
qui save "${gsdData}/1-CleanTemp/m_data.dta", replace
*Section N
use "${gsdDataRaw}/SectionN.dta", clear
ren (SectionN__id n04 n06 n07 n08)(k01 k04 k06 k07 k08)
isid interview__id k01
qui save "${gsdData}/1-CleanTemp/n_data.dta", replace
*Put sections K to N together
use "${gsdData}/1-CleanTemp/k_data.dta", clear
append using "${gsdData}/1-CleanTemp/l_data.dta" "${gsdData}/1-CleanTemp/m_data.dta" "${gsdData}/1-CleanTemp/n_data.dta"
isid interview__id k01
qui save "${gsdData}/1-CleanTemp/klmn.dta", replace
erase "${gsdData}/1-CleanTemp/k_data.dta"
erase "${gsdData}/1-CleanTemp/l_data.dta"
erase "${gsdData}/1-CleanTemp/m_data.dta"
erase "${gsdData}/1-CleanTemp/n_data.dta"
*-------------------------------------------------------------------------------------------------------------------------------------------------
*.................................................
use "${gsdData}/1-CleanTemp/klmn.dta", clear
ren k01 nf02
gen nf03=1
ren (k04 k06 k07 k08) (nf04 nf06 nf07 nf08)
gen sect=6
gen recall=4
drop if nf04==0 | nf04==.
qui save "${gsdData}/1-CleanTemp/k1.dta", replace
*.................................................
use "${gsdData}/1-CleanTemp/klmn.dta", clear
*gen xx=1
*replace xx=0 if k03__1==1
*replace xx=0 if k03__1==1 & k03__2==1
*keep if xx==1
*collapse (sum) k04 k06 k07 k08, by(interview__id k01)
ren k01 nf02
gen nf03=3
ren (k04 k06 k07 k08) (nf04 nf06 nf07 nf08)
gen sect=6
gen recall=4
qui save "${gsdData}/1-CleanTemp/k2.dta", replace
*.................................................
use "${gsdData}/1-CleanTemp/k1.dta", clear
append using "${gsdData}/1-CleanTemp/k2.dta"
duplicates drop interview__id nf02 nf04 nf08, force
isid interview__id nf02
qui save "${gsdData}/1-CleanTemp/klmn.dta", replace
*.................................................
erase "${gsdData}/1-CleanTemp/k1.dta"
erase "${gsdData}/1-CleanTemp/k2.dta"
*-------------------------------------------------------------------------------------------------------------------------------------------------
*SECTION O
*-------------------------------------------------------------------------------------------------------------------------------------------------
use "${gsdDataRaw}/SectionO.dta", clear
destring SectionO__id,gen(labval)
gen nf02=SectionO__id
ren (o04 o05) (nf04 nf05)
isid interview__id nf02 
keeporder interview__key interview__id nf02 nf04 nf05 qrt
qui save "${gsdData}/1-CleanTemp/o_data.dta", replace
*-------------------------------------------------------------------------------------------------------------------------------------------------
*.................................................
use "${gsdData}/1-CleanTemp/o_data.dta", clear
isid interview__id nf02
gen nf03=1
gen sect=7
gen recall=4
drop if nf04==0 | nf04==.
drop nf05
qui save "${gsdData}/1-CleanTemp/o1.dta", replace
	
use "${gsdData}/1-CleanTemp/o_data.dta", clear
isid interview__id nf02
gen nf03=2
gen sect=7
gen recall=4
drop if nf05==0 | nf05==.
drop nf04
qui save "${gsdData}/1-CleanTemp/o2.dta", replace
*.................................................
use "${gsdData}/1-CleanTemp/o1.dta", clear
append using "${gsdData}/1-CleanTemp/o2.dta"
forval i=4/5 {
bys interview__id nf02: egen max_nf0`i'=max(nf0`i')
replace nf0`i'=max_nf0`i' if mi(nf0`i') & !mi(max_nf0`i')
drop max_nf0`i'
}
duplicates drop interview__id nf02,force
isid interview__id nf02 
qui save "${gsdData}/1-CleanTemp/o.dta", replace
*.................................................
erase "${gsdData}/1-CleanTemp/o1.dta"
erase "${gsdData}/1-CleanTemp/o2.dta"
*-------------------------------------------------------------------------------------------------------------------------------------------------
*SECTION P
*-------------------------------------------------------------------------------------------------------------------------------------------------
use "${gsdDataRaw}/Section_p.dta", clear
ren (Section_p__id) (p01)
isid interview__id p01
qui save "${gsdData}/1-CleanTemp/p_data.dta", replace
*-------------------------------------------------------------------------------------------------------------------------------------------------
*.................................................
use "${gsdData}/1-CleanTemp/p_data.dta", clear
isid interview__id p01
ren p01 nf02
gen nf03=1
ren p04 nf04
gen sect=8
gen recall=4
qui savesome interview__id nf02 nf03 nf04 sect recall if !(nf04==0 | nf04==.) using "${gsdData}/1-CleanTemp/p1.dta", replace
*.................................................
use "${gsdData}/1-CleanTemp/p_data.dta", clear
isid interview__id p01
ren p01 nf02
gen nf03=2
ren p06 nf05
gen sect=8
gen recall=4
qui savesome interview__id nf02 nf03 nf05 sect recall if !(nf05==0 | nf05==.) using "${gsdData}/1-CleanTemp/p2.dta", replace
*.................................................
use "${gsdData}/1-CleanTemp/p_data.dta", clear
isid interview__id p01
ren p01 nf02
gen nf03=3
ren (p04 p08 p09 p10) (nf04 nf06 nf07 nf08)
gen sect=8
gen recall=4
qui savesome interview__id nf02 nf03 sect recall nf06 nf07 nf08 if nf03==3 using "${gsdData}/1-CleanTemp/p3.dta", replace
*.................................................
use "${gsdData}/1-CleanTemp/p1.dta", clear
append using "${gsdData}/1-CleanTemp/p2.dta" "${gsdData}/1-CleanTemp/p3.dta"
duplicates tag interview__id nf02,gen(d)
forval i=4/8 {
bys interview__id nf02: egen max_nf0`i'=max(nf0`i')
replace nf0`i'=max_nf0`i' if mi(nf0`i') & !mi(max_nf0`i')
drop max_nf0`i'
}
duplicates drop interview__id nf02 ,force 
isid interview__id nf02 
qui save "${gsdData}/1-CleanTemp/p.dta", replace
*.................................................
erase "${gsdData}/1-CleanTemp/p1.dta"
erase "${gsdData}/1-CleanTemp/p2.dta"
erase "${gsdData}/1-CleanTemp/p3.dta"
*-------------------------------------------------------------------------------------------------------------------------------------------------
use "${gsdData}/1-CleanTemp/g.dta", clear
local v "h i j klmn o p"
foreach x of local v {
append using "${gsdData}/1-CleanTemp/`x'.dta"
}
qui save "${gsdData}/1-CleanTemp/nonfood.dta", replace

use "${gsdData}/1-CleanTemp/nonfood.dta", clear
replace nf02=6506 if nf02==9801 & sect==4 & recall==2
replace nf02=6507 if nf02==9802 & sect==4 & recall==2
replace nf02=6508 if nf02==9803 & sect==4 & recall==2
replace nf02=6510 if nf02==9805 & sect==4 & recall==2
replace nf02=9504 if nf02==9804 & sect==6 & recall==4
replace nf02=9807 if nf02==9806 & sect==6 & recall==4
replace nf02=9504 if nf02==9901 & sect==6 & recall==4
replace nf02=9505 if nf02==9902 & sect==6 & recall==4
replace nf02=9506 if nf02==9903 & sect==6 & recall==4
duplicates tag interview__id nf02,gen(dd)
drop if dd==1 
isid interview__id nf02
order  sect recall nf02 nf03 nf04 nf05 nf06 nf07 nf08, after (interview__id)
lab var interview__id "Interview ID"
lab var nf02 "Item Code"
lab var nf03 "Type of Transaction"
lab var nf04 "Amount Paid for the purchased"
lab var nf05 "Value acquired or Consumed from Other sources"
lab var nf06 "How many items do you own"
lab var nf07 "Item's age"
lab var nf08 "Item resale value"

gen sectx =0
local v "1906 4702 4704 4705 9806 4707 4901"
foreach x of local v {
	qui replace sectx=2 if nf02==`x'
}
lab def sect 1 "Section F" 2 "Section G"
lab val sectx sect

local v "2001 2003 2201 2202 2203 2204 2205 2206 2207 2301 2302 2303 2304 2305 2306 2401 2501 2502 2601 2701 2702 2703 2801 2802 2803 2804 2805 2806 2807 2901 2902 2903 3001 3002 3003 3004 3006 3007 3101 3102 3103 3201 3202 3203 3204 3205 3206 3207 3208 3209 3210 3211 3212 3213 3214 3215 3216 3217 3218 3219 3220 3221 3222 3223 3224 3301 3302 3303 3304 3401 3402 3403 3404 3405 3406 3407 3408 3409 3501 3502 3503 3504 3505 3506 3507 3508 3509 3510 3511 3512"
foreach x of local v {
	qui replace sectx=3 if nf02==`x'
}
lab def sect 3 "Section H", add

local v "3601 3602 3603 3604 3605 3606 3607 3608 3609 3610 3611 3612 3613 3614 3615 3616 3617 3618 3619 3620 3621 3622 3623 3624 3625 3626 3627 3628 3701 3702 3703 3704 3705 3706 3707 3708 3801 3802 3803 3804 3805 3901 3902 3903 3904 3905 3906 3907 4001 4002 4101 4102 4103 4104 4105 4106 4107 4201 4202 4203 4301 4302 4303 4304 4305 4306 4401 4402 4403 4404 4405 4501 4502 4503 4504 4505 4506 4601 4701 4703 4706 4801 4802 4902 4903 5001 5002 5003 5004 5101 5102 5103 5201 5202 5301 5401 5501 5502 5503 5504 5601 5602 5701 5702 5703 5801 5901 5902 5903 5904 6001 6002 6003 6004 6101 6201 6202 6203 6204 6205 6301 6302 6303 6401 6402 6403 6404 6405 6406 6407 6501 6502 6504 6505 6506 6507 6508 6509 6510 9801 9802 9803 9804 9805"
foreach x of local v {
	qui replace sectx=4 if nf02==`x'
}
lab def sect 4 "Section I", add

local v "6601 6602 6603 6701 6702 6703 6704 6801 6802 6803 6804 6901 6902 6903 6904 6905 6906 6907 6908 6909 6910 6911 6912 6913 6914 6915 6916 6917 6918 6919 7001 7002 7003 7004 7005 7006 7007 7008 7009 7010 7011 7012 7013 7014 7015 7016 7017 7018 7019 7020 7021 7022 7023 7024 7025 7101 7102 7103 7104 7105 7106 7107 7108 7109 7110 7111 7112 7113 7114 7115 7116 7117 7118 7119 7120 7121 7122 7123 7201 7202 7203 7204 7205 7206 7207 7301 7302 7303 7304 7305 7306 7307 7308 7401 7402 7403 7404 7405 7406 7407 7408 7501 7502 7503 7504 7505 7506 7507 7508 7601 7602 7603 7604 7605 7606 7607 7608 7701"
foreach x of local v {
	qui replace sectx=5 if nf02==`x'
}
lab def sect 5 "Section J", add

local v "8301 8302 8303 8304 8305 8306 8307 8308 8309 8310 8311 8312 8313 8314 8315 8316 8317 8318 8319 8320"
foreach x of local v {
	qui replace sectx=6 if nf02==`x'
}
lab def sect 6 "Section K", add

local v "8401 8402 8403 8404 8405 8406 8407 8408 8409 8410 8501 8502 8503 8504 8505 8506 8507 8508 8509 8510 8511 8601 8602 8603 8604 8605 8606 8607 8608 8609 8610 8701"
foreach x of local v {
	qui replace sectx=7 if nf02==`x'
}
lab def sect 7 "Section L", add

local v "8801 8802 8803 8804 8805 8806 8807 8808 8809 8810 8811 8812 8901 8902 8903 8904 8905 8906 8907 8908 8909 9001 9002 9003 9004 9005 9006 9007 9008 9009 9010 9011 9012 9013 9014"
foreach x of local v {
	qui replace sectx=8 if nf02==`x'
}
lab def sect 8 "Section M", add

local v "9101 9102 9103 9201 9202 9203 9204 9205 9206 9301 9302 9303 9304 9401 9402 9403 9404 9405 9406 9407 9501 9502 9503 9504 9505 9506 9804 9805 9807 9900 9901 9902 9903"
foreach x of local v {
	qui replace sectx=9 if nf02==`x'
}

lab def sect 9 "Section N", add

local v "9701 9702 9703 9704 9705 9706 9707 9708 9709 9710 9711 9901 9902 9903 9904 9905 9906 9907 9908 9909 9910 9911 9912"
foreach x of local v {
	qui replace sectx=10 if nf02==`x'
}
lab def sect 10 "Section O", add

local v "10001 10002 11101 12001 13001 14001 14002 14003 14004 14005 14006"
foreach x of local v {
	qui replace sectx=11 if nf02==`x'
}
lab def sect 11 "Section P", add

lab def nf03 1 "Purchased" 2 "Other Sources" 3 "Own"
lab val nf03 nf03

qui gen recll=1 if sectx==2
qui replace recll=2 if sectx==3 | sectx==4
qui replace recll=3 if sectx==5
qui replace recll=4 if sectx>5

lab def recall 1 "7 days" 2 "1 month" 3 "3 months" 4 "12 months"
lab val recll recall
order  sectx recll nf02 nf03 nf04 nf05 nf06 nf07 nf08, after (interview__id)
drop sect recall
ren (recll sectx) (recall sect)
lab var sect "Questionaire Serction"
lab var recall "Recall Period"
ren interview__id interview_id
qui compress

isid interview_id nf02

qui save "${gsdData}/1-CleanTemp/nonfood_1.dta", replace

*Importing Comparables so as to retain 275 items************
import excel using "${gsdDataRaw}/comparable items.xlsx", firstrow clear
merge 1:m nf02 using "${gsdData}/1-CleanTemp/nonfood_1.dta"
keep if _merge==3 | nf02==2001
replace Itemname="Actual housing rent" if nf02==2001
drop _merge
qui save "${gsdData}/1-CleanTemp/nonfood_2.dta", replace 
