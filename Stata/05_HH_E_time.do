* Describe what is accomplished with file:
* This .do file calculates the ganyu labor time for households
* Date: 2016/09/16
* Author: Tim Essam, Brent McCusker & Park Muhonda
* Project: WVU Livelihood Analysis for Malawi
********************************************************************

clear
capture log close

* Load the dataset needed to derive time use and ganyu variables
use "$wave1/HH_MOD_E.dta", clear

* Merge in household roster so you can determine who is head and spouse
merge 1:1 case_id id_code using "$wave1/HH_MOD_B.dta", gen(_roster)
merge 1:1 case_id id_code using "$pathout/hh_roster_2011.dta", gen(_rosterKeep)
drop if _rosterKeep == 1 | _roster == 2

* water time -- use hh_b04 (correct variable when making spouse/head vars)
egen totWaterTime = total(hh_e05), by(case_id)
g spouseWaterTime = (hh_e05) if hh_b04 == 2
g headWaterTime = (hh_e05) if hh_b04 == 1

* Firewood time
egen totFirewdTime = total(hh_e06), by(case_id)
g spouseFireTime = (hh_e06) if hh_b04 == 2
g headFireTime	= (hh_e06) if hh_b04 == 1

* Ganyu time and household composition
* --- only counting hh members between 10 and 65 as being eligible for ganyu
g byte ganyuAgeRange = inrange(hh_b05a, 10, 65)
g byte ganyuParticipation = inlist(hh_e55 , 1) == 1 & ganyuAgeRange == 1
egen ganyuDenom = total(ganyuParticipation), by(case_id)
egen totGanyuElig = total(inrange(hh_b05a, 10, 65)), by(case_id)
egen hhsize = count(case_id), by(case_id)
g ganyuParticRate = (ganyuDenom / totGanyuElig)

* --- Female headed households
g byte femhead = (hh_b04 == 1 & hh_b03 == 2)

g byte ganyuFemhead = (femhead == 1 & ganyuParticipation == 1)
la var ganyuFemhead "female head partcipating in ganyu"

g ganyuTotdays = hh_e56 * hh_e57 * hh_e58 if ganyuParticipation == 1
* Check that no individual has more than 365 days of Ganyu Labor participation
assert ganyuTotdays < 365 if !missing(ganyuTotdays)
egen totGanyuDaysHH = total(ganyuTotdays), by(case_id)

* What is total estimated wage of ganyu labor efforts
clonevar ganyuWageRate = hh_e59
sum ganyuWageRate, d
count if ganyuWageRate > 2 * `r(p99)' & !missing(ganyuWageRate)
winsor ganyuWageRate, gen(ganyuWR) highonly h(`r(N)')

g ganyuTotWage = ganyuTotdays * hh_e59 if ganyuParticipation == 1

* Check for outliers (greater than 99th percentile), replace them with
sum ganyuTotWage, d
scalar tmpmed = `r(p99)'
* replace the outliers using the median value of the wage (hh_e59)
egen medWage = median(hh_e59)
replace ganyuTotWage = ganyuTotdays * medWage if ganyuTotWage > tmpmed & !missing(ganyuTotWage)

* Create a logged value to normalize the distribution of ganyu earnings
g ganyuTotWageLog = ln(ganyuTotWage)
egen ganyuTotHHWage = total(ganyuTotWage), by(case_id)
g ganyuTotHHWagePC = ganyuTotHHWage/ganyuDenom
g ganyuTotHHWageLog = log(ganyuTotHHWage)
g ganyuTotHHWageLogPC =  ganyuTotHHWageLog/ganyuDenom

egen maxGanyuTime = max(ganyuTotdays), by(case_id)
g spouseGanyuTime = (ganyuTotdays) if hh_b04 == 2
g sopuseGanyuWage = ganyuTotWage if hh_b04 == 2
g headGanyuTime	= (ganyuTotdays) if hh_b04 == 1
g headGanyuWage =  ganyuTotWage if hh_b04 == 1

la var totWaterTime "Total household time spent on water collection"
la var spouseWaterTime "Total spouse time spent on water collection"
la var headWaterTime "Total time hh head spent on water collection"
la var totFirewdTime "Total household time spent on firewood collection"
la var spouseFireTime "Total spouse time spent on firewood collection"
la var headFireTime "Total hoh time spent on firewood collection"
la var spouseGanyuTime "Total spouse time spent on Ganyu activities in past 12months"
la var headGanyuTime "Total hh of houdehold time spent on Ganyu activities in past 12months"
la var maxGanyuTime "Maximum time a household member spent on Ganyu activities in the past 12months"
la var ganyuParticipation "household member participated in ganyu labor"
la var ganyuDenom "Total number of household members participating in ganyu"
la var ganyuTotdays "Total number of days participating in labor (months * weeks * days/week)"
la var ganyuTotWage "Total estimated wage earned through ganyu (days * average wage)"
la var ganyuTotWageLog "Logged value of ganyuTotWage (to normalize)"
la var spouseGanyuTime "Spouse time spent in ganyu"
la var sopuseGanyuWage "Spouse wage earned in ganyu"
la var headGanyuTime "Head time spent in ganyu"
la var headGanyuWage "Head wage earned in ganyu"
la var ganyuTotHHWage "total household ganyu wage"
la var ganyuTotHHWagePC "total household ganyu wage per ganyu participant"
la var ganyuTotHHWageLog "total household ganyu wage logged"
la var ganyuTotHHWageLogPC "total household ganyu wage logged per ganyu participant"

* Calculate a regional wage rate based on district averages
egen ganyuDistWR = mean(ganyuWR), by(district)

* Create a quick plot of the results
mean ganyuWageRate
	matrix smean = r(table)
	local varmean = smean[1,1]
mean ganyuWageRate, over(district)
	matrix plot = r(table)'
	matsort plot 1 "down"
	matrix plot = plot'
	coefplot (matrix(plot[1,])), ci((plot[5,] plot[6,])) xline(`varmean')


*collapse
qui include "$pathdo/copylabels.do"
	ds(hh_* case_id id_code qx_type visit status ea_id _roster), not
	collapse (max) `r(varlist)', by(case_id)
qui include "$pathdo/attachlabels.do"

g year = 2011
compress
* This will write over your other hh_dem_wave1 data.
*save "$pathout/hh_dem_wave1.dta", replace
save "$pathout/hh_dem_modE_wave1.dta", replace

***** Wave 2 *****
* Process 2nd wave
* Load the dataset needed to derive time use and ganyu variables
use "$wave2/HH_MOD_E.dta", clear
merge 1:1 y2_hhid PID using "$wave2/HH_MOD_B.dta", gen(_roster)
merge 1:1 y2_hhid PID using "$pathout/hh_roster_2013.dta", gen(_rosterKeep)
drop if _rosterKeep == 1 | _roster == 2

* Drop anyone who is not a regular household member
keep if hhmember !=0 & !missing(hhmember)

* water time
egen totWaterTime = total(hh_e05), by(y2_hhid)
g spouseWaterTime = (hh_e05) if hh_b04 == 2
g headWaterTime = (hh_e05) if hh_b04 == 1

* Firewood time
egen totFirewdTime = total(hh_e06), by(y2_hhid)
g spouseFireTime = (hh_e06) if hh_b04 == 2
g headFireTime	= (hh_e06) if hh_b04 == 1

* Ganyu time
g byte ganyuParticipation = inlist(hh_e06_6 , 1)
egen ganyuDenom = total(ganyuParticipation), by(y2_hhid)

g ganyuTotdays = hh_e56 * hh_e57 * hh_e58 if ganyuParticipation == 1
* Check that no individual has more than 365 days of Ganyu Labor participation
assert ganyuTotdays < 365 if !missing(ganyuTotdays)
egen totGanyuDaysHH = total(ganyuTotdays), by(y2_hhid)

* What is total estimated wage of ganyu labor efforts
clonevar ganyuWageRate = hh_e59
sum ganyuWageRate, d
count if ganyuWageRate > 2 * `r(p99)' & !missing(ganyuWageRate)
winsor ganyuWageRate, gen(ganyuWR) highonly h(`r(N)')

* What is total estimated wage of ganyu labor efforts
g ganyuTotWage = ganyuTotdays * hh_e59 if ganyuParticipation == 1

* Check for outliers, replace them with
sum ganyuTotWage, d
g tmpmed = `r(p99)'
* replace the outliers using the median value of the wage (hh_e59)
egen medWage = median(hh_e59)
replace ganyuTotWage = ganyuTotdays * medWage if ganyuTotWage > tmpmed & !missing(ganyuTotWage)

* Create a logged value to normalize the distribution of ganyu earnings
g ganyuTotWageLog = ln(ganyuTotWage)
egen ganyuTotHHWage = total(ganyuTotWage), by(y2_hhid)
g ganyuTotHHWagePC = ganyuTotHHWage/ganyuDenom
g ganyuTotHHWageLog = log(ganyuTotHHWage)
g ganyuTotHHWageLogPC =  ganyuTotHHWageLog/ganyuDenom

egen maxGanyuTime = max(ganyuTotdays), by(y2_hhid)
g spouseGanyuTime = (ganyuTotdays) if hh_b04 == 2
g sopuseGanyuWage = ganyuTotWage if hh_b04 == 2
g headGanyuTime	= (ganyuTotdays) if hh_b04 == 1
g headGanyuWage =  ganyuTotWage if hh_b04 == 1

la var totWaterTime "Total household time spent on water collection"
la var spouseWaterTime "Total spouse time spent on water collection"
la var headWaterTime "Total time hh head spent on water collection"
la var totFirewdTime "Total household time spent on firewood collection"
la var spouseFireTime "Total spouse time spent on firewood collection"
la var headFireTime "Total hoh time spent on firewood collection"
la var spouseGanyuTime "Total spouse time spent on Ganyu activities in past 12months"
la var headGanyuTime "Total hh of houdehold time spent on Ganyu activities in past 12months"
la var maxGanyuTime "Maximum time a household member spent on Ganyu activities in the past 12months"
la var ganyuParticipation "household member participated in ganyu labor"
la var ganyuDenom "Total number of household members participating in ganyu"
la var ganyuTotdays "Total number of days participating in labor (months * weeks * days/week)"
la var ganyuTotWage "Total estimated wage earned through ganyu (days * average wage)"
la var ganyuTotWageLog "Logged value of ganyuTotWage (to normalize)"
la var spouseGanyuTime "Spouse time spent in ganyu"
la var sopuseGanyuWage "Spouse wage earned in ganyu"
la var headGanyuTime "Head time spent in ganyu"
la var headGanyuWage "Head wage earned in ganyu"
la var ganyuTotHHWage "total household ganyu wage"
la var ganyuTotHHWagePC "total household ganyu wage per ganyu participant"
la var ganyuTotHHWageLog "total household ganyu wage logged"
la var ganyuTotHHWageLogPC "total household ganyu wage logged ganyu participant"

* Create a quick plot of the results
mean ganyuWageRate
	matrix smean = r(table)
	local varmean = smean[1,1]
mean ganyuWageRate, over(district)
	matrix plot = r(table)'
	matsort plot 1 "down"
	matrix plot = plot'
	coefplot (matrix(plot[1,])), ci((plot[5,] plot[6,])) xline(`varmean')



*collapse
qui include "$pathdo/copylabels.do"
	ds(occ y2_hhid PID qx_type baselineme~r moverbasehh interview_status hh_* /*
	*/ hhmember baselineme~t _roster tmp*), not
	collapse (max) `r(varlist)', by(y2_hhid)
qui include "$pathdo/attachlabels.do"

g year = 2013
compress
save "$pathout/hh_dem_modE_wave2.dta", replace

* Append two datasets together
append using "$pathout/hh_dem_modE_wave1.dta"
order case_id y2_hhid

g id = case_id if year == 2011
replace id = y2_hhid if id == "" & year == 2013

save "$pathout/labor_all.dta", replace


******* Process 2016 Data *************
* Load the dataset needed to derive time use and ganyu variables
use "$wave3/HH_MOD_E.dta", clear

* Merge in household roster so you can determine who is head and spouse
merge 1:1 case_id PID using "$wave3/HH_MOD_B.dta", gen(_roster)
merge 1:1 case_id PID using "$pathout/hh_base_indiv_2016.dta", gen(_rosterKeep)
drop if _rosterKeep == 1 | _roster == 2

* --- Time fetching totWaterTime
egen totWaterTime = total(hh_e05), by(case_id)
g spouseWaterTime = hh_e05 if hh_b04 == 2
g headWaterTime	= hh_e05 if hh_b04 == 1

* --- Firewood fetching time
egen totFirewdTime = total(hh_e06), by(case_id)
g spouseFireTime = hh_e06 if hh_b04 == 2
g headFireTime = hh_e06 if hh_b04 == 1

* ---- Ganyu participation and details
* --- only counting hh members between 10 and 65 as being eligible for ganyu
g byte ganyuAgeRange = inrange(hh_b05a, 10, 65)
g byte ganyuParticipation = hh_e06_6 == 1  & ganyuAgeRange == 1
egen ganyuDenom = total(ganyuParticipation), by(case_id)
egen totGanyuElig = total(inrange(hh_b05a, 10, 65)), by(case_id)
g ganyuParticRate = (ganyuDenom / totGanyuElig)

* --- Female headed households
g byte femhead = (hh_b04 == 1 & hh_b03 == 2)

g byte ganyuFemhead = (femhead == 1 & ganyuParticipation == 1)
la var ganyuFemhead "female head partcipating in ganyu"
la var ganyuParticipation "participated in ganyu labor over last 12 months"

egen ganyuTot = total(ganyuParticipation), by(case_id)

* Total months participating in ganyu
g ganyuTotdays = hh_e56 * hh_e57 * hh_e58 if ganyuParticipation == 1 & hh_e58!=12
* Check that range is valid for an individual
assert ganyuTotdays <= 365 if !missing(ganyuTotdays)
egen totGanyuDaysHH = total(ganyuTotdays), by(case_id)

* Estimate wage of ganyu labor efforts
clonevar ganyuWageRate = hh_e59
sum ganyuWageRate, d
count if ganyuWageRate > 2 * 	`r(p99)' & !missing(ganyuWageRate)
winsor ganyuWageRate, gen(ganyuWR) highonly h(`r(N)')

* --- Total earnings from ganyu
g ganyuTotWage = ganyuTotdays * ganyuWR if ganyuParticipation == 1
sum ganyuTotWage, d
scalar tempmed = 	`r(p99)'
* replacing outliers with median value of wage across country
egen medWage = median(ganyuWR)
replace ganyuTotWage = ganyuTotdays * medWage if ganyuTotWage > tmpmed & !missing(ganyuTotWage)

* --- Normalize wages by taking logarithm
g ganyuTotWageLog = ln(ganyuTotWage)
egen ganyuTotHHWage = total(ganyuTotWage), by(case_id)
g ganyuTotHHWagePC = ganyuTotHHWage / ganyuTot
g ganyuTotHHWageLog = ln(ganyuTotHHWage)
g ganyuTotHHWageLogPC = ganyuTotHHWageLog/ganyuTot

* --- Generate ganyu time variables
egen maxGanyuTime = max(ganyuTotdays), by(case_id)
g spouseGanyuTime = ganyuTotdays if hh_b04 == 2
g spouseGanyuWage = ganyuTotWage if hh_b04 == 2
g headGanyuTime = ganyuTotdays if hh_b04 == 1
g headGanyuWage = ganyuTotWage if hh_b04 == 1

la var totWaterTime "total hh time spent on water collection"
la var spouseWaterTime "total time spouse spent on water"
la var headWaterTime "total time head spent on water"
la var totFirewdTime "total time to gather firewood"
la var spouseFireTime "total time spouse spent on wood gathering"
la var headFireTime "total time head spent on wood gathering"
la var ganyuTot "total number of hh members participating in ganyu"
la var ganyuTotdays "total days worked in ganyu"
la var ganyuTotWage "total wages from ganyu"
la var medWage "median wage from ganyu"
la var ganyuTotWageLog "ganyu total wages logged"
la var ganyuTotHHWage "total household wages from ganyu"
la var ganyuTotHHWagePC "total wages per person workign in ganyu per hh"
la var ganyuTotHHWageLog "logged total household wages from ganyu"
la var ganyuTotHHWageLogPC "logged per person wages from ganyu"
la var spouseGanyuTime "time spent in ganyu by spouse"
la var headGanyuTime "time spent in ganyu by hoh"
la var spouseGanyuWage "wages for spouse in ganyu"
la var headGanyuWage "wages for head from ganyu"

* --- calculate regional wage rates based on district numbers
egen ganyuDistWR = mean(ganyuWR), by(district)
histogram(ganyuWR), by(district)

* ---- plotting results by district
mean ganyuWageRate
	matrix smean = r(table)
	local varmean = smean[1,1]
mean ganyuWageRate, over(district)
	matrix plot = r(table)'
	matsort plot 1 "down"
	matrix plot = plot'
	coefplot (matrix(plot[1,])), ci((plot[5,] plot[6,])) xline(`varmean')

* --- Collapse everything down to district level

qui include "$pathdo/copylabels.do"
	ds(hh_e* hh_b* case_id hhsize reside HHID PID _roster  region hh_wgt ea_id interview*), not
	collapse (max) `r(varlist)', by(case_id)
qui include "$pathdo/attachlabels.do"

g year = 2016
compress

save "$pathout/hh_labor_2016.dta", replace
