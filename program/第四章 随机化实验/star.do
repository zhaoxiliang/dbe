*美国田纳西州班规模的随机化实验
/*
STAR项目是由美国田纳西州1980年代做的一项大型的随机化实验，实验持续4年，花费1200多万美元。实验对象主要是1985-1986学年进入幼儿园学习的孩子（5岁左右），一直持续到三年级。由于幼儿园阶段并不是必须参与的，因而，在第二年秋季还对一年级入学的孩子做了同样的随机分组，对这些孩子跟踪了3年。孩子在入学时（幼儿园或一年级），随机分配孩子进入三种班级，小班（13-17人），大班（22-25人）或大班加一个辅导老师。三种班级的随机化分配是在学校层面进行的，因而，要求参与的学校必须每种类型班级都能开出至少一个班级。学校每年级学生超过67人的才能开出至少三种班级。分配到小班的学生，就会一直在小班中学习，直到三年级结束。而在大班中学习的学生，在一年级时，又会在两种大班之间进行随机化分组（大班和大班加老师）。老师是在学校层面随机化分配到班级。参与的学校一共有80所，共有近11600名学生参与3年或4年的实验。关于STAR项目的详细说明，可以参考：
Krueger, Alan B. (1999), Experimental estimates of education production functions, Quarterly Journal of Economics, 114(2): 497-532. http://piketty.pse.ens.fr/files/Krueger1999.pdf

我们拿到了原始数据webstar.dta，我们将集中评价幼儿园阶段进入实验的孩子，进入小班学习（相对于大班）的学习效果。进行分析之前，首先要对数据进行适当的处理，将研究对象限制在stark==1的样本，本练习集中于分析班级规模对数学成绩（这里可以只讨论幼儿园时的成绩tmathssk，你也可以讨论其他年级时的成绩）的影响。另外，因众多研究表明，两种大班对孩子成绩影响几乎没有差别，因而，在分析中可以将两种类型的大班合并为一类。
*/

global data " " //修改为数据所在目录
cd "$data"


use star.dta, clear


*仅保留幼儿园开始参与的学生
keep if stark == 1

*合并大小班，产生小班的干预变量
gen treat = (cltypek == 1) if !missing(cltypek)

*主要的协变量
gen male = ssex == 1
gen white = inlist(srace, 1, 3) //白人和亚裔
gen free_lunch = sesk==1

*大小班特征差异和数学成绩
*ttable3 male white free_lunch tmathssk, by(treat) pvalue
tabstat male white free_lunch tmathssk, by(treat)
*分析：
*(1) FEP
ritest treat _b[treat], strata(schidkn) reps(100): reg tmathssk treat i.schidkn, vce(r)

*(2) Stratification
keep if !missing(tmathssk)
su treat 
local N = r(N) //总数
local N1 = r(sum) //记录干预组人数

local TATE = 0
local VATE = 0
local TATT = 0
local VATT = 0
levelsof schidkn, local(school)
foreach s of local school {
	su tmathssk if treat==1 & schidkn == `s'
	local ybar1 = r(mean)
	local nt = r(N)
	local st2 = r(Var)
	
	su tmathssk if treat ==0 & schidkn == `s'
	local ybar0 = r(mean)
	local nc = r(N)
	local sc2 = r(Var)

	local Ts = `ybar1' - `ybar0'
	local Vs = `sc2'/`nc' + `st2'/`nt'
	local w = (`nt' + `nc')/`N' //s层样本数占比
	local w1 = (`nt')/(`N1') // s层干预组样本占比
	
	local TATE = `TATE' + `w' * `Ts'
	local TATT = `TATT' + `w1' * `Ts'
	local VATE = `VATE' + (`w')^2 *`Vs'
	local VATT = `VATT' + (`w1')^2*`Vs'
}
di "Strata Estimate of ATE = ", `TATE'
di "Neyman S.E of sATE = ", sqrt(`VATE')
di "Strata Estimate of ATT = ", `TATT'
di "Neyman S.E of sATT = ", sqrt(`VATT')

*(3) Regression
eststo clear
eststo: reg tmathssk treat i.schidkn, vce(cl schidkn)
eststo: reg tmathssk treat i.schidkn male white free_lunch, vce(cl schidkn)

esttab est1 est2, b(%10.4f) se(%10.4f) mtitles("unadjusted" "adjusted")  ///
star(* .10 ** .05 *** .01) nogap ar2 keep(treat male white free_lunch)
