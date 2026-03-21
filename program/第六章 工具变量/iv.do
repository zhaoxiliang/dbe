*===============================================================================
****Xiliang Zhao, 2016.11.24
****Modified in 2020.05.10
****Modified in 2024.6.30
****Modified in 2025.4.21
****Modified in 2026.3.21
*===============================================================================
global data " " //修改为数据所在目录
cd "$data"

set more off

use angrist, clear
set seed 2024
*sample 10 //利用全样本注消该句

gen region = (ENOCENT==1) + (ESOCENT==1)*2 + (MIDATL==1)*3 + (MT==1)*4 + (NEWENG==1)*5 + (SOATL==1)*6 + (WNOCENT==1)*7 + (WSOCENT==1)*8

preserve
g year = YOB + QOB*1/4-1/4 
collapse (mean) EDUC LWKLYWGE,by(year)
*two con EDUC year, xtitle("出生季度") ytitle("教育年限") saving(educ, replace)
two (sc EDUC year if year-int(year)<0.5, xtitle("出生季度") ytitle("教育年限") m(S))(sc EDUC year if year-int(year)>=0.5, xtitle("出生季度", margin(t=2)) ytitle("教育年限", margin(t=2)) m(Sh))(line EDUC year), legend(order(1 "1、2 季度" 2 "3、4 季度") pos(11) ring(0) cols(1) region(lstyle(none))) saving(educ,replace) 

*two con LWKLYWGE year, xtitle("出生季度") ytitle("对数周工资") saving(lwage,replace)
two (sc LWKLYWGE year if year-int(year)<0.5, xtitle("出生季度") ytitle("对数周工资") m(S))(sc LWKLYWGE year if year-int(year)>=0.5, xtitle("出生季度", margin(t=2)) ytitle("对数周工资", margin(t=2)) m(Sh))(line LWKLYWGE year), legend(order(1 "1、2 季度" 2 "3、4 季度") pos(11) ring(0) cols(1) region(lstyle(none))) ylabel(5.87(0.01)5.93) xlabel(30(1)40) saving(lwage,replace) 
restore

*===============================================================================
*****IV回归
*===============================================================================
*1. OLS回归：教育回归6.39%
reg LWKLYWGE EDUC RACE MARRIED SMSA  YR21 - YR29  NEWENG MIDATL ENOCENT WNOCENT SOATL ESOCENT WSOCENT MT, vce(robust)
*2. IV回归：用2、3、4季度作为工具，教育回报9.79%, 官方命令
ivregress 2sls LWKLYWGE (EDUC=QTR1 - QTR3 )  RACE MARRIED SMSA YR21 - YR29 NEWENG MIDATL ENOCENT WNOCENT SOATL ESOCENT WSOCENT MT, vce(robust) first

*(1) 检验内生性：p=0.098 marginal reject H0，内生
estat endog
*(2) 检验弱工具：第1阶段F值=30.502>22.3，拒绝弱工具假设
estat first
*(3) 过度识别检验：p=0.33 不能拒绝原假设E[Ze]=0
estat overid

*(4) Stata19提供，弱式具有效的检验
estat weakrobust


*可以用liml方法，它是弱工具稳健的
ivregress liml LWKLYWGE (EDUC=i.QOB) RACE SMSA i.YOB i.region, vce(robust) first

*3. IV回归: ivreg2
ivreg2 LWKLYWGE (EDUC=QTR1 - QTR3 )  RACE MARRIED SMSA YR21 - YR29 NEWENG MIDATL ENOCENT WNOCENT SOATL ESOCENT WSOCENT MT, robust
*弱工具检验（异方差稳健的统计量）, Stock(2018)建议报告Effective F值，用weakivtest
weakivtest
/*得到的教育回报9.79%，还报告了下列检验结果：

检验第1阶段系数为零：
Underidentification test (Kleibergen-Paap rk LM statistic):             91.471
                                                   Chi-sq(3) P-val =    0.0000
------------------------------------------------------------------------------
弱工具检验（异方差稳健的统计量）, Stock(2018)建议报告Effective F值，用weakivtest
Weak identification test (Kleibergen-Paap rk Wald F statistic):         30.502
Stock-Yogo weak ID test critical values:  5% maximal IV relative bias    13.91
                                         10% maximal IV relative bias     9.08
                                         20% maximal IV relative bias     6.46
                                         30% maximal IV relative bias     5.39
                                         10% maximal IV size             22.30
                                         15% maximal IV size             12.83
                                         20% maximal IV size              9.54
                                         25% maximal IV size              7.80
Source: Stock-Yogo (2005).  Reproduced by permission.
NB: Critical values are for Cragg-Donald F statistic and i.i.d. errors.
------------------------------------------------------------------------------
过度识别检验：
Hansen J statistic (overidentification test of all instruments):         2.207
                                                   Chi-sq(2) P-val =    0.3317
------------------------------------------------------------------------------
*/
*4. IV：ivreghdfe 在ivreg2基础上加了吸收高维协变量的选项
ivreghdfe LWKLYWGE (EDUC=QTR1 - QTR3 ) RACE SMSA , robust absorb(i.YOB i.region)

*===============================================================================
* DML
*===============================================================================
use angrist, clear
** 0. 定义变量
global Y "LWKLYWGE"
global D "EDUC"
global Z "QTR1 QTR2 QTR3"
global X "RACE MARRIED SMSA NEWENG MIDATL ENOCENT WNOCENT SOATL ESOCENT WSOCENT MT YR20 YR21 YR22 YR23 YR24 YR25 YR26 YR27 YR28"

** 1. 初始化模型
ddml init iv, kfolds(2)

** 2. 设定ML模型
ddml E[Y|X]: reg $Y $X
ddml E[Y|X]: pystacked $Y $X, type(reg) method(rf)
ddml E[D|X]: reg $D $X
ddml E[D|X]: pystacked $D $X, type(reg) method(rf)
ddml E[Z|X]: reg $Z $X
ddml E[Z|X]: pystacked $Z $X, type(reg) method(rf)

** 3. 进行交叉拟合
ddml crossfit, shortstack

** 4. 估计因果效应
ddml estimate, robust
 
 
 

log close
set more on
exit



