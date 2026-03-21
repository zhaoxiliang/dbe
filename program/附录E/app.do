*Stata 数据处理编程
*赵西亮，2020年9月14日
*Modified in 2026.3.21
*========================================================================
global data " " //修改为数据所在目录
cd "$data"

/*
*========================================================================
参考资料：
https://stats.idre.ucla.edu/stata/

Baum, Christopher. An Introduction to Stata
Programming, Stata Press, 2nd edition, 2006.

Cameron, Colin and Trivedi, Pravin. 
Microeconomietrics Using Stata, 
Stata Press, 2010.

*========================================================================

第一节 常用命令

基本命令格式：
[prefix:] command [varlist][=exp][if]
[in][weight][using filename][,options]

常用的40个命令
Stata-Help-Pdf documents-User's Guide-Contents-28 Commands everyone should know
(1) 导入数据：import, odbc
help import
import excel hsb2.xls, sheet("hsb2") firstrow clear

insheet using \hsb2.csv, clear
Access数据导入
设置ODBC驱动程序
64位Stata需要先安装ODBC驱动
32位Stata不需要安装，直接打开C:\Windows\SysWOW64\odbcad32.exe 进行设置

在windows菜单搜索ODBC，找到设置的地方，进行下列操作：
ODBC-添加（或配置）-Microsoft Access Driver(*.mdb, *.accdb)-完成-Data Source Name（输入数据源名）-Database(Select)-OK

设置完成后，在Stata菜单或命令窗口进行导入odbc数据源即可。

odbc load, table("2003") clear

*利用工业库不同年份匹配的程序，参考Brandt et al.(2012) JDE:
https://feb.kuleuven.be/public/N07057/CHINA/appendix/

(2) 数据描述
describe
codebook
list
table
tabulate
summarize
tabstat
(3) 数据处理
append, merge
generate, replace
label var
label value

sysuse auto, clear
des foreign
label var foreign "产地"
tab foreign
label define fore 0 "国内" 1 "国外"
label value foreign fore
tab foreign

recode
rename
drop, keep
sort
encode, decode
reshape
duplicates report
duplicates drop


-----------
数据合并：纵向合并和横向合并
|A|, |B|
=>纵向append
|A|
|B|
=>横向merge
|A||B|

cd worldbank
*纵向合并
use gdp2016, clear
gen year = 2016
append using gdp2017
replace year = 2017 if missing(year)
save tmp1, replace
*横向合并
clear
use gdp2016
ren gdp_per_capita gdp_pc_2016
merge 1:1 countrycode using gdp2017
ren gdp_per_capita gdp_pc_2017
drop _merge
save tmp2, replace
*横向合并：两库不完全一致
use gdp2016
drop in 1/10
ren gdp_per_capita gdp_pc_2016
merge 1:1 countrycode using gdp2017
keep if _merge==3
drop if _merge == 2

drop _merge
*横向合并：多对一，一对多
use tmp1, clear
merge m:1 countrycode using mapping

use mapping, clear
merge 1:m countrycode using tmp1
*---------------------------------------
*长表与宽表
insheet using gdp-wide.csv,clear
reshape long gdp, i(countrycode) j(year)

keep if inlist(countrycode, "EMU", "WLD")
reshape wide gdp countryname, i(year) j(countrycode) string
line gdpEMU gdpWLD year
*(4) 缺失值处理

cd "$data"
use patient_pt1_stata_dm.dta, clear

*character vars
tab smokinghx, missing
tab familyhx, missing

*numeric variable
tab co2, missing

mvdecode _all, mv(-98 -99)
misstable summarize lungcapacity test1 test2
misstable patterns

*egen命令可以使用函数产生新的变量
gen average = (test1 + test2)/2
list test1 test2 average in 1/10
egen mean = rowmean(test1 test2)
list test1 test2 mean in 1/10
egen total = rowtotal(test1 test2)
list test1 test2 total in 1/10
misstable patterns test1 test2 average mean

*字符数据的处理：
*strtrim:去掉前后的空格
*substr：截取字符

tab hospital
replace hospital = strtrim(hospital)

tab docid
gen doc_id = substr(docid, 3, 3)
tab doc_id

encode hospital, gen(hos)
tab hos
tab hos, nol

*destring

*_n, _N
sysuse auto, clear
by foreign: gen n = _N
by foreign: gen id = _n
(4)画图
graph sc
kdensity




*第二节 do文件
*1.注释
*星号：第一种方式
// 这是第二种方式
/* */ 第三种方式
*/

clear // 清除数据
cap eststo clear

sysuse ///
auto, ///
clear

sysuse /*
*/ auto, clear

#delimit ;
sysuse auto, clear;
list in 1/5; sum;
#delimit cr

/*2.两种函数：
r(), e()
return list
ereturn list
*/
sysuse auto, clear
sum mpg
ret list

reg mpg weight price, vce(robust)
eret list
/*3.两种宏:
全局宏：global, $
局部宏：local, `'
*/
global xlist "price weight"
di "$xlist"

reg mpg $xlist

local xlist2 "price weight"
di "`xlist2'"
reg mpg `xlist2'

/*4.三种循环语句
foreach
forvalues
while
*/

clear
set obs 100
set seed 1234
gen x1 = runiform()
gen x2 = runiform()
gen x3 = runiform()
gen x4 = runiform()

su

*foreach
cap drop sum
gen sum = 0
foreach var of varlist x1 x2 x3 x4 {
  di "`var'  " `var'
  replace sum = sum + `var'
}
di "The sum of x1-x4 = " sum
list sum in 1/5

replace sum = 0
local xs "x1 x2 x3 x4"
foreach var of local xs {
  qui replace sum = sum + `var'
  }
  di "The sum of x1-x4 = " sum


*forvalues
replace sum = 0
forvalues i=1/4 {
  qui replace sum = sum + x`i'
}
di "The sum of x1-x4 = " sum

forvalues i = 1/10 {
  di "`i'"
  }
  

*while
replace sum = 0
local i = 1
while `i' <= 4 {
   qui replace sum = sum + x`i'
   local i = `i' + 1
   }
di "The sum of x1-x4 = " sum

sysuse auto, clear

local cov "weight price length"
foreach xs of local cov {
	reg mpg `xs'
}

/*第三节 结果呈现利器：estout软件包
Ben Jann: 
http://repec.sowi.unibe.ch/stata/estout/
esttab, estout, eststo, estadd, estpost
安装：
ssc install estout, replace
*/

sysuse auto, clear
eststo m1: qui reg mpg weight price, vce(robust)
eststo m2: qui reg mpg weight price foreign, vce(robust)
esttab m1 m2

esttab m1 m2 using result1.rtf, replace ///
b(%12.4f) se(%5.4f) ///
ar2(%12.4f) star(* .10 ** .05 *** .01) ///
mtitle("OLS1" "OLS2") nogap


*estadd
qui reg mpg weight price
estadd local Control = "No"
eststo m1

qui reg mpg weight price foreign
estadd local Control = "Yes"
eststo m2

esttab m1 m2,  b(%12.4f) se(%5.4f) ///
 ar2(%12.4f) star(* .10 ** .05 *** .01) ///
 mtitle("OLS1" "OLS2") ///
 stats(Control N r2_a, fmt(%3s %5.0f %5.4f))


esttab m1 m2 using result.rtf, replace ///
 b(%12.4f) se(%5.4f) ///
 ar2(%12.4f) star(* .10 ** .05 *** .01) ///
 mtitle("OLS1" "OLS2") ///
 stats(Control N r2_a, fmt(%3s %5.0f %5.4f))


 *estpost
 *estpost summarize
 estpost su mpg weight price foreign
 esttab ., cells("mean sd count") noobs nonumber ///
 nogap nomtitle
 *estpost tabstat
 estpost tabstat mpg weight price, by(foreign) ///
 s(mean sd) col(s)
 esttab ., main(mean) aux(sd) unstack noobs ///
 label nogap nonumber nomtitle
 

* Stata官方命令
sysuse "auto.dta", clear

*生成描述性统计表格
dtable price mpg rep78 trunk weight, nformat(%9.2f) 

* 生成估计结果表格
reg price mpg rep78 trunk weight, robust
est store m1

reg price mpg rep78 trunk weight length, robust
est store m2

reg price mpg rep78 trunk weight length turn, robust
est store m3

etable,                                ///
   estimates(m1 m2 m3) column(index)     ///
   keep(rep78 trunk weight length turn)  ///
   cstat(_r_b, nformat(%9.2f)) cstat(_r_se, nformat(%9.2f)) mstat(N) mstat(r2_a, nformat(%5.4f)) ///
   stars(0.10 "*" .05 "**" .01 "***") ///
   showstars showstarsnote ///
   export("result.docx",replace)
   
   
   

   


 
 
 
