*Xiliang Zhao 2024.7.16
*modified in 2025.4.22

*使用模拟数据baler.dta

global data " " //修改为数据所在目录
cd "$data"

use baker, clear 
/*
* 1,000 firms (25 per state), 40 states, 4 groups (250 per groups), 30 years
* y2 常数效应
* y  时变效应
* id 企业id
* year 年份
* treat 干预状态D，1986， 1992， 1998， 2004 四个干预组，没有Never treated group
*/
*画出干预图
panelview y treat , i(id) t(year) type(treat) ylabdist(40)


*画出数据效应图
preserve
collapse (mean) y y2, by(year group)

* 常数效应：
two(sc y2 year if group==1, c(l))(sc y2 year if group==2, c(l))(sc y2 year if group==3, c(l))(sc y2 year if group==4, c(l)), legend(label(1 1986) label(2 1992) label(3 1998) label(4 2004)) xlabel(1980(2)2009) ytitle("y2") name(constant, replace)

*异质性效应
two(sc y year if group==1, c(l))(sc y year if group==2, c(l))(sc y year if group==3, c(l))(sc y year if group==4, c(l)), legend(label(1 1986) label(2 1992) label(3 1998) label(4 2004)) xlabel(1980(2)2009) ytitle("y") name(timevaring, replace)

restore


*========================================================================
*Brousyak et al. (2024) Imputation method
*Brousyak et al.(2024) 缺失值填补方法
*========================================================================

did_imputation y id year treat_date, autosample pre(17) h(0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17)
event_plot, graph_opt(xtitle("Periods since the event ") ytitle("Average causal effect") xlabel(-17(2)17) xline(0, lp(dash))) 

did_imputation y2 id year treat_date, autosample pre(17) h(0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17)
event_plot, graph_opt(xtitle("Periods since the event ") ytitle("Average causal effect") xlabel(-17(2)17) xline(0, lp(dash))) plottype(scatter)

*========================================================================
*Xu(2017) Generalized SCM or Counterfactual estimators
*========================================================================

*ssc install fect
fect y, treat(treat) unit(id) time(year) method("ife")
*要报告标准误，可以加上选项se，速度比较慢，
*fect y, treat(treat) unit(id) time(year) method("ife") se nboots(50)

*ATT估计结果显示
mat list e(ATT)
*动态效应：
mat list e(ATTs)

fect y2, treat(treat) unit(id) time(year) method("ife")
*ATT估计结果显示
mat list e(ATT)
*动态效应：
mat list e(ATTs)


*使用ife存在误设，
fect y, treat(treat) unit(id) time(year) method("fe") se
*要报告标准误，可以加上选项se，速度比较慢，
*fect y, treat(treat) unit(id) time(year) method("ife") se nboots(50)

*ATT估计结果显示
mat list e(ATT)
*动态效应：
mat list e(ATTs)

fect y2, treat(treat) unit(id) time(year) method("fe")
*ATT估计结果显示
mat list e(ATT)
*动态效应：
mat list e(ATTs) 

