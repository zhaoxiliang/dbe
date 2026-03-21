*========================================================================
*! Xiliang Zhao, 2016.12.26
*Modified in 2020.5.27
*Modified in 2023.7.19, 2026.3.21
/*
https://rdpackages.github.io/rdrobust/
(1) rdrobust package:
rdrobust package include three commands: rdplot, rdbwselect, rdrobust

安装：
ssc install rdrobust, replace
net install rdrobust, from(https://raw.githubusercontent.com/rdpackages/rdrobust/master/stata) replace
(2) McCrary (2008) density test:
Using DCdensity.ado provided by McCrary, Copy it to \ado\plus\d\ before you can use it:
 http://eml.berkeley.edu/~jmccrary/DCdensity/

rddensity to do McCrary (2008) Test and plots:
ssc install rddensity, replace
net install rddensity, from(https://raw.githubusercontent.com/rdpackages/rddensity/master/stata) replace
net install lpdensity, from(https://raw.githubusercontent.com/nppackages/lpdensity/master/stata) replace

Reference: Calonico, Cattaneo, Farrell and Titiunik (2017): rdrobust: Software for Regression Discontinuity Designs, Stata Journal 17(2): 372-404.
*/
*========================================================================
global data " " //修改为数据所在目录
cd "$data"

set more off

use lee, clear
describe
summarize

drop if margin>.5 | margin<-.5
/*(1)画出结果变量与参考变量关系图: vote vs. margin
* draw figure 6. in Lee and Lemieux (2010)
*/

rdplot vote margin if margin>=-.5&margin<=.5, c(0) nbins(50 50) graph_options(legend(off) plotregion(style(none)) scale(1.35)  title("") xlabel(-0.5(0.1)0.5,format(%2.1f) nogrid) ylabel(,format(%2.1f) nogrid) ///
 xtitle("Democratic Vote Share Margin of Victory, Election t", margin(t=2)) ///
 ytitle("Vote Share, Election t+1") note(Note: Replicate figure 6 of Lee and Lemieumx (2010))  name(rdplot1, replace)) // replicate figure 6 in Lee and Lemieux (2010)
* Probability of win

rdplot win margin if margin>=-.5&margin<=.5, c(0) nbins(50 50) graph_options(legend(off) plotregion(style(none)) scale(1.35)  title("") xlabel(-0.5(0.1)0.5, format(%2.1f) nogrid) ylabel(,format(%2.1f) nogrid) ///
 xtitle("Democratic Vote Share Margin of Victory, Election t", margin(t=2)) ///
 ytitle("Vote Share, Election t+1") note(Note: Replicate figure 9 of Lee and Lemieumx (2010))  name(rdplot1, replace)) // replicate figure 9 in Lee and Lemieux (2010)
  
*add ci, or ci with shade
rdplot vote margin if margin>=-.5&margin<=.5, c(0) p(1) nbins(50 50) ci(95) shade graph_options(legend(off) title("") xlabel(-0.5(0.1)0.5) ///
 xtitle("Democratic Vote Share Margin of Victory, Election t") ///
 ytitle("Vote Share, Election t+1") note(Note: Replicate figure 6 of Lee and Lemieumx (2010))  name(rdplot3, replace)) // replicate figure 6 in Lee and Lemieux (2010)
 
 
/*(2) 画出协变量与参考变量关系图：检验连续性假设：voteprev vs. margin*/
*Open original data of Lee(2008)

rdplot voteprev margin if inrange(margin, -.5, .5), c(0)p(2) graph_options(scale(1.2) plotregion(style(none)) xtitle("Democratic Vote Share Margin of Victory, Election t", margin(t=2)) ytitle("Vote Share, Election t-1")  yscale(r(0.30 0.70)) xlabel(-.5(.1).5, format(%2.1f)) ylabel(0.3(.1)0.7, format(%2.1f) nogrid) legend(off) note(Note: Replicate figure 4(b) of Lee (2008))  name(rdplot4, replace))



/*(3) 画参考变量密度图：检验局部随机化假设 McCrary Test*/
use lee,clear

*可以直接用rddensity vote, plot画图并报告检验结果
rddensity margin, c(0) plot plot_range(-.5 .5) hist_range(-.5 .5) graph_opt(xtitle("Democratic Vote Share Margin of Victory, Election t") xlabel(-.5(.1).5) legend(off)) 


/*(4) 选择最优带宽:h_CV=0.28, rdbwselect */
use lee,clear
keep if margin>=-.5&margin<=.5
rdbwselect vote margin
rdbwselect vote margin, all 

/*(5) 估计因果效应*/

*手动估计参数（相当于矩形核）：LLR
use lee, clear
keep if margin>=-0.125 & margin<=0.125
gen d=margin>0 // 产生分组变量
*计算标准化变量
gen  x = margin/ 0.125
*产生权重：三解核
gen k=1/sqrt(6)*(1- abs(x)/sqrt(6))*(abs(x)<sqrt(6))

** 估计模型
reg vote 1.d, vce(robust)
eststo m1
reg vote d##c.margin, vce(robust)
eststo m2

reg vote 1.d [aw = k], vce(robust)
eststo m3
reg vote d##c.margin [aw = k], vce(robust)
eststo m4

*estimate stats m1 m2
esttab m1 m2 m3 m4 using rdd.rtf, replace star(* .10 ** .05 *** .01) nogap  mtitle("NW" "LLR") se(%5.4f) ar2 keep(1.d margin 1.d#c.margin _cons)

*多项式估计，选择最优阶数p=2
use lee, clear
keep if margin<=.5&margin>=-.5
gen d=margin>0
gen x=margin
gen x2=x^2
gen x3=x^3
gen x4=x^4

reg vote d##c.x, vce(robust)
eststo m1
reg vote d##c.(x x2), vce(robust)
eststo m2
reg vote d##c.(x x2 x3), vce(robust)
eststo m3
reg vote d##c.(x x2 x3 x4), vce(robust)
eststo m4
esttab m1 m2 m3 m4 using rdd.rtf, replace star(* .10 ** .05 *** .01) nogap mtitle("p = 1" "p = 2" "p = 3" "p = 4") se(%5.4f) ar2 aic(%10.4f) bic(%10.4f) drop(0.d 0.d#c.x 0.d#c.x2 0.d#c.x3 0.d#c.x4)


* 用rdrobust估计
rdrobust vote margin, c(0) p(3)
rdrobust vote margin, c(0) p(3) all
rdrobust vote margin, c(0) p(1) all h(.125)
rdrobust vote margin, c(0) p(1) all h(.125) kernel(uni)


/*(6) 检验*/
*a)局部随机化假设检验McCrary(2008)密度检验
*Using rddensity to do the test
use lee, clear
keep if margin >=-.5 &margin <=.5
rddensity margin, all
rddensity margin, p(1) all
rddensity margin, p(1) all plot plot_range(-.5 .5) hist_range(-.5 .5) graph_opt(xtitle("Democratic Vote Share Margin of Victory, Election t") xlabel(-.5(.1).5, format(%2.1f)) ylabel(, format(%2.1f)) legend(off))

*b)协变量连续性检验
use lee, clear
keep if margin >=-.5 &margin <=.5

gen x=margin
gen x2=x^2
gen x3=x^3
gen x4=x^4
gen d=margin>=0
reg voteprev d##c.(x x2 x3 x4) , vce(robust)

reg voteprev d##c.(x x2) if inrange(margin, -.125, .125), vce(robust)

rdrobust voteprev margin, p(1) h(.125)
rdrobust voteprev margin, p(2) h(.125)

*c) 其它断点效应分析：安慰剂检验
*Plots: RDD plots
use lee, clear
rdplot vote margin if margin<0, c(-.25) graph_options(legend(off) title("") xlabel(-.5(.1)0))


rdplot vote margin if margin>=0, c(.25) graph_options(legend(off) title("") xlabel(0(.1).5))
*Placebo test: RDD estimation
rdrobust vote margin if margin<0, c(-.25)
rdrobust vote margin if margin>=0, c(.25)

*d)用不同带宽进行估计 

forvalues h = .5(-.1).1 {
qui rdrobust vote margin, h(`h') p(1)
di "bandwidth h= " `h',  " TE=" e(tau_bc), " S.E.=" e(se_tau_rb), " p-value=" e(pv_rb) 
}
  
tempname resmat
forvalue h = .5(-.1).1 {
qui rdrobust vote margin, h(`h') p(1)
matrix `resmat'=nullmat(`resmat')\(e(tau_bc), e(se_tau_rb), e(pv_rb)) // 加一行到矩阵`resmat'上
 local names `"`names'`"`h'"'"' //产生行名
}
matrix coln `resmat' = "treatment effect" "robust std err" "p-value" //定义列名
matrix rown `resmat' = `names' //定义行名
matlist `resmat', row("Bandwidth") format(%8.4f)
  

  
  
