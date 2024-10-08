//Main survey Pilot upload file preperations

qui import excel "C:\KNBS\KHIBS MATERIALS\KIBHS_Pilot_Sample_3.7.24.xlsx", sheet("KIBHS_Pilot_Households") firstrow clear

clonevar A01=county_code //county
clonevar A02=Subcounty_name //subcounty
clonevar A03=Division_name //division
clonevar A04=Location_name //location
clonevar A05=Sublocation_name //sublocation
clonevar A06=Enumeration_Area_name //EA
clonevar GEOCODE=Geocode //geocode
clonevar A09=CLUSTER_NUMBER //Cluster number
clonevar A10=STRUCTURE_NUMBER //Structure number
clonevar A11=SERIAL_NUM_HU //Housing unit number
clonevar A13=HOMESTEAD_STRUCTURE_NAME //Household number
clonevar A14__Latitude=latitude
clonevar A14__Longitude=longitude
clonevar A15=Residence //Area of residence
gen prefill_group=runiformint(0, 1)
gen prefill= runiformint(0, 1)
ralpha _responsible, range(J/z) l(10)
ds ,has(type string)
local strings `r(varlist)'
foreach s of local strings {
	replace `s'=upper(trim(`s'))
}
keep A01 A02 A03 A04 A05 A06 GEOCODE A09 A10 A11 A13	A14__Latitude A14__Longitude A15 prefill prefill_group _responsible
qui export delimited A01 A02 A03 A04 A05 A06 GEOCODE A09 A10 A11 A13	A14__Latitude A14__Longitude A15 prefill prefill_group _responsible using "C:\KNBS\KHIBS MATERIALS\ASSIGNMENTS\Field Practice\Folder_stata_assignment/KIHBS_2024_2025_Field_practice.tab", delimiter(tab) replace nolabel

//Market survey Pilot upload file preperations
qui import excel "C:\KNBS\KHIBS MATERIALS\KIBHS_Pilot_Sample_3.7.24.xlsx", sheet("KIHBS_Pilot_Clusters") firstrow clear

clonevar A01=county_code //county
clonevar A02=Subcounty_name //subcounty
clonevar A03=Division_name //division
clonevar A04=Location_name //location
clonevar A05=Sublocation_name //sublocation
clonevar A06=EANAME_1 //EA
clonevar A09=ClusterNumber //Cluster number
//clonevar A13__Latitude=latitude
//clonevar A13__Longitude=longitude
clonevar GEOCODE=Geocode //geocode
clonevar A14=Residence //Area of residence
ralpha _responsible, range(J/z) l(10)
ds ,has(type string)
local strings `r(varlist)'
foreach s of local strings {
	replace `s'=upper(trim(`s'))
}
keep A01 A02 A03 A04 A05 A06 GEOCODE A09 A14 _responsible
qui export delimited A01 A02 A03 A04 A05 A06 GEOCODE A09 A14 _responsible using "C:\KNBS\KHIBS MATERIALS\ASSIGNMENTS\Field Practice\Folder_stata_assignment/KIHBS_Market_Field_Practice.tab", delimiter(tab) replace nolabel


//Community survey MAIN upload file preperations
qui import excel "C:\KNBS\KHIBS MATERIALS\KIBHS_Pilot_Sample_3.7.24.xlsx", sheet("KIHBS_Pilot_Clusters") firstrow clear

clonevar C001=county_code //county
clonevar C002=Subcounty_name //subcounty
clonevar C003=Division_name //division
clonevar C004=Location_name //location
clonevar C005=Sublocation_name //sublocation
clonevar C006=EANAME_1 //EA
//clonevar A13__Latitude=latitude
//clonevar A13__Longitude=longitude
clonevar GEOCODE=Geocode //geocode
clonevar C009=ClusterNumber //Cluster number
clonevar C010=Residence //Area of residence
ralpha _responsible, range(J/z) l(10)
ds ,has(type string)
local strings `r(varlist)'
foreach s of local strings {
	replace `s'=upper(trim(`s'))
}
keep C001 C002 C003 C004 C005 C006 GEOCODE C009 C010 _responsible
qui export delimited C001 C002 C003 C004 C005 C006 GEOCODE C009 C010 _responsible using "C:\KNBS\KHIBS MATERIALS\ASSIGNMENTS\Field Practice\Folder_stata_assignment/kihbs_community_qnn_Pilot.tab", delimiter(tab) replace nolabel


