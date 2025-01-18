do "~/Dropbox/DIEP Labor Demand Study/setup"
drop _all
eststo clear

local data  ACS //  Data source:  ACS or CPS
global bartik employed
global vari indbroad
global weight n

use "${`data'}/`data'_workmeasures_collapsed_${vari}.dta", clear

if "`data'" == "ACS" {
	local baseyr 2005
	local geo czone
}
if "`data'" == "CPS" {
	local baseyr 1988
	local geo state
}

collapse (rawsum) employed $weight (mean) incwage_real [aw=$weight] if year >= `baseyr', by(`geo' ${vari} year)

* Generate base year industry employment share by geo
preserve
keep if year == `baseyr'
collapse (rawsum) $bartik $weight, by(`geo' ${vari})
bysort `geo':  egen N_emp = sum(employed)
bysort `geo': egen N_pop = sum($weight)
egen N_pop_all = sum($weight)
generate share_`baseyr' = employed/N_emp
generate weight_`baseyr' = N_pop/N_pop_all
keep weight_`baseyr' share_`baseyr' `geo' ${vari}
tempfile share_`baseyr'
save `share_`baseyr'', replace
restore

drop if indbroad == .

* Generate national sum employment {'shocks'}
preserve
collapse (rawsum) ${bartik}_nat = $bartik, by(${vari} year)
tempfile national
save `national', replace
restore

merge m:1 ${vari} year using `national', nogen keep(master match)
merge m:1 `geo' ${vari} using `share_`baseyr'', nogen keep(master match)

bysort `geo' ${vari} (year):  gen leaveout = ${bartik}_nat - $bartik

preserve

clonevar share1A = share_`baseyr'
clonevar share1B = share_`baseyr'
generate share2A = share_`baseyr' * weight_`baseyr'
clonevar share2B = share_`baseyr'

generate shift1A = log(${bartik}_nat * weight_`baseyr')
generate shift1A_leaveout = log(leaveout * weight_`baseyr')

generate shift1B = log(${bartik}_nat)
generate shift1B_leaveout = log(leaveout)

clonevar shift2A = ${bartik}_nat
clonevar shift2A_leaveout = leaveout

clonevar shift2B = ${bartik}_nat
clonevar shift2B_leaveout = leaveout

keep shift* share* `geo' ${vari} year ${weight}
rename ${weight} ${weight}I

if "${vari}" == "indbroad" {
	cap rename ind* ind
}
save "${`data'}/`data'_instrument_data_${vari}.dta", replace

restore


* Construct bartik
* Log national employment (shocks)
	* Weight by population size
	generate bartik1A = log(${bartik}_nat * weight_`baseyr') * share_`baseyr'
	generate bartik1A_leaveout = log(leaveout * weight_`baseyr') * share_`baseyr'

	label var bartik1A "Log Employment Bartik (Population Weighted)"
	label var bartik1A_leaveout "Leave-out Log Employment Bartik (Population Weighted)"

	* Unweighted
	generate bartik1B = log(${bartik}_nat) * share_`baseyr'
	generate bartik1B_leaveout = log(leaveout) * share_`baseyr'

	label var bartik1B "Log Employment Bartik"
	label var bartik1B_leaveout "Leave-out Log Employment Bartik"
	
* Untransformed national employment
	*  Weighted by population size
	generate bartik2A = ${bartik}_nat * weight_`baseyr' * share_`baseyr'
	generate bartik2A_leaveout = leaveout * weight_`baseyr' * share_`baseyr'
	
	label var bartik2A "Employment Bartik (Population Weighted)"
	label var bartik2A_leaveout "Leave-out Log Employment Bartik (Population Weighted)"
	
	*  Unweighted
	generate bartik2B = ${bartik}_nat * share_`baseyr'
	generate bartik2B_leaveout = leaveout * share_`baseyr'
	
	label var bartik2B "Employment Bartik (Population Weighted)"
	label var bartik2B_leaveout "Leave-out Log Employment Bartik (Population Weighted)"

gen ln_${bartik} = log($bartik)

collapse (rawsum) *${bartik} bartik* $weight (mean) incwage [aw=$weight], by(`geo' year)


label var incwage "Wage Income"
label var employed "Employment"
label var ln_employed "Log Employment"

save "${`data'}/`data'_bartik_${vari}.dta", replace

*  Stata code for histograms
*  Side by side scatter plots

twoway histogram ln_employed if inrange(ln_employed, 4, 18), color(maroon%60) lcolor(maroon%70) width(0.1) fraction || ///
       histogram bartik1A if inrange(bartik1A, 4, 18), color(navy%60) lcolor(navy%70) width(0.1) fraction || ///
	   histogram bartik1B if inrange(bartik1B, 4, 18), color(gray%60) lcolor(gray%70) width(0.1) fraction ||, ///  
       legend(order(1 "Log Employment Level" 2 "Population Weighted Bartik (1A)" 3 "Unweighted Bartik (1B)")) ///
       xlabel(, labsize(small) grid) ///
       ylabel(, labsize(small) nogrid) ///
       ytitle("Fraction of Obs", size(small)) ///
		graphregion(color(white)) plotregion(margin(none)) ///
		xscale(range(4 17.5)) xlabel(5(3)17)

foreach path in "" "_overleaf" {
	graph export "${figures`path'}/compare_logbartik_`data'_${vari}.png", replace

}

*  Need to save

preserve
foreach var of varlist employed bartik2A bartik2B {
	su `var', de
	*replace `var' = . if `var' < `r(p5)'
	replace `var' = . if `var' > `r(p90)'
	replace `var' = `var'/1000
	}

gen t=.

twoway histogram employed, color(maroon%60) lcolor(maroon%70) fraction width(10) || ///
       histogram bartik2A, color(navy%60) lcolor(navy%70) fraction width(10) || ///
	   histogram t, color(gray%60) lcolor(gray%70) fraction width(10) ||, ///
	   legend(order(1 "Employment Level" 2 "Population Weighted Bartik (2A)" 3 "Unweighted Bartik (2B)")) ///
       xlabel(, labsize(small) grid) ///
       ylabel(, labsize(small) nogrid) ///
	   graphregion(color(white)) plotregion(margin(none)) ///
		xscale(range(0 400)) xlabel(0(50)400) ///
	   name(g1, replace)

twoway histogram bartik2B, color(gray%60) lcolor(gray%70) fraction width(100) ///
		xtitle("") ///
		xlabel(, labsize(small) grid) ///
       ylabel(, labsize(small) nogrid) ///
	   graphregion(color(white)) plotregion(margin(none)) ///
		xscale(range(8800 22000)) xlabel(9000(1500)21000) ///
	   name(g2, replace)
	   
grc1leg2 g1 g2
foreach path in "" "_overleaf" {
	graph export "${figures`path'}/compare_levelbartik_`data'_${vari}.png", replace

}
restore

drop if !inrange(year, 2008, 2021) 
foreach var of varlist employed bartik2A bartik2B {
	replace `var' = `var'/1000
}

eststo clear

/* Calculate means and variances */
foreach var in ln_employed bartik1A bartik1B employed bartik2A bartik2B {
    summarize `var'
    scalar mean_`var' = string(round(r(mean), 0.01), "%12.2fc")
    scalar var_`var' = string(round(r(Var), 0.01), "%12.2fc")
}

/* Perform regressions */
foreach var in bartik1A bartik1B {
    reghdfe ln_employed `var', cluster(czone) absorb()
    scalar F_stat_`var' = string(round(e(F), 0.01), "%12.2fc")
    scalar coeff_`var' = string(round(_b[`var'], 0.01), "%12.2fc")

    reghdfe ln_employed `var', absorb(czone year) cluster(czone)
    scalar F_stat_`var'_FE = string(round(e(F), 0.01), "%12.2fc")
    scalar coeff_`var'_FE = string(round(_b[`var'], 0.01), "%12.2fc")

    reghdfe ln_employed `var', absorb(czone) cluster(czone)
    scalar F_stat_`var'_czone = string(round(e(F), 0.01), "%12.2fc")
    scalar coeff_`var'_czone = string(round(_b[`var'], 0.01), "%12.2fc")
}

foreach var in bartik2A bartik2B {
    reghdfe employed `var', cluster(czone) absorb()
    scalar F_stat_`var' = string(round(e(F), 0.01), "%12.2fc")
    scalar coeff_`var' = string(round(_b[`var'], 0.01), "%12.2fc")

    reghdfe employed `var', absorb(czone year) cluster(czone)
    scalar F_stat_`var'_FE = string(round(e(F), 0.01), "%12.2fc")
    scalar coeff_`var'_FE = string(round(_b[`var'], 0.01), "%12.2fc")

    reghdfe employed `var', absorb(czone) cluster(czone)
    scalar F_stat_`var'_czone = string(round(e(F), 0.01), "%12.2fc")
    scalar coeff_`var'_czone = string(round(_b[`var'], 0.01), "%12.2fc")
}

/* Create LaTeX table */
foreach path in "" "_overleaf" {
file open table_tex using "${figures`path'}/instrument_describe_${vari}.tex", write replace
file write table_tex "" // Clear the file content
file write table_tex "\begin{table}[htbp]\centering\renewcommand{\arraystretch}{1.5}" 
file write table_tex "\caption{Summary Statistics and First-Stage Regression Results}" 
file write table_tex "\begin{tabular}{lcccccccccccccc}" 
file write table_tex "\toprule" 
file write table_tex " & \multicolumn{7}{c}{Log Employment} & \multicolumn{7}{c}{Employment (000s)} \\"
file write table_tex "\cmidrule(lr){2-8} \cmidrule(lr){9-15}"
file write table_tex " & \multicolumn{1}{c}{Actual} & \multicolumn{3}{c}{Population Weighted Bartik} & \multicolumn{3}{c}{Unweighted Bartik} & \multicolumn{1}{c}{Actual} & \multicolumn{3}{c}{Population Weighted Bartik} & \multicolumn{3}{c}{Unweighted Bartik} \\"
file write table_tex "\cmidrule(lr){2-2} \cmidrule(lr){3-5} \cmidrule(lr){6-8} \cmidrule(lr){9-9} \cmidrule(lr){10-12} \cmidrule(lr){11-12}"
file write table_tex "Mean & \multicolumn{1}{c}{`=mean_ln_employed'} & \multicolumn{3}{c}{`=mean_bartik1A'} & \multicolumn{3}{c}{`=mean_bartik1B'} & \multicolumn{1}{c}{`=mean_employed'} & \multicolumn{3}{c}{`=mean_bartik2A'} & \multicolumn{3}{c}{`=mean_bartik2B'} \\"
file write table_tex "Variance & \multicolumn{1}{c}{`=var_ln_employed'} & \multicolumn{3}{c}{`=var_bartik1A'} & \multicolumn{3}{c}{`=var_bartik1B'} & \multicolumn{1}{c}{`=var_employed'} & \multicolumn{3}{c}{`=var_bartik2A'} & \multicolumn{3}{c}{`=var_bartik2B'} \\"
file write table_tex "\midrule" 

/* Write coefficients */
file write table_tex "$\beta_1$ &  & `=coeff_bartik1A' & `=coeff_bartik1A_czone' & `=coeff_bartik1A_FE' & `=coeff_bartik1B' & `=coeff_bartik1B_czone' & `=coeff_bartik1B_FE' &  & `=coeff_bartik2A' & `=coeff_bartik2A_czone' & `=coeff_bartik2A_FE' & `=coeff_bartik2B' & `=coeff_bartik2B_czone' & `=coeff_bartik2B_FE' \\"

/* Write F-statistics */
file write table_tex "F-statistic &  & `=F_stat_bartik1A' & `=F_stat_bartik1A_czone' & `=F_stat_bartik1A_FE' & `=F_stat_bartik1B' & `=F_stat_bartik1B_czone' & `=F_stat_bartik1B_FE' &  & `=F_stat_bartik2A' & `=F_stat_bartik2A_czone' & `=F_stat_bartik2A_FE' & `=F_stat_bartik2B' & `=F_stat_bartik2B_czone' & `=F_stat_bartik2B_FE' \\"

/* Add fixed effects rows */
file write table_tex "Unit Fixed Effects &  & & \checkmark & \checkmark &  & \checkmark & \checkmark &  &  & \checkmark & \checkmark &  & \checkmark & \checkmark \\"
file write table_tex "Time Fixed Effects &  &  &  & \checkmark &  &  & \checkmark &  &  &  & \checkmark &  &  & \checkmark \\"

/* Close table */
file write table_tex "\bottomrule" 
file write table_tex "\end{tabular}" 
file write table_tex "\end{table}" 
file close table_tex
}




/*
*drop if year == `baseyr'

if $lag == 1 local suffix
else local suffix _L$lag
save "${`data'}/`data'_bartik_${vari}`suffix'.dta", replace
drop if year > 2021

su bartik, detail
drop if !inrange(bartik, `r(p1)', `r(p99)')

* Some first stage-plots
binscatter2 $bartik bartik [aw=$weight], ///
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
