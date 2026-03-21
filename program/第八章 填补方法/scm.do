*!Xiliang ZHAO, Dec. 2, 2016
*Modified in May 23, 2020
*修改为中文，2022.7.27
*Modified in 2023.7.16, 2025.4.22, 2026.3.21
*========================================================================
* 合成控制法
*Sythetic Control Methods, Abadie et al. (2010) 
*https://web.stanford.edu/~jhain/Video/SynthDemo.mp4
*========================================================================

global data " " //修改为数据所在目录
cd "$data"

use smoking, clear
*数据结构
gen treat = (state ==3 & year>=1989)
panelview cigsale treat , i( state ) t(year) type(treat)
*======================================
*Generage Figure 1. Linear trend of treated group and average control group 
*======================================
*Prepare data 
drop if state == 3 // excluding California
collapse (mean) cigsale, by(year) // Generate the averages of control states
gen co = 1 // Generate an indicator for averages controls
append using smoking

*lpattern(dash)-dashed line, lcolor(black)-color of line
line cigsale year if state==3,lc(black) ||line cigsale year if co==1, ///
lp(dash) lcolor(black) xline(1988, lp(dot) lc(black)) ///
 text(25 1988 `"99议案通过{&rarr}"', placement(sw)) ///
 legend(label(1 "加州") label(2 "美国其余州") col(1) pos(1) ring(0) region(lstyle(none))) ///
xtitle(年份, margin(t=2)) ytitle("人均香烟销售量（包）") xlabel(1970(5)2000) ylabel(0(20)140) name(syn1, replace) scale(1.2)

*======================================
*Do the synthetic control analysis 
*covariates includes the averages of cigsale, beer, lnincome, retprice, age5to24, and three years of cigsale 1988 1980 1975, the result will be saved in estout.dta
*======================================
use smoking, clear
tsset state year

synth cigsale beer lnincome retprice age15to24 cigsale(1988) cigsale(1980) cigsale(1975) , ///
 trunit(3) trperiod(1989) xperiod(1980(1)1988) keep(estout, replace) fig // add option "fig" to show figure 2
 
/*add options "nested" and "allopt" to get better synth and better matching
synth cigsale beer lnincome retprice age15to24 cigsale(1988) cigsale(1980) cigsale(1975) , ///
 trunit(3) trperiod(1989) xperiod(1980(1)1988) nested  keep(estout, replace) // add option "fig" to show figure 2
*/
*======================================
*Draw Figure 2 & 3 using generated medium outcome data: estout.dta
*======================================
use estout,clear

*figure 2. Treated vs. synthetic control
two line _Y_treated _time ||line _Y_synthetic _time, lp(dash) lc(black) xline(1988,lp(dot) lc(black)) ///
 xtitle(年份, margin(t=2)) ytitle("人均香烟销售量差别（包）") ylabel(0(20)120) ///
 text(25 1988 "99法案通过{&rarr}", placement(sw)) ///
 legend(label(1 "加州") label(2 "合成加州") col(1) pos(1) ring(0) region(lstyle(none))) xlabel(1970(5)2000) name(syn2, replace) scale(1.4)


*figure 3. Treated effects
gen te= _Y_treated- _Y_synthetic 
line te _time, xline(1988,lp(dot) lc(black)) yline(0,lp(dash) lc(black)) ///
 text(-25 1988 "99法案通过{&rarr}", placement(sw)) /// placement() et a. options for text()
 xtitle(年份, margin(t=2)) ytitle("人均香烟销售量（包）") lc(black) xlabel(1970(5)2000) name(syn3, replace) scale(1.4) legend(region(lstyle(none)))
 
 
*======================================
*Robustness Test: Placebo tests or Inference*
*======================================
set more off
use smoking,clear
tsset state year
* Obtain some numbers which will use later
qui tab state
local n = r(r) // # of units
qui tab year
local n_year = r(r) // # of years

*======================================
*Specify the following variables
*User can change the values here according to users' researches
*======================================
local date_t = "1989"
local m = 2 // To limit the MSPE of controls at m times of MSPE of treated group, =0 means no limit
*local slow = "nested" // unstar it to use "nested" option in synth command
local id_t=3 // The id of treated unit
local treat_name ="加州" // Treated names in graph
local ctrl_name="控制州" // control group names in graph
local xtitle "年份"
local ytitle "人均香烟销售量差别（包）"
local saving "syn_plot" //saving graphs
*======================================

tempname resmat

forvalues i=1/`n' {		
synth cigsale beer lnincome retprice age15to24 cigsale(1988) cigsale(1980) cigsale(1975) , ///
 trunit(`i') trperiod(`date_t') xperiod(1980(1)1988) `slow' keep(tmp`i', replace) 
 
*
matrix rm=e(RMSPE)
local rmspe = rm[1,1]
 
 use tmp`i',clear
 keep _Y_treated _Y_synthetic _time
 gen te = _Y_treated- _Y_synthetic 
 gen id = `i'
 keep in 1/`n_year' //1970-2000, there are 31 years, which is keep in the first 31 obs.
 gen te2 = te*te // use it to calculate MSPE
 local n_before = `date_t' - _time[1] // position of the pretreatment date
 local n_after = `n_before' + 1 //start of treatment period
 qui sum te2 in 1/`n_before' // MSPE
 local mspe_pre = r(mean) // MSPE for pretreatment periods
 qui sum te2 in `n_after'/`n_year'
 local mspe_post = r(mean) // MSPE for posttreatment periods
 local r = `mspe_post'/`mspe_pre'
 
 matrix `resmat' = nullmat(`resmat')\(`rmspe', `mspe_pre', `mspe_post', `r') //resmat saves the RMSPE for each model
 local names `"`names'`"`i'"'"' // names of each

 save tmp`i', replace
 
use smoking,clear
tsset state year
}
	mat colnames `resmat' = "RMSPE"  "MSPE_pre" "MSPE_post" "Abadie_R"
	mat rownames `resmat' = `names'
	matlist `resmat', row("Treated Unit")

*Placebo Graphs - Draw Figure 3
*Get the RMSPE of the treated unit

local RMSPE_t=`resmat'[`id_t',1]
use tmp1, clear
local num = 0 // # of units includes in the graph
forvalues i=2/`n' {
	if `m'==0 {
		append using tmp`i'
		local num = `num' + 1
	}
	else if `resmat'[`i',1]^2<=`m'*`RMSPE_t'^2 { // MSPE comparation
		append using tmp`i'
		local num = `num' + 1
	}
}


*======================================
*Draw Placebo test graphs

set scheme s1mono

local s="" // string to store the graph command
local controls = "" //string to store the id of control units used
local num_t = `num'+1 // # postion to identify the treated unit

levelsof id, local(levels)
foreach l of local levels {
	if `l'!=`id_t' {
	local s = "`s'"+"(line te _time if id==`l', lc(gs13))"
	local controls = "`controls'"+" "+"`l'"
	}
}

local date_before = `date_t'-1
two `s'(line te _time if id==`id_t', lc(black)), ///
legend(order(`num_t' "`treat_name'" `num' "`ctrl_name'") cols(1) pos(11) ring(0) region(lstyle(none))) xline(`date_before', lp(dot) lc(black)) yline(0, lp(dash) lc(black)) ///
 xlabel(1970(5)2000) xtitle("`xtitle'", margin(t=2)) ytitle("`ytitle'") saving(`saving'_`m', replace)  name(placebo, replace) scale(1.4)

di "# of controls after limit `m' times of RMSPE of treated unit: " `num'
di "ID of controls:" "`controls'"


*======================================
*Draw permutation test R of Abadie et al. (2010)
*======================================
clear
svmat `resmat', names(col)
save tmp_R, replace //unstar this line if you want to save the file 

histogram Abadie_R, freq width(1) text(1 80 "加州{&rarr}", placement(s)) xtitle("99议案之后和之前的均方预测误差之比", margin(t=2)) lwidth(none) name(permutation, replace) scale(1.2)


*======================================
*delete all temprary files
!del tmp* 
erase estout.dta


*====================================== 
 /*Another user written command: synth_runner
 Galiani and Quistorff(2017). The synth_runner packages: Utilites to automate
 synthetic control estimation using synth, The Stata Journal, 17(4): 834-849.
 ssc install synth_runner, all replace
 or 
 search synth_runner, and install
 *======================================*/
set scheme s2color
use smoking, clear
tsset state year
synth_runner cigsale beer(1984(1)1988) lnincome(1972(1)1988) retprice age15to24 cigsale(1988) cigsale(1980) cigsale(1975), trunit(3) trperiod(1989) gen_vars

*安慰剂检验图 
single_treatment_graphs, trlinediff(-1) effects_ylabels(-30(10)30) effects_ymax(35) effects_ymin(-35)
*因果效应图
effect_graphs, trlinediff(-1)
*p值图
pval_graphs

*========================================================================
* 合成双重差分法(Sythetic DID)
*命令sdid可以通过method()选项做did, sc, sdid
*========================================================================

use smoking, clear
gen treat = (state ==3 & year>=1989)
panelview cigsale treat , i( state ) t(year) type(treat)

sdid cigsale state year treat, vce(placebo) seed(1213) graph g1on g1_opt(xtitle("")) g2_opt(ylabel(0(50)150)) 

matrix list e(series)
matrix list e(difference)


*画出event plot
sdid_event cigsale state year treat, vce(placebo) brep(50) placebo(all)

mat res = e(H)[2..32, 1..5]
svmat res
gen id = _n - 1 if !missing(res1)
replace id = 12 - _n if _n > 12 & !missing(res1)
sort id
twoway (rarea res3 res4 id, lc(gs10) fc(gs11%50)) (scatter res1 id, mc(blue) ms(d) con(l) lc(gs1)), legend(off) title(sdid_event) xtitle(Relative time to treatment change) ytitle(Women in Parliament) yline(0, lc(red) lp(-)) xline(0, lc(black) lp(solid)) name(eventplot, replace)



*可以加控制变量，但要求平衡面板，不存在缺失值，并且具有时变性
sdid cigsale state year treat, vce(placebo) seed(1213) graph g1_opt(xtitle("")) g2_opt(ylabel(0(50)150)) covariates(retprice)


*========================================================================
* 回归合成方法
*========================================================================

use smoking, clear
xtset state year

rcm cigsale, trunit(3) trperiod(1989) method(lasso)

* 进行随机置换检验
rcm cigsale, trunit(3) trperiod(1989) method(lasso) placebo(unit)





 
 
 