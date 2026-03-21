*Xiliang Zhao, 2024/4/9, zhaoxiliang@gmail.com
*2024/7/17,7/22 更新，考虑增加职业的工具变量，教育的工具变量
*2018年CHIP城市数据

*mediate命令在Stata18中才能用
*========================================================================
global data " " //修改为数据所在目录
cd "$data"



***分析
**以职业为中介
use occup,clear
keep if edu>3 //仅保留高中及以上数据
local xs "age age2 male married i.prov"
mediate(linc `xs')(occup `xs')(college), all 
eststo m1

** 表2
esttab using res1.rtf, keep(NIE:r1vs0.college NDE:r1vs0.college PNIE:r1vs0.college TNDE:r1vs0.college TE:r1vs0.college) b(%5.3f) ci(%5.3f) replace
estat proportion

estat effectsplot


**中介用logit模型，估计结果基本不变
local xs "age age2 male married i.prov"
mediate(linc `xs')(occup `xs',logit)(college), all
estat proportion



*控制能力：用高考分数代替
local xs "c.age##c.age male married score_cee i.prov_cee i.year_cee i.prov"
mediate(linc `xs')(occup `xs')(college), all
eststo m2

** 表3
esttab using res2.rtf, keep(NIE:r1vs0.college NDE:r1vs0.college PNIE:r1vs0.college TNDE:r1vs0.college TE:r1vs0.college) b(%5.3f) ci(%5.3f) replace
estat proportion
estat effectsplot

*========================================================================
*工具变量回归：无交影响
*========================================================================
use occup,clear

*三阶段的工具变量法长程序
cap prog drop mediateiv
global xlist "age age2 male married i.prov "
program mediateiv, rclass
	tempname d_fit m_fit
	*first stage
	reg college seduc $xlist , vce(r)
	predict `d_fit', xb
	local F1=e(F)
	
	*second stage
	reg occup `d_fit' foccup moccup $xlist if e(sample),vce(r)
	local b1 = _b[`d_fit']
	local F2 = e(F)
	predict `m_fit', xb
	
	
	*third stage
	reg linc `d_fit' `m_fit' $xlist if e(sample), vce(r)
	local c1 = _b[`d_fit']
	local c2 = _b[`m_fit']
	return scalar nie = `b1' * `c2'
	return scalar nde = `c1'
	return scalar te = `c1' +  `b1' * `c2'
	return scalar pm = ( `b1' * `c2')/(`c1' + `b1' * `c2')
	return scalar F1 = `F1'
	return scalar F2 = `F2'
end
*估计效应
qui mediateiv
retu list

*用bootstrap得到估计量的标准误差
bootstrap nie = r(nie) nde = r(nde) te= r(te) , reps(50): mediateiv


*========================================================================
*工具变量回归——三阶段最小二乘法：有交互影响
*用配偶教育为作教育的工具，
*用父母职业作为职业的工具
*========================================================================

**允许DM交互影响
cap prog drop mediateiv2
global xlist "age age2 male married i.prov "
program mediateiv2, rclass
	tempname d_fit m_fit dm_fit
	*first stage
	reg college seduc $xlist, vce(r)
	predict `d_fit', xb
	
	*second stage
	reg occup `d_fit' foccup moccup $xlist if e(sample),vce(r)
	local b0 = _b[_cons]
	local b1 = _b[`d_fit']
	local b2_f= _b[foccup]
	local b2_m = _b[moccup]
	local b3_age = _b[age]
	local b3_age2=_b[age2]
	local b3_male=_b[male]
	local b3_married =_b[married]
	
	local provs "14  15 21 32 34 37  41 42 43  44 50 51 53 62 "
	local sumprov = 0
	 foreach prov of local provs {
	 	local b_`prov'=_b[i`prov'.prov]
		qui su i`prov'.prov if e(sample)
		local mprov`prov' = r(mean)
		local sumprov = `sumprov' + `b_`prov''*`mprov`prov''
	 }
	predict `m_fit', xb
	
	gen `dm_fit' = `d_fit'*`m_fit'
	
	*third stage
	reg linc `d_fit' `m_fit' `dm_fit' $xlist if e(sample), vce(r)
	local c1 = _b[`d_fit']
	local c2 = _b[`m_fit']
	local c3 = _b[`dm_fit']

*计算协变量和工具变量平均值
	local xs "foccup moccup age age2 male married"
	foreach x of local xs {
		qui su `x' if e(sample)
		local m`x' = r(mean)
	}
		

*计算目标参数：
	
	local nie0 = `b1' * `c2'
	local nie1 = `b1' * (`c2' + `c3')
	local nde0 = `c1' + `b0' * `c3' + `c3' * (`b2_f' * `mfoccup' +`b2_m' * `mmoccup' + `b3_age' * `mage' + `b3_age2' * `mage2' + `b3_male' * `mmale' + `b3_married' * `mmarried' + `sumprov')
	local nde1 = `c1' + (`b0' + `b1') * `c3' + `c3' * (`b2_f' * `mfoccup' +`b2_m' * `mmoccup' + `b3_age' * `mage' + `b3_age2' * `mage2' + `b3_male' * `mmale' + `b3_married' * `mmarried' + `sumprov')
	local te = `nie1' + `nde0'
	local pm0 = `nie0'/`te'
	local pm1 = `nie1'/`te'
	
	return scalar nie0 = `nie0'
	return scalar nie1 = `nie1'
	return scalar nde0 = `nde0'
	return scalar nde1 = `nde1'
	return scalar te = `te'
	return scalar pm0 = `pm0'
	return scalar pm1 = `pm1'
end

mediateiv2
return list

bootstrap nie0 = r(nie0) nie1 = r(nie1)  nde0 = r(nde0) nde1 = r(nde1) te= r(te), reps(50): mediateiv2

