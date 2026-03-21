*美国职业培训随机化实验LaLonde(1986)数据

global data " " //修改为数据所在目录
cd "$data"


use "nsw_dw.dta", clear
tab treat // 干预分配情况
tabstat age - re75, by(treat) // 协变量平衡性情况


*分析
*(1) FEP
ritest treat _b[treat], reps(100): reg re78 treat, vce(r)
ritest treat _b[treat], reps(100): reg re78 treat age - re75, vce(r)

*(2) Neyman
su re78 if treat
local ybar1 = r(mean)
local nt = r(N)
local st2 = r(Var)

su re78 if treat ==0
local ybar0 = r(mean)
local nc = r(N)
local sc2 = r(Var)

local Tdif = `ybar1' - `ybar0'
local Vneyman = `sc2'/`nc' + `st2'/`nt'
local cil = `Tdif' - 1.96*sqrt(`Vneyman')
local cih = `Tdif' + 1.96*sqrt(`Vneyman')

di "Difference in callback rate: " `Tdif'
di "The variance of estimator V(Tdif): " `Vneyman'
di "The standard error of estimator se(Tdif):" sqrt(`Vneyman')
di "Confidence interval:  [`cil', `cih']" 

*(3) regression
eststo m1: regress re78 treat, vce(robust)
eststo m2: regress re78 treat, vce(hc2)
eststo m3: regress re78 treat age-re74,vce(robust)
eststo m4: regress re78 treat age-re74,vce(hc2)
esttab m1 m2 m3 m4, b(%10.4f) se(%10.4f) star(* .10 ** .05 *** .01) nogap ar2 mtitles(``unadjusted'' ``unadjusted−hc2'' ``adjusted'' ``adjusted−hc2'')




