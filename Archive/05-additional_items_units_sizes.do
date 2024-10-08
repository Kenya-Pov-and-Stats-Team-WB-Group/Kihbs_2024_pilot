*cereals renaming for appending and merging
use "${gsdOutput}/nsu/cereals_item_unit_size.dta",clear
rename cereals__id fitem_code
rename units_cereals__id fitem_unit_code
rename cereals_size__id fitem_size_code

merge m:1 fitem_code fitem_unit_code fitem_size_code  using "${gsdOutput}/nsu/food_conversion_wide.dta" , keep(match master)

keeporder interview__key A02 fitem_code  fitem_unit_code ///
other_unit_cereals fitem_size_code other_size_cereals q110?_cereals_1 weight_kg? weight_kg??

sort fitem_code fitem_unit_code fitem_size_code

duplicates drop fitem_code fitem_unit_code fitem_size_code, force
save "${gsdOutput}/nsu/cereals_item_unit_size1.dta", replace



*veges renaming for appending and merging
use "${gsdOutput}/nsu/veges_item_unit_size.dta",clear
rename veges__id fitem_code
rename units_veges__id fitem_unit_code
rename veges_size__id fitem_size_code
merge m:1 fitem_code fitem_unit_code fitem_size_code  using "${gsdOutput}/nsu/food_conversion_wide.dta" , keep(match master)

keeporder interview__key A02 fitem_code fitem_unit_code ///
other_unit_veges fitem_size_code other_size_veges q110?_veges_1 weight_kg? weight_kg?? 

sort fitem_code fitem_unit_code fitem_size_code

duplicates drop fitem_code fitem_unit_code fitem_size_code, force
save "${gsdOutput}/nsu/veges_item_unit_size1.dta", replace


*fruits renaming for appending and merging
use "${gsdOutput}/nsu/fruits_item_unit_size.dta",clear
rename fruits__id fitem_code
rename units_fruits__id fitem_unit_code
rename fruits_size__id fitem_size_code
merge m:1 fitem_code fitem_unit_code fitem_size_code  using "${gsdOutput}/nsu/food_conversion_wide.dta" , keep(match master)

keeporder interview__key A02 fitem_code fitem_unit_code ///
other_unit_fruits fitem_size_code other_size_fruits q110?_fruits_1 weight_kg? weight_kg?? 

sort fitem_code fitem_unit_code fitem_size_code

duplicates drop fitem_code fitem_unit_code fitem_size_code, force
save "${gsdOutput}/nsu/fruits_item_unit_size1.dta", replace


*meat renaming for appending and merging
use "${gsdOutput}/nsu/meat_item_unit_size.dta",clear
rename meat__id fitem_code
rename units_meat__id fitem_unit_code
rename meat_size__id fitem_size_code
merge m:1 fitem_code fitem_unit_code fitem_size_code  using "${gsdOutput}/nsu/food_conversion_wide.dta" , keep(match master)

keeporder interview__key A02 fitem_code fitem_unit_code ///
other_unit_meat fitem_size_code other_size_meat q110?_meat_1 weight_kg? weight_kg?? 

sort fitem_code fitem_unit_code fitem_size_code

duplicates drop fitem_code fitem_unit_code fitem_size_code, force
save "${gsdOutput}/nsu/meat_item_unit_size1.dta", replace


*oil_fats renaming for appending and merging
use "${gsdOutput}/nsu/oil_fats_item_unit_size.dta",clear
rename oil_fats__id fitem_code
rename units_oil_fats__id fitem_unit_code
rename oil_fats_size__id fitem_size_code
merge m:1 fitem_code fitem_unit_code fitem_size_code  using "${gsdOutput}/nsu/food_conversion_wide.dta" , keep(match master)

keeporder interview__key A02 fitem_code fitem_unit_code ///
other_unit_oil_fats fitem_size_code other_size_oil_fats q110?_oil_fats_1 weight_kg? weight_kg?? 

sort fitem_code fitem_unit_code fitem_size_code

duplicates drop fitem_code fitem_unit_code fitem_size_code, force
save "${gsdOutput}/nsu/oil_fats_item_unit_size1.dta", replace


*sugars renaming for appending and merging
use "${gsdOutput}/nsu/sugars_item_unit_size.dta",clear
rename sugars__id fitem_code
rename units_sugars__id fitem_unit_code
rename sugars_size__id fitem_size_code
merge m:1 fitem_code fitem_unit_code fitem_size_code  using "${gsdOutput}/nsu/food_conversion_wide.dta" , keep(match master)

keeporder interview__key A02 fitem_code fitem_unit_code ///
other_unit_sugars fitem_size_code other_size_sugars q110?_sugars_1 weight_kg? weight_kg?? 

sort fitem_code fitem_unit_code fitem_size_code

duplicates drop fitem_code fitem_unit_code fitem_size_code, force
save "${gsdOutput}/nsu/sugars_item_unit_size1.dta", replace

*others renaming for appending and merging
use "${gsdOutput}/nsu/others_item_unit_size.dta",clear
rename others__id fitem_code
rename units_others__id fitem_unit_code
rename others_size__id fitem_size_code
merge m:1 fitem_code fitem_unit_code fitem_size_code  using "${gsdOutput}/nsu/food_conversion_wide.dta" , keep(match master)

keeporder interview__key A02 fitem_code fitem_unit_code ///
other_unit_others fitem_size_code other_size_others q110?_others_1 weight_kg? weight_kg?? 

sort fitem_code fitem_unit_code fitem_size_code

duplicates drop fitem_code fitem_unit_code fitem_size_code, force
save "${gsdOutput}/nsu/others_item_unit_size1.dta", replace
