*Matching LaLonde(1986)
*Modified by Xiliang Zhao 2024/6/17 2026/3/19
cap log close
set more off

global data " " //修改为数据所在目录
cd "$data"

**********************************
*DW(1999) nonexperimental data: CPS
**********************************
use nsw_dw, clear

drop if treat==0
append using cps_controls
gen u74 = (re74 == 0)
gen u75 = (re75 == 0)
gen agesq=age*age
gen age3 = age^3
gen marriedre75=married*re75
gen agere74=age*re74
gen nodegreeage=nodegree*age

save nsw_cps, replace

estpost tabstat age-re75 u74 u75,by(treat) s(mean sd) column(s) ///
 listwise // 利用~tabstat~进行分组简单统计
eststo sum // 结果保存到~sum~中
esttab sum, main(mean) aux(sd) unstack nonumber nomtitle ///
 nogap noobs
 // 将统计结果列到显示器上，
 //也可以用~using~选项将结果保存到文件中

 
 
**********************************
* 协变量匹配
**********************************
* 近邻匹配
use nsw_cps, clear
global xlist "age education black hispanic married nodegree re74 re75"
teffects nnmatch (re78 $xlist)(treat), atet gen(id) nn(1)
*注意到1：1匹配，其实最多会有9个匹配，里面因为倾向指数完全相同，出现ties时同时匹配，匹配上的结果会超过1个。


* 偏差调整
cap drop id*
teffects nnmatch (re78 age-re75)(treat), atet nn(1)  biasadj(age education re74 re75) ematch(black hispanic married ) gen(id)

*检测匹配效果
tebalance summarize

*可以限定卡尺
teffects nnmatch (re78 age-re75)(treat), atet nn(1) caliper(.5) biasadj(age education re74 re75) ematch(black hispanic married nodegree) os(ma)
* ma = 1表示不在共同区间上，即不在限定的卡尺范围内的，=0表示在共同区间内，即卡尺范围内的样本。只有在卡尺范围内样本估计。
teffects nnmatch (re78 age-re75)(treat) if ma==0, atet
tebalance summarize


 
**********************************
* 倾向得分匹配 
**********************************
teffects psmatch (re78)(treat age education black hisp married re74 re75 marriedre75 agere74, logit), atet nn(2)

tebalance summarize

* 共同区间图
teoverlap

********************************************************
*Double Machine Learning---telasso
********************************************************
use nsw_cps, clear
drop agesq - nodegreeage // 删除前面生成的二次变量和交互项，为下面用vl命令构造宏列表

*Stata 18 新命令
vl set // 产生4组宏变量列表vlcategorical, vlcontinuous, vluncertain, vlother

vl create cvars = vlcontinuous - (re78) 
//连续变量列表中删除结果变量re78

vl create fvars=vlcategorical - (treat) // 分类变量删除干预变量treat
vl sub allvars = c.cvars c.vluncertain i.fvars c.cvars#i.fvars c.vluncertain#i.fvars c.cvars#c.cvars c.vluncertain#c.vluncertain // 40个


*Double lasso估计因果效应: 线性模型
poregress re78 treat, controls($allvars)

*用Dobule ML估计因果效应：更一般模型，参见help 文件
telasso (re78 $allvars) (treat $allvars), atet

*Double machine learning
xporegress re78 treat, controls($allvars) xfolds(2)

/* 
************************************************************************
DDML包说明：https://statalasso.github.io/docs/ddml/plm/
*DDML包使用需要安装python（建议直接安装Anaconda）, 并正确设置位置，
*python query, https://www.bilibili.com/opus/995070938175242246
*查询是否设置python_userpath，设置pystacked包的位置，
*pystacked是其他机器学习算法包，可以用ssc install pystacked, replace安装
*需要安装python机器学习包, 在cmd窗口使用命令：pip install -U scikit-learn

* 系统配置建议：
在CMD命令窗口操作:
创造一个新环境，安装python3.10
conda create -n stata_py python=3.10 
conda activate stata_py
安装核心包：
conda install numpy pandas scikit-learn=1.2.2

在Stata中检验安装是否正确：
python
>>> import numpy
>>> import pandas
>>> import sklearn
end
如果没有报错，证明安装成功

在Stata命令窗口安装pystacked
ssc install pystacked
检验pystacked是否正常运行：
clear all
use https://statalasso.github.io/dta/cal_housing.dta, clear
set seed 42
gen train=runiform()
replace train=train<.75
set seed 42
pystacked medh longi-medi if train

如果不报错，说明正常



*注意事项：高版本python和scikit-learn包不兼容，在crossfit时会报错
*1. python版本建议3.8-3.10，推荐3.10版本
*2. scikit-learn建议1.2.2版本
*在CMD命令窗口：conda install python=3.10 scikit-learn=1.2.2

* 设置python程序和pystacked包的位置
*set python_exec "E:\miniconda3\envs\stata_py\python.exe", perm
*set python_userpath "H:\Program Files\Stata19\utilities"
************************************************************************
*/
/* DDML包用法：

先定义全局宏 Y, D, X

然后按下列步骤：
1. 初始化DDML模型，定义Cross-fitting 折数，通常用5折，模型类型有 partial iv interactive late fiv interactiveiv

ddml init partial, kfolds(2) // partial是模型类型，查帮助网页看所有模型类型

2. 加入机器学习算法Machine learners

ddml E[Y|X]: reg $Y $X // 最简单模型是线性回归
ddml E[D|X]: reg $Y $X
* 可以用其他机器学习方法，使用其他方法要用到pystacked包，ssc install安装后使用
比如，使用随机森林方法，可以定义如下：
ddml E[Y|X]: pystacked $Y $X, type(reg) method(rf)
ddml E[D|X]: pystacked $D $X, type(reg) method(rf)

设定好后，可以检验一下模型设定结果是否正确：
ddml desc

3. 交叉拟合Cross-fitting
ddml crossfit

4. 估计因果效应
ddml estimate, robust

*/


* 0. 定义变量
global Y re78
global D treat
global X $allvars

* 1. 初始化模型
ddml init partial, kfolds(2)
* 2. 设定学习模型
ddml E[Y|X]: reg $Y $X
ddml E[Y|X]: pystacked $Y $X, type(reg) method(rf)

ddml E[D|X]: reg $D $X
ddml E[D|X]: pystacked $D $X, type(reg) method(rf)

* 检验模型设定：
ddml describe

* 3. 进行交叉拟合
ddml crossfit, shortstack

* 4. 因果效应估计, 可以加allcombos（堆叠集成）
ddml estimate, robust

ddml estimate, robust allcombos



/*直接使用一行简化命令：qddml*/
*search qddml, 安装
qddml re78 treat ($allvars), kfolds(2) model(partial) cmd(pystacked) cmdopt(type(reg) method(rf))









