*Do-file to run KCHS cleaning and analysis.
clear all
set more off
set maxvar 10000
global suser = c(username)

*Check if filepaths have been established using init.do
if "${gsdData}"=="" {
	display as error "Please run init.do first."
	error 1
}

global datacollection 1 //turn on (i.e. set as 1 if data is being collected and hence needs to be screened on a regular frequent basis)

** 0-STAGE: Prepare Raw data
*retrieve data through API
run "${gsdDo}/0-x-api_getdata.do"
 
*append hh, hhm, food and nonfood datasets for datasets.
run "${gsdDo}/0-x-append.do"

*check data 
run "${gsdDo}/0-x-check.do"

*Process the KCHS datasets
run "${gsdDo}/0-x-process.do"

*Anonymize all datasets by randomizing cluster, structure and household numbers and dropping identifying information. Finally, save all anonymized datasets in the CleanInput folder.
run "${gsdDo}/0-x-anonymize.do"

** 1-STAGE: Clean datases
*Clean the food consumption section and create food component of consumption aggregate
run "${gsdDo}/1-1-clean_fcons.do"

*Clean the non-food section and create non-food component of consumption aggregate
run "${gsdDo}/1-2-clean_nfcons.do"

*Calculate rent component of consumption aggregate
run "${gsdDo}/1-3-rent.do"

*Calculate education component of consumption aggregate
run "${gsdDo}/1-4-clean_educ.do"

*Generate KCHS food consumption basket
run "${gsdDo}/1-5-basket.do"

*Generate KCHS Paasche price deflator
run "${gsdDo}/1-6-deflator.do"

*Calculate poverty line and poverty rate
run "${gsdDo}/1-7-pline.do"

** 2-STAGE: Analysis
run "${gsdDo}/2-1-poverty.do"
