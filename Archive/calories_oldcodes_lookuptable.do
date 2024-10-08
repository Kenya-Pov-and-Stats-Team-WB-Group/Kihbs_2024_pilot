use "C:\Users\wb562201\Downloads\food_items_microdata.dta", clear 
duplicates drop fooditem_code,force
gen oldcodes=fooditem_code
sort fooditem_code
//br fooditem_code oldcodes calories
decode fooditem_code,gen(REPORTONLYITEMSCONSUMEDWITHI)
replace REPORTONLYITEMSCONSUMEDWITHI=upper(REPORTONLYITEMSCONSUMEDWITHI)
clonevar REPORTONLYITEMSCONSUMEDWITHI1=REPORTONLYITEMSCONSUMEDWITHI
tempfile lookup
qui save `lookup', replace 

qui import excel "C:\Users\wb562201\Downloads\2024_25 KIHBS Q1C_Consumption Expenditure_3rd draft_20.12.23.xlsx", sheet("YA_HH Food (OPTION 2)") cellrange(A5:U989) firstrow clear
keep if ITEMCODE>=1000 & !mi(ITEMCODE)
replace REPORTONLYITEMSCONSUMEDWITHI=upper(REPORTONLYITEMSCONSUMEDWITHI)
dropmiss *, force
//merge 1:1 REPORTONLYITEMSCONSUMEDWITHI using `lookup', keepusing(oldcodes calories)
//sort _merge
format %70s REPORTONLYITEMSCONSUMEDWITHI

preserve 
matchit ITEMCODE REPORTONLYITEMSCONSUMEDWITHI using `lookup' , idusing(fooditem_code) txtusing(REPORTONLYITEMSCONSUMEDWITHI) over
keep if similscore>.9
duplicates drop REPORTONLYITEMSCONSUMEDWITHI1, force
tempfile matched
qui save `matched', replace 
restore 

merge m:m REPORTONLYITEMSCONSUMEDWITHI using `matched', nogen

merge m:m REPORTONLYITEMSCONSUMEDWITHI1 using `lookup'
duplicates drop REPORTONLYITEMSCONSUMEDWITHI, force 
keeporder REPORTONLYITEMSCONSUMEDWITHI ITEMCODE oldcodes calories COICOPCODE
replace COICOPCODE=strtrim(COICOPCODE)
replace REPORTONLYITEMSCONSUMEDWITHI=strtrim(REPORTONLYITEMSCONSUMEDWITHI)
drop if mi(ITEMCODE)
sort ITEMCODE
clonevar rowcode=ITEMCODE
//replace calories=runiform(30,200) if mi(calories)
clonevar newcode=rowcode
export excel REPORTONLYITEMSCONSUMEDWITHI rowcode newcode oldcodes calories COICOPCODE using "C:\Users\wb562201\OneDrive - WBG\Desktop\asdasd.xls", sheetreplace firstrow(variables)
keeporder rowcode newcode oldcodes calories COICOPCODE REPORTONLYITEMSCONSUMEDWITHI

qui export delimited rowcode newcode oldcodes calories using "C:\Users\wb562201\Downloads\oldcodes_calories.txt", delimiter(tab) replace

