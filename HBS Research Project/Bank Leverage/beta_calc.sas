options nosource;
 
options source nocenter nodate noovp errors=3 mprint symbolgen macrogen;
 
Title1 CRSP DSF Extract for a Rolling regression run; 
Title2; 
 
%let start_year= 1990;
%let end_year=  2007;
%let sample_years=  2;
%let year1= %eval(&start_year-&sample_years);
** YEAR1 is set to make sure a full sample size is extracted;
 
* Results saved here;
libname mydir ';
%let final_ds=  mydir.betacalc;
 
 
*** End of program parameter section, nothing below should need to be changed ***;
 
 
* 1.  Create Daily Return dataset from DSF datafile (for selected permcos) and add Market index;
 
*Extract DSF items for each permco for the total required date range;
proc sql;
  create table dsfx1
  as select date, permco, ret
  from crsp.dsf
  where year(date) between &year1 and &end_year;
quit;
 
 
* Add CRSP Total Market Index-- VWRETD is Value weighted with dividends;
*  and Fama-French data items, plus compute excess return adjustments for Risk Free rate (RF);
*  MKTRF in F-F set should be a rounded version of VWRETD-RF;
 
proc sql;
 
  create table dsfx1
  as select a.*, b.vwretd
  from dsfx1 as a left join crsp.dsi as b
  on a.date=b.date;
 
  create table dsfx1
  as select a.*, b.mktrf, b.rf, (b.mktrf + b.rf) as mkt,
                 (a.ret-b.rf) as retrf, (a.vwretd-b.rf) as vwretdrf
  from dsfx1 as a left join ff.factors_daily as b
  on a.date=b.date
  order by a.permco, a.date;
 
quit;
 
* FYI --- SAS log warning about recursively references to a target table can be ignored;
 
* Printout to check data extract;
proc print data=dsfx1(obs=12); run;
 
 
 
* 2. Define Year-Month loop, YY MM macros variable used to count forward years and months;
 
%macro RRLOOP (year1= 2001, year2= 2005,  nyear= 2, in_ds=temp1, out_ds=work.out_ds);
 
%local date1 date2 date1f date2f yy mm;
 
*Extra step to be sure to start with clean, null datasets for appending;
proc datasets nolist lib=work;
  delete all_ds oreg_ds1;
run;
 
*Loop for years and months;
 %do yy = &year1 %to &year2;
   %do mm = 1 %to 12;
 
 *Set date2 for mm-yy end point and date1 as 24 months prior;
 %let xmonths= %eval(12 * &nyear); *Sample period length in months;
 %let date2=%sysfunc(mdy(&mm,1,&yy));
 %let date2= %sysfunc (intnx(month, &date2, 0,end)); *Make the DATE2 last day of the month;
 %let date1 = %sysfunc (intnx(month, &date2, -&xmonths+1, begin)); *set DATE1 as first (begin) day;
 *FYI --- INTNX quirk in SYSFUNC:  do not use quotes with 'month' 'end' and 'begin';
 
*An extra step to be sure the loop starts with a clean (empty) dataset for combining results;
proc datasets nolist lib=work;
  delete oreg_ds1;
run;
 
*Regression model estimation -- creates output set with coefficient estimates;
proc reg noprint data=&in_ds outest=oreg_ds1 edf;
  where date between &date1 and &date2;  *Restricted to DATE1- DATE2 data range in the loop;
  model retrf = vwretdrf;
  by permco;
run;
 
*Store DATE1 and DATE2 as dataset variables;
*  and rename regression coefficients as ALPHA and BETA;
data oreg_ds1;
  set oreg_ds1;
  date1=&date1;
  date2=&date2;
  rename intercept=alpha  vwretdrf=beta;
  nobs= _p_ + _edf_;
  format date1 date2 yymmdd10.;
run;
 
* Append loop results to dataset with all date1-date2 observations;
proc datasets lib=work;
  append base=all_ds data=oreg_ds1;
run;
 
 %end;  %* MM month loop;
 
 %end; %* YY year loop;
 
* Save results in final dataset;
data &out_ds;
  set all_ds;
run;
 
%mend RRLOOP;
 
 
* 3. Invoke the RRLOOP macro;
%RRLOOP (year1= &start_year, year2= &end_year,  nyear= &sample_years, in_ds=dsfx1, out_ds=&final_ds);
 
* 4. Check the results;
Title1 CAPM Beta Estimates-- Rolling regression results; 
 
*Sort and Print rolling-sample BETA estimates by permco;
proc sort data=&final_ds;
  by permco date2;
run;
 
proc print data=&final_ds;
  by permco;
  id permco date1 date2 _depvar_;
  var alpha beta;
  var _rmse_   _rsq_ nobs;
run;