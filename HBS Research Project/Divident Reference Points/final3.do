******************************************************************************;
*
* final3.do
* Alexander Guzov
*
* When this program is run from the user's HBS Research Grid directory, it 
* produces the figures from Professor Baker and Professor Wurgler's paper
* "Dividends as Reference Points: A Behavioral Signaling Model".  The figures
* are named according to where they appear in the paper's appendix.
*
******************************************************************************;

**********************************************;
* Specify the source dataset's pathname
**********************************************;

log using final3m.log, replace

set mem 3g 

use /export/home/local/aguzov_temp/dsfevents, clear

sort permno date
gen year = year(date)
gen month = month(date)
gen day = day(date)

replace divamt = (round(divamt*1000))/1000
drop if divamt<0

sort permno date
drop divdiff
gen divdiff = divamt-divamt[_n-1] if (permno==permno[_n-2]&cfacpr==cfacpr[_n-2])& ///
	((year==year[_n-1]&(month==month[_n-1]+3))|(year==(year[_n-1]+1)&(month==(month[_n-1]-9))))

sort permno date	
gen simple_divdiff = divamt-divamt[_n-1] if permno==permno[_n-2]

drop if ret_lag1==. | ret_lead1==. | ret==.	| vwretd_lag1==. | vwretd_lead1==. | vwretd==.

gen abnorm_ret = (ret_lag1 - vwretd_lag1) + (ret-vwretd) + (ret_lead1-vwretd_lead1)
drop if abnorm_ret==.

sort permno date


gen thresh1_divdiff = divamt - ((int(divamt[_n-1]*10))/10)+.1 ///
	if (permno==permno[_n-2]&cfacpr==cfacpr[_n-2])& ///
	((year==year[_n-1]&(month==month[_n-1]+3))|(year==(year[_n-1]+1)&(month==(month[_n-1]-9))))
gen thresh05_divdiff = divamt - ((int(divamt[_n-1]*20))/20)+.05 ///
	if (permno==permno[_n-2]&cfacpr==cfacpr[_n-2])& ///
	((year==year[_n-1]&(month==month[_n-1]+3))|(year==(year[_n-1]+1)&(month==(month[_n-1]-9))))
gen thresh025_divdiff = divamt - ((int(divamt[_n-1]*40))/40)+.025 ///
	if (permno==permno[_n-2]&cfacpr==cfacpr[_n-2])& ///
	((year==year[_n-1]&(month==month[_n-1]+3))|(year==(year[_n-1]+1)&(month==(month[_n-1]-9))))


sort permno date
gen newdiv = round(mod((divamt*10),1),.01)/10

sort permno date
	
gen chg=(simple_divdiff~=0)
sort permno date
bys permno: gen obsnum=_n
sort permno date
bys permno: gen regime=sum(chg)
egen firstobs=min(obsnum),by(permno regime)
gen streaktemp=obsnum-firstobs+1
sort permno date
replace streak=streaktemp[_n-1] if permno==permno[_n-1]
drop firstobs chg

preserve
replace abnorm_ret=. if divdiff==.
tabstat divamt newdiv divdiff thresh1_divdiff thresh05_divdiff thresh025_divdiff streak abnorm_ret, ///
	columns(statistics) stats(count mean med sd p5 p25 p75 p95)
restore

reg abnorm_ret divdiff, r

preserve
keep if divdiff~=. & abnorm_ret~=.
gen divdiff_n02 = min(divdiff,-0.2)
gen divdiff_n01 = min(-0.1-(-0.2),max(divdiff-(-0.2),0)) 
gen divdiff_n005 = min(-0.05-(-0.1),max(divdiff-(-0.1),0)) 
gen divdiff_n0025 = min(-0.025-(-0.05),max(divdiff-(-0.05),0)) 
gen divdiff_00 = min(0-(-0.025),max(divdiff-(-0.025),0)) 
gen divdiff_0025 = min(0.025,max(divdiff,0)) 
gen divdiff_005 = min(0.05-0.025,max(divdiff-0.025,0)) 
gen divdiff_01 = min(0.1-0.05,max(divdiff-0.05,0)) 
gen divdiff_02 = min(0.2-0.1,max(divdiff-0.1,0)) 
gen divdiff_02p = max(divdiff-0.2,0)
reg abnorm_ret divdiff_*, r
test -divdiff_00-divdiff_n0025-divdiff_n005 = divdiff_0025+divdiff_005+divdiff_01
predict abnorm_rethat
sort divdiff
graph twoway line abnorm_rethat divdiff if abs(divdiff)<=0.201, xline(0) yline(0)
restore

log close

/*
**************************************************************;
* Produces a histogram of the dividend payment per share and
* a histogram of the second and third decimal in dividends
* per share
**************************************************************;

histogram divamt, discrete xlabel(0(.05)2,grid) saving(4a,replace) title("4A")

histogram newdiv, discrete xlabel(0(.05)1,grid) saving(4b, replace) title("4B")

*************************************************************;
* Produces histograms relating to changes in dividends per
* share.
*************************************************************;

histogram divdiff, discrete saving(5a,replace) title("5A")
histogram divdiff if divdiff !=0, discrete saving(5b, replace) title("5B")
histogram divdiff if divdiff >0, discrete saving(5c, replace) title("5C")
histogram divdiff if divdiff <0, discrete saving(5d, replace) title("5D")

**************************************************************;
* Produces histograms relating to reaching thresholds in
* dividends per share.
**************************************************************;

histogram divdiff if mod(round(divdiff,.001),.1)==0, discrete saving(6a,replace) title("6A")
histogram divdiff if mod(round(divdiff,.001),.05)==0, discrete saving(6b,replace) title("6B")
histogram divdiff if mod(round(divdiff,.0001),.025)==0, discrete saving(6c,replace) title("6C")
histogram divdiff if mod(round(divdiff,.001),.1)==0 	///
				  & mod(round(divamt,.0001),.025)==0, ///
				  discrete saving(6d,replace) title("6D")
				  
histogram divdiff if mod(round(divdiff,.001),.05)==0 	///
				  & mod(round(divamt,.0001),.025)==0, ///
				  discrete saving(6e,replace) title("6E")
				  
histogram divdiff if mod(round(divdiff,.0001),.025)==0 	///
				  & mod(round(divamt,.0001),.025)==0, ///
				  discrete saving(6f,replace) title("6F")

*************************************************************
* Produces line graphs relating 3-day abnormal return to
* changes in dividends per share, grouping dividend changes
* to the nearest .05 and .025.
*************************************************************

gen divdiff_rd05 = .05 * floor(round(divdiff,.01)/.05)
by divdiff_rd05, sort: egen abnorm_retm05 = mean(abnorm_ret)
graph twoway line abnorm_retm05 divdiff_rd05, saving(7a, replace) title("7A")

gen divdiff_rd025 = .025 * floor(round(divdiff,.01)/.025)
by divdiff_rd025, sort: egen abnorm_retm025 = mean(abnorm_ret)
graph twoway line abnorm_retm025 divdiff_rd025, saving(7b, replace) title("7B")

*************************************************************
* Produces line graphs relating 3-day abnormal return to 
* threshold changes in dividends per share, looking at
* thresholds of .1, .05, and .025.
*************************************************************


gen divdiff_thresh1rd025 = .025 * floor(round(divdiff_thresh1,.01)/.025)
by divdiff_thresh1rd025, sort: egen abnorm_1ret025 = mean(abnorm_ret)
graph twoway line abnorm_1ret025 divdiff_thresh1rd025, saving(8a, replace) title("8A")


gen divdiff_thresh05rd025 = .025 * floor(round(divdiff_thresh05,.01)/.025)
by divdiff_thresh05rd025, sort: egen abnorm_05ret025 = mean(abnorm_ret)
graph twoway line abnorm_05ret025 divdiff_thresh05rd025, saving(8b, replace) title("8B")


gen divdiff_thresh025rd025 = .025 * floor(round(divdiff_thresh025,.01)/.025)
by divdiff_thresh025rd025, sort: egen abnorm_025ret025 = mean(abnorm_ret)
graph twoway line abnorm_025ret025 divdiff_thresh025rd025, saving(8c, replace) title("8C")

*************************************************************
* Produces a line graph that plots 3-day abnormal returns by
* changes in dividends per share, grouping dividend payments
* by previous streaks of identical dividend payments, with
* the groups being streaks of 0, less than 5, and greater
* than 4.
*************************************************************

gen streak_group = 0 if streak_lag1==0
replace streak_group = 1 if (0<streak_lag1 & streak_lag1 <= 4)
replace streak_group = 2 if streak_lag1 > 4
by divdiff_rd05 streak_group, sort: egen abnorm_retm05s = median(abnorm_ret)
twoway (line abnorm_retm05s divdiff_rd05 if streak_group==0) ///
	   (line abnorm_retm05s divdiff_rd05 if streak_group==1) ///
	   (line abnorm_retm05s divdiff_rd05 if streak_group==2), saving(10, replace) title("10")

**************************************************************
* Produces a CSV file with clustering percentages and 
* number of observations by streak, which can be opened in
* Excel to create the needed line graphs.
**************************************************************

sort permno date
gen streak_lead1 = streak[_n+1]
by permno date: gen contstreak = (streak+1 == streak_lead1)
preserve
collapse (mean) clusterfract=contstreak (count) streakobs=permno, by(streak)
outsheet streak clusterfract streakobs using /export/home/local/aguzov_temp/figure9.csv,comma

exit,clear