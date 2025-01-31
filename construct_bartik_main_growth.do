do "~/Dropbox/DIEP Labor Demand Study/setup"
drop _all
eststo clear


local data  ACS //  Data source:  `data' or `data'
global bartik employed
global vari occ
global lag 1
global weight n

use "${`data'}/`data'_workmeasures_collapsed.dta", clear

if "`data'" == "ACS" {
	local baseyr 2005
	local geo czone
}
if "`data'" == "CPS" {
	local baseyr 1988
	local geo state
}

if "`data'"  == "CPS" {
	preserve
	collapse (mean) hours_workedyr [aw=nE] if year >= `baseyr', by(`geo' disabwrk year)
	reshape wide hours*, i(`geo' year) j(disabwrk)
	gen hours_ratio = log(hours_workedyr1/hours_workedyr0)
	tempfile hours
	save `hours', replace
	restore
	collapse (rawsum) employed $weight (mean) emprate incwage_real hours_workedyr [aw=$weight] if year >= `baseyr', by(`geo' ${vari} year)

}

else collapse (rawsum) employed $weight (mean) emprate incwage_real [aw=$weight] if year >= `baseyr', by(`geo' ${vari} year)


* Generate actual employment growth per `geo' (what we're instrumenting for)
preserve
collapse (rawsum) $bartik, by(`geo' year)
bysort `geo' (year): gen log_change = (($bartik) - ($bartik[_n-$lag]))/$bartik[_n-$lag]
label var log_change "Change in log employment"
tempfile actual_growth
save `actual_growth', replace
restore

* Generate base year industry employment share by geo
preserve
keep if year == `baseyr'
collapse (rawsum) $bartik, by(`geo' ${vari})
bysort `geo': egen N_emp = sum(employed)
generate share_`baseyr' = employed/N_emp
keep share_`baseyr' `geo' ${vari}
tempfile share_`baseyr'
save `share_`baseyr'', replace
restore

* Generate national growth
preserve
collapse (rawsum) ${bartik}_nat = $bartik, by(${vari} year)
bysort ${vari} (year): gen national_growth = ($bartik - $bartik[_n-$lag])/$bartik[_n-$lag]
bysort ${vari} (year): gen national_change = ($bartik - $bartik[_n-$lag])
label var national_growth "National industry growth"
tempfile national_growth
save `national_growth', replace
restore

* Generate own employment growth per industry x `geo'
bysort `geo' ${vari} (year): gen own_growth = ($bartik - $bartik[_n-$lag])/$bartik[_n-$lag]

merge m:1 ${vari} year using `national_growth', nogen keep(master match)
merge m:1 `geo' ${vari} using `share_`baseyr'', nogen keep(master match)

bysort `geo' ${vari} (year):  gen leaveout_growth = (national_change - ($bartik - $bartik[_n-$lag]))/(${bartik}_nat[_n-$lag] - $bartik[_n-$lag])

* Construct bartik
generate bartik = national_growth*share_`baseyr'
generate bartik_leaveout = leaveout_growth*share_`baseyr'

collapse (rawsum) bartik* $weight (mean) emprate incwage [aw=$weight], by(`geo' year)

merge m:1 `geo' year using `actual_growth', nogen keep(master match)
capture merge m:1 `geo' year using `hours', nogen keep(master match)

label var emprate "Employment Rate"
label var incwage "Wage Income"
label var bartik "Bartik"
label var bartik_leaveout "Leave-out Bartik"
label var log_change "Actual Growth"

drop if year == `baseyr'

if $lag == 1 local suffix
else local suffix _L$lag
save "${`data'}/`data'_bartik_${vari}`suffix'.dta", replace
drop if year > 2021

su log_change, detail
drop if !inrange(log_change, `r(p1)', `r(p99)')

su bartik, detail
drop if !inrange(bartik, `r(p1)', `r(p99)')

replace log_change = log_change*100
replace bartik = bartik*100
* Some first stage-plots
binscatter2 log_change bartik [aw=$weight], ///
	name(bartik_binscatter, replace) ///
	xtitle("Bartik (%)") ytitle("Employment Growth (%)") 
foreach path in "" "_overleaf" {
	graph export "${figures`path'}/firststage_year_`geo'`data'_${vari}`suffix'_growth.pdf", replace
}

*  Only stating identifying assumptions (some discussion) + maybe calculating Rotemberg 

twoway (histogram log_change, color(maroon%60) lcolor(maroon%70) width(0.4) percent) ///
       (histogram bartik, color(navy%60) lcolor(navy%70) width(0.4) percent), ///
	   	name(bartik_hist, replace) ///
       xlabel(, labsize(small) grid) ///
       ylabel(, labsize(small) nogrid) ///
       ytitle("Frequency (%)", size(small)) ///
       xtitle("Growth (%)", size(small)) ///
	   legend(order(1 "Actual" 2 "Bartik")) ///
       graphregion(color(white)) plotregion(margin(none))
foreach path in "" "_overleaf" {
	graph export "${figures`path'}/bartik_hist_`data'_${vari}`suffix'.pdf", replace
}

collapse (mean) bartik* log_change [aw=n], by(year)
twoway scatter bartik log_change year, ///
	name(bartik_scatter, replace) ///
	legend(order(1 "Bartik" 2 "Actual")) ///
	ytitle("Growth %") xtitle("Year")
	
foreach path in "" "_overleaf" {
	graph export "${figures`path'}/bartik_scatter_`data'_${vari}`suffix'.pdf", replace
}


/*
foreach var of varlist bartik* log_change {
	bysort year: egen m`var' = mean(`var')
	generate `var'd = `var' - m`var'
	drop m`var'
}
*/

/*
preserve
keep if inlist(year, 2006, 2012, 2018, 2021)
gen to_show = "{&Beta} = "
regress log_changed bartikd if year == 2006
replace to_show = to_show + string(round(e(b)[1,1],0.0001)) if year == 2006
regress log_changed bartikd if year == 2012
bysort year: replace to_show = to_show + string(round(e(b)[1,1],0.0001)) if year == 2012
regress log_changed bartikd if year == 2018
bysort year: replace to_show = to_show + string(round(e(b)[1,1],0.0001)) if year == 2018
regress log_changed bartikd if year == 2021
bysort year: replace to_show = to_show + string(round(e(b)[1,1],0.0001)) if year == 2021

twoway scatter log_changed bartikd, by(year, legend(off) note("") rescale) 
restore
*/

	   