*！Xiliang Zhao, 2024.7.27 
*Modified in 2024.4.22, 2026.3.21
*改变下列路径为数据所在的目录
global data " " //修改为数据所在目录
cd "$data"
*========================================================================
use cgvo,clear
xtset village_id year

* 事件研究法模型
xtreg l_poor_reg_rate Lead_D4_plus Lead_D3 Lead_D2 D0 Lag_D1 Lag_D2 Lag_D3_plus i.year, fe vce(cl village_id)  level(90)

** 平行趋势检验
test Lead_D4_plus Lead_D3 Lead_D2


**动态效应图
coefplot, drop(*.year _cons) vertical yline(0,lp(dash)) xline(3.5, lp(dash)) level(90) ciopts(recast(rcap)) xlab(1 "≤ -4" 2 "-3" 3 "-2" 4 "0" 5 "1" 6 "2" 7 "≥ 3", labsize(medsmall) labcolor(black) axis(1))  xtitle("") ytitle("Estimated Coefficients")  scheme(s1mono)



** 保存系数和协方差矩阵
matrix sigma = e(V)
matrix beta = e(b)
matrix beta = beta[., 1..7]
matrix sigma = sigma[1..7, 1..7]


** 统计功效检验
pretrends, numpre(3) b(beta) v(sigma) slope(.03) level(90)

return list

** 敏感性分析：事后一期效应
** 相对幅度标准(rm)
matrix l_vec = 0 \ 1 \ 0 \ 0 
local plotopts xtitle(Mbar) ytitle(90% Robust CI)
honestdid, l_vec(l_vec) pre(1/3) post(4/7) mvec(0.5(0.5)2)  coefplot `plotopts' alpha(.1) 

** 平滑幅度标准
honestdid, l_vec(l_vec) pre(1/3) post(4/7) mvec(0(.1).5) coefplot `plotopts' alpha(.1) delta(sd)


