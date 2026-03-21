*************************************************************************
* name: baker.do
* author: scott cunningham (baylor) adapting andrew baker (stanford)
* description: illustrate TWFE with differential timing and
*              heterogenous treatment effects over time
* last updated: jan 5, 2022
* modified by Xiliang Zhao, 2024.7.11, 2026.3.21
*************************************************************************
global data " " //修改为数据所在目录
cd "$data"

use baker, clear

*ssc install panelview
panelview y treat,i(id) t(year) type(treat) ylabdist(50) legend(pos(6) ring(1))  name(str, replace) 

*画出数据效应图
preserve
collapse (mean) y y2, by(year group)

* 常数效应：
two(sc y2 year if group==1, c(l) ms(S) mc(gs0))(sc y2 year if group==2, c(l) ms(D) mc(gs5))(sc y2 year if group==3, c(l) ms(O) mc(gs9))(sc y2 year if group==4, c(l) ms(T) mc(gs10)), legend(label(1 1986) label(2 1992) label(3 1998) label(4 2004) pos(11) ring(0) col(2)) xlabel(1980(2)2009, nogrid angle(45))

graph save y2.gph, replace

*异质性效应
two(sc y year if group==1, c(l) ms(S) mc(gs0))(sc y year if group==2, c(l) ms(D) mc(gs5))(sc y year if group==3, c(l) ms(O) mc(gs9))(sc y year if group==4, c(l) ms(T) mc(gs10)), legend(label(1 1986) label(2 1992) label(3 1998) label(4 2004) pos(11) ring(0) col(2)) xlabel(1980(2)2009, nogrid angle(45)) 
gr save y.gph, replace

gr combine y.gph y2.gph, ysize(3) xsize(8)
restore

*************************************************************************
** 经典面板方法
*************************************************************************
xtset id year
** 常数效应下，TWFE可以正确的估计出效应，平均效应ATT
xtreg y2 treat i.year, fe vce(cl id)
** 异质性效应情况下，尽管对于每组的效应都为正值，但TWFE估计出的为负值。
xtreg y treat i.year, fe vce(cl id)


** Bacon decomposition shows the problem -- notice all those late to early 2x2s!
*ssc install bacondecomp
bacondecomp y treat, ddetail

*Stata官方分解命令，用在didregress或xtdidregress之后，官方命令需要有从未干预组，删除2004年才接受干预的组，即以2004年作为从未干预组。

drop if year>=2004

xtdidregress (y )(treat), group(id) time(year) 

** Goodman-Bacon分解
estat bdecomp

*************************************************************************
*异质性DID
*官方命令hdidregress,xthdidregress
*************************************************************************
use baker, clear
xtset id year
xthdidregress twfe (y)(treat),group(id)  controlgroup(notyet)

**事件研究法系数图
estat atetplot, xlabel(, nogrid) ylabel(, nogrid)  xtitle("Time", margin(t=2)) ytitle("ATT") plotregion(style(none))

**加总估计量
estat aggregation
estat aggregation, cohort
estat aggregation, time
estat aggregation, dynamic graph



