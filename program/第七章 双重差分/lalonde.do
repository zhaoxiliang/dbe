*LaLonde实验数据和非实验数据的DID分析
*Xiliang Zhao, 2024.7.9
*Modified in 2025.4.22, 2026.3.21
global data " " //修改为数据所在目录
cd "$data"


*========================================================================
*1. NSW+CPS数据
*========================================================================
use nsw_cps, clear
*构造面板数据
gen id = _n
expand 3
sort id
gen year = 1974
by id: replace year=1975 if _n==2
by id: replace year=1978 if _n==3

gen pre = year==1974
gen post = year==1978

gen re = re74
replace re = re75 if year==1975
replace re = re78 if year==1978

*协变量二元特征均不时变，年龄除外
replace age = age - 3 if year==1974
replace age = age - 2 if year==1975

*产生treat变量
gen D = treat *(year>1975)
save nsw_cps_panel, replace

*画出数据结构图
*panelview要求截面个体不能多于1000个，所以只画出前1000个个体
use nsw_cps_panel, clear
panelview re D if i<1000,i(id) t(year) type(treat) ylabdist(100)


*========================================================================
*经典DID 
*========================================================================

*(1) 矩估计：difference-in-means
reg re treat if year==1978, r //-8497.51

*difference-in-difference
*双重差分法75/78年数据-矩估计
su re if treat==1 & year==1978
local y11 = r(mean)
su re if treat==1 & year==1975
local y10 = r(mean)
su re if treat==0 & year==1978
local y01 = r(mean)
su re if treat==0 & year==1975
local y00 = r(mean)

local did = (`y11' - `y10') - (`y01' - `y00')
di "Difference-in-difference moment estimator: ", `did' //3621.2321

*(2) 回归DID
** 利用reg命令
reg re i.treat##i.post, vce(cl id)
** 利用xtreg命令
xtset id year
xtreg re D i.year, fe vce(cl id)

**时间安慰剂，利用时间数据，假设1975年为政策时点
*事前研究法和事前期趋势：直接回归
reg re i.treat##i.pre if inlist(year, 1974,1975), vce(cl id) //结果也是197.52，p值0.655，统计上不显著。事前满足平行趋势。

**事前研究法结果：合并回归
reg re i.treat##i.pre i.treat##i.post, vce(cl id)
*画出动态效应图
coefplot ,base keep(1.treat#1.pre 0.treat#0.post 1.treat#1.post) vertical yline(0) rename(1.treat#1.pre=pre 0.treat#0.post=current 1.treat#1.post=post) addplot(line @b @at, lp(dash))  ciopts(recast(rcap)) 


**引入协变量
xtreg re D i.year age c.(education - nodegree)#1.post, fe vce(cl id)

**引入交互项
local covs " education black hispanic married nodegree"

local s=""
foreach var of local covs {
	cap drop d`var'
	su `var' if treat == 1	
	gen d`var' = `var' - r(mean)
	local s="`s'"+" d`var'"
}
di "`s'" //检验产生的变量列表
*** 估计因果效应
xtreg re treat#1.pre treat#1.post 1.pre#c.(`covs') 1.post#c.(`covs') 1.treat#1.pre#c.(`s') 1.treat#1.post#c.(`s') i.pre i.post, fe vce(r)

*(3) PSM-DID
cap gen agesq=age*age
cap gen age3 = age^3
cap gen marriedre75=married*re75
cap gen agere74=age*re74 
cap gen nodegreeage=nodegree*age

*search pscore // 然后安装pscore包
cap drop id_nsw ps_nsw
pscore treat age education black hisp married re74 re75  ///
marriedre75 agere74 if year==1974, pscore(ps_nsw) blockid(id_nsw) ///
 comsup logit 

*手动PSM-DID
gen dre = re78 - re75
teffects nnmatch (dre age-nodegree)(treat) if year==1978, atet vce(r)
teffects psmatch (dre)(treat age education black hisp married re74 re75 marriedre75 agere74) if year==1978, atet vce(robust) //1078.541


*(4) 随机置换检验
use nsw_cps_panel, clear
reg re i.treat##i.post, vce(cluster id)
local att = _b[1.treat#1.post] 
permute treat beta=_b[1.treat#1.post], reps(1000) nodots noheader seed(134) saving(placebo, replace): reg re i.treat##i.post, vce(cluster id)
use placebo, clear
kdensity beta, xline(3522.47, lpattern(dash)) xtitle("beta") title("") note("") xlabel(-4000(1000)4000) 

*========================================================================
*Stata 官方命令
*========================================================================
** 经典DID命令：重复截面
use nsw_cps_panel, clear
didregress (re age-nodegree)(D), group(id) time(year)


*** omeans 调整平均结果，ltrends调整趋势图 line1opts是控制组，line2opts是干预组
estat trendplots 
*** 平行趋势检验
**** 线性趋势
estat ptrends
**** 非线性趋势
estat granger


** 面板数据
xtset id year
xtdidregress (re age-nodegree)(D), group(id) time(year)

** 异质性DID：
hdidregress twfe (re age-nodegree)(D), group(id) time(year)



