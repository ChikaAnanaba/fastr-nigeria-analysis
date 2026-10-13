* Nigeria FASTR Round 1: vaccine availability and electricity continuity
* Published summary extraction, descriptive comparisons, tables and charts.
* Run this whole file. Update the project path below if your folder differs.
* New outputs use the readiness_ prefix; the earlier outputs are retained.

version 19.0
clear all
set more off
local project_root "C:/Users/nwoke/OneDrive/Documents/FASTR_Nigeria"
cd "`project_root'"
confirm file "data/FASTR-Data.xlsx"
capture mkdir "outputs"
capture log close
log using "outputs/FASTR_Nigeria_expanded.log", text replace

* Indicator IDs: 1 vaccine average; 2 electricity source; 3 continuity.
* Different indicator meanings must be retained even though all use 0-100.
tempfile national zones programme

* ---------- National summaries ----------
import excel using "data/FASTR-Data.xlsx", ///
    sheet("Final selected indicators") allstring clear
assert strtrim(Z[1]) == "NG_R1"
generate long source_row = _n
quietly count if strtrim(C) == "N"
assert r(N) == 1
quietly summarize source_row if strtrim(C) == "N", meanonly
local sample_row = r(min)
scalar national_sample = real(Z[`sample_row'])
assert scalar(national_sample) == 3989
quietly count if strtrim(B) == "data collection range"
assert r(N) == 1
quietly summarize source_row if strtrim(B) == "data collection range", meanonly
local period_row = r(min)
assert strtrim(Z[`period_row']) == "May-July 2025"

generate byte indicator_id = .
replace indicator_id = 1 if strtrim(C) == "SUP_05AAA_*"
replace indicator_id = 2 if strtrim(C) == "INF_04"
replace indicator_id = 3 if strtrim(C) == "INF_05"
keep if !missing(indicator_id)
assert _N == 3
isid indicator_id
rename C indicator_code
rename B source_indicator
rename Z availability_pct
keep indicator_id indicator_code source_indicator availability_pct
replace indicator_code = strtrim(indicator_code)
replace source_indicator = strtrim(source_indicator)
destring availability_pct, replace
assert !missing(availability_pct)
assert inrange(availability_pct, 0, 100)
generate str36 indicator_label = ""
replace indicator_label = "Average key vaccine availability" if indicator_id == 1
replace indicator_label = "Primary electricity source" if indicator_id == 2
replace indicator_label = "Continuous electricity in past 7 days" if indicator_id == 3
generate long survey_sample_n = scalar(national_sample)
generate str8 country_round = "NG_R1"
generate str20 survey_period = "May-July 2025"
format availability_pct %9.2f
sort indicator_id
save `national'
save "outputs/readiness_national_summary.dta", replace
export delimited using "outputs/readiness_national_table.csv", replace
list indicator_label availability_pct survey_sample_n, noobs

graph hbar (asis) availability_pct, ///
    over(indicator_label, sort(indicator_id)) ///
    blabel(bar, format(%4.2f)) ylabel(0(20)100) ///
    ytitle("Published indicator value (%)") ///
    title("Nigeria: vaccine availability and electricity") ///
    note("Source: GFF FASTR published summaries, Nigeria Round 1, May-July 2025." ///
         "Vaccine average and facility percentages measure different things.")
graph export "outputs/readiness_national.png", width(1800) replace
graph save "outputs/readiness_national.gph", replace

* ---------- Zone summaries ----------
import excel using "data/FASTR-Data.xlsx", ///
    sheet("by city or region") allstring clear
assert strtrim(CT[1]) == "NG_R1"
assert strtrim(CT[4]) == "North-Central"
assert strtrim(CU[4]) == "North-East"
assert strtrim(CV[4]) == "North-West"
assert strtrim(CW[4]) == "South-East"
assert strtrim(CX[4]) == "South-South"
assert strtrim(CY[4]) == "South-West"
generate long source_row = _n
quietly count if strtrim(B) == "Sample"
assert r(N) == 1
quietly summarize source_row if strtrim(B) == "Sample", meanonly
local sample_row = r(min)
local j = 0
foreach col in CT CU CV CW CX CY {
    local ++j
    local sample`j' = real(`col'[`sample_row'])
}
generate byte indicator_id = .
replace indicator_id = 1 if strtrim(C) == "SUP_05AAA_*"
replace indicator_id = 2 if strtrim(C) == "INF_04"
replace indicator_id = 3 if strtrim(C) == "INF_05"
keep if !missing(indicator_id)
assert _N == 3
isid indicator_id
keep indicator_id CT CU CV CW CX CY
rename (CT CU CV CW CX CY) (value1 value2 value3 value4 value5 value6)
reshape long value, i(indicator_id) j(group_id)
rename value availability_pct
destring availability_pct, replace
generate str20 zone = ""
replace zone = "North-Central" if group_id == 1
replace zone = "North-East" if group_id == 2
replace zone = "North-West" if group_id == 3
replace zone = "South-East" if group_id == 4
replace zone = "South-South" if group_id == 5
replace zone = "South-West" if group_id == 6
generate long survey_sample_n = .
forvalues j = 1/6 {
    replace survey_sample_n = `sample`j'' if group_id == `j'
}
assert _N == 18
isid indicator_id zone
assert !missing(availability_pct, survey_sample_n)
assert inrange(availability_pct, 0, 100)
assert survey_sample_n > 0 & survey_sample_n == floor(survey_sample_n)
bysort indicator_id: egen total_sample = total(survey_sample_n)
assert total_sample == scalar(national_sample)
drop total_sample
merge m:1 indicator_id using `national', ///
    keepusing(indicator_code indicator_label source_indicator country_round survey_period) ///
    assert(match) nogen
format availability_pct %9.2f
sort indicator_id group_id
save `zones'
save "outputs/readiness_zone_summary.dta", replace
export delimited using "outputs/readiness_zone_table.csv", replace

forvalues k = 1/3 {
    preserve
    keep if indicator_id == `k'
    local label = indicator_label[1]
    graph hbar (asis) availability_pct, ///
        over(zone, sort(1) descending) ///
        blabel(bar, format(%4.2f)) ylabel(0(20)100) ///
        ytitle("Published indicator value (%)") ///
        title("Nigeria: `label' by zone", size(medsmall)) ///
        note("Source: GFF FASTR published summaries, Nigeria Round 1." ///
             "Separate group summaries; not facility-level associations.")
    graph export "outputs/readiness_zone_indicator`k'.png", width(1800) replace
    graph save "outputs/readiness_zone_indicator`k'.gph", replace
    restore
}

* ---------- BHCPF programme groups ----------
import excel using "data/FASTR-Data.xlsx", ///
    sheet("by facility type") allstring clear
assert strtrim(AV[1]) == "NG_R1"
assert strtrim(AV[3]) == "Non-BHCPF"
assert strtrim(AW[3]) == "BHCPF"
generate long source_row = _n
quietly count if strtrim(B) == "Sample"
assert r(N) == 1
quietly summarize source_row if strtrim(B) == "Sample", meanonly
local sample_row = r(min)
local sample1 = real(AV[`sample_row'])
local sample2 = real(AW[`sample_row'])
generate byte indicator_id = .
replace indicator_id = 1 if strtrim(C) == "SUP_05AAA_*"
replace indicator_id = 2 if strtrim(C) == "INF_04"
replace indicator_id = 3 if strtrim(C) == "INF_05"
keep if !missing(indicator_id)
assert _N == 3
isid indicator_id
keep indicator_id AV AW
rename (AV AW) (value1 value2)
reshape long value, i(indicator_id) j(group_id)
rename value availability_pct
destring availability_pct, replace
generate str12 programme_group = cond(group_id == 1, "Non-BHCPF", "BHCPF")
generate long survey_sample_n = cond(group_id == 1, `sample1', `sample2')
assert _N == 6
isid indicator_id programme_group
assert !missing(availability_pct, survey_sample_n)
assert inrange(availability_pct, 0, 100)
assert survey_sample_n > 0 & survey_sample_n == floor(survey_sample_n)
bysort indicator_id: egen total_sample = total(survey_sample_n)
assert total_sample == scalar(national_sample)
drop total_sample
merge m:1 indicator_id using `national', ///
    keepusing(indicator_code indicator_label source_indicator country_round survey_period) ///
    assert(match) nogen
format availability_pct %9.2f
sort indicator_id group_id
save `programme'
save "outputs/readiness_programme_summary.dta", replace
export delimited using "outputs/readiness_programme_table.csv", replace

forvalues k = 1/3 {
    preserve
    keep if indicator_id == `k'
    local label = indicator_label[1]
    graph hbar (asis) availability_pct, ///
        over(programme_group, sort(1) descending) ///
        blabel(bar, format(%4.2f)) ylabel(0(20)100) ///
        ytitle("Published indicator value (%)") ///
        title("Nigeria: `label' by programme group", size(medsmall)) ///
        note("Source: GFF FASTR published summaries, Nigeria Round 1." ///
             "Descriptive comparison; does not establish programme effects.")
    graph export "outputs/readiness_programme_indicator`k'.png", width(1800) replace
    graph save "outputs/readiness_programme_indicator`k'.gph", replace
    restore
}

* ---------- Full-precision gaps for each indicator ----------
use `programme', clear
keep indicator_id indicator_code indicator_label group_id availability_pct
reshape wide availability_pct, i(indicator_id indicator_code indicator_label) j(group_id)
generate double bhcpf_minus_nonbhcpf_pp = availability_pct2 - availability_pct1
rename availability_pct1 nonbhcpf_pct
rename availability_pct2 bhcpf_pct
tempfile pgaps
save `pgaps'

use `zones', clear
bysort indicator_id: egen double zone_max_pct = max(availability_pct)
bysort indicator_id: egen double zone_min_pct = min(availability_pct)
generate double highest_minus_lowest_zone_pp = zone_max_pct - zone_min_pct
keep indicator_id zone_max_pct zone_min_pct highest_minus_lowest_zone_pp
bysort indicator_id: keep if _n == 1
merge 1:1 indicator_id using `pgaps', assert(match) nogen
format *_pct *_pp %9.2f
sort indicator_id
save "outputs/readiness_comparison_gaps.dta", replace
export delimited using "outputs/readiness_comparison_gaps.csv", replace
list indicator_label bhcpf_minus_nonbhcpf_pp highest_minus_lowest_zone_pp, noobs

* ---------- Record only checks actually implemented ----------
file open checks using "outputs/readiness_extraction_checks.txt", write text replace
file write checks "Nigeria Round 1: vaccine and electricity summary extraction" _n
file write checks "Country-round, survey period and subgroup header checks passed." _n
file write checks "Exactly three unique selected indicators found in each source sheet." _n
file write checks "Expected national/zone/programme row counts: 3/18/6; unique keys passed." _n
file write checks "Nonmissing numeric values, 0-100 ranges and positive integer survey samples passed." _n
file write checks "Zone and programme survey samples each reconcile to 3,989 per indicator." _n
file write checks "Survey samples are not confirmed indicator denominators." _n
file write checks "No combined readiness score, correlation, regression, causal analysis or HMIS linkage." _n
file write checks "Electricity measures do not establish cold-chain functionality." _n
file write checks "Separate summaries do not identify facilities with overlapping gaps." _n
file close checks
display "Completed: expanded tables/datasets, gap table, seven charts, checks and log."
log close
