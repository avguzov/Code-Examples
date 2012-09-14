/* -------------------------------------------------------------------- */
/*
/* Program name: ff.sas
/*
/* This program has two objectives:
/*
/* 1. The program pulls together on dividend policy from the CRSP data alone.
/*
/*    a. Quarterly dividends per share in the quarter
/*    b. Splits in the quarter
/*    c. Quarter end share price
/*    d. Quarter end shares outstanding
/*    e. Dividend announcement date
/*    f. Dividend announcement return (3-day market adjusted)
/*    g. Permno
/*    h. SIC
/*    i. Company Name
/*    j. Quarter
/*
/* -------------------------------------------------------------------- */

OPTIONS MPRINT NODATE NOCENTER NONUMBER PS=MAX LS=MAX;

LIBNAME output '/sastemp1/mbaker';

/* Look at databases */

*PROC CONTENTS DATA=crsp.msf; RUN;
*PROC PRINT DATA=crsp.msf(OBS=100); RUN;
*PROC CONTENTS DATA=crsp.mse; RUN;
*PROC PRINT DATA=crsp.mse(OBS=100); RUN;
*PROC CONTENTS DATA=crsp.dsf; RUN;
*PROC PRINT DATA=crsp.dsf(OBS=100); RUN;

*PROC CONTENTS DATA=comp.g_secd; RUN;
*PROC PRINT DATA=comp.g_secd(OBS=100); RUN;


/* -------------------------------------------------------------------- */
/*
/* Get CRSP dividend data
/*
/* -------------------------------------------------------------------- */

* Get price and split data - COULD BE AN ALIGNMENT PROBLEM HERE WITH SPLITS AND DIVIDENDS / COULD USE CFACPR INSTEAD OF CFACSHR ;

DATA msf;
	SET crsp.msf;
	KEEP PERMNO DATE PRC CFACPR CFACSHR SHROUT;
RUN;

PROC SORT NODUPKEY;
	BY PERMNO DATE;

* Get dividend data ;

DATA mse;
	SET crsp.mse;
	KEEP PERMNO DATE EVENT COMNAM SICCD SHRCD DCLRDT DISTCD RCRDDT DIVAMT;
RUN;

DATA names;
	SET mse;
	IF EVENT="NAMES";
	KEEP PERMNO DATE COMNAM SICCD SHRCD;
RUN;

DATA dist;
	SET mse;
	IF EVENT="DIST" AND INT(DISTCD/100)=12 AND DISTCD-INT(DISTCD/10)*10=2 AND DCLRDT~=. AND DIVAMT~=.;
	KEEP PERMNO DATE DCLRDT RCRDDT DIVAMT DISTCD;
RUN;

PROC SORT DATA=dist;
	BY PERMNO DCLRDT DISTCD DIVAMT;

DATA dist;
	SET dist;
	BY PERMNO DCLRDT DISTCD DIVAMT;
	IF LAST.DISTCD;
RUN;

* Get announcement return data ;

PROC SQL;
	CREATE TABLE annret1 AS
	SELECT A.PERMNO, A.DISTCD, A.DCLRDT, B.DATE, B.RET, B.PRC
	FROM dist A, crsp.dsf B
	WHERE A.PERMNO=B.PERMNO AND B.DATE-10<=A.DCLRDT<=B.DATE+10;

PROC SQL;
	CREATE TABLE annret AS
	SELECT A.PERMNO, A.DISTCD, A.DCLRDT, A.DATE, A.RET, A.PRC, B.VWRETD
	FROM annret1 A, crsp.dsi B
	WHERE A.DATE=B.DATE;

PROC SORT DATA=annret;
	BY PERMNO DISTCD DCLRDT DATE;

DATA annret;
	SET annret;
	BY PERMNO DISTCD DCLRDT DATE;
	RETAIN RELATIVE1;
	IF FIRST.DCLRDT THEN RELATIVE1 = .;
	IF DATE>=DCLRDT AND RELATIVE1=. THEN RELATIVE1 = 0;
	ELSE RELATIVE1 = RELATIVE1 + 1;
RUN;

PROC SORT DATA=annret;
	BY PERMNO DISTCD DCLRDT DESCENDING DATE;

DATA annret (DROP=RELATIVE1);
	SET annret;
	BY PERMNO DISTCD DCLRDT DESCENDING DATE;
	RETAIN RELATIVE;
	IF RELATIVE1~=. THEN RELATIVE = RELATIVE1;
	ELSE RELATIVE = RELATIVE - 1;
RUN;

DATA lagprice (KEEP=PERMNO DISTCD DCLRDT LAGPRC);
	SET annret;
	IF RELATIVE=-2;
	LAGPRC = PRC;
RUN;

DATA annret;
	SET annret;
	IF RELATIVE>=-1 AND RELATIVE<=+1;
RUN;

DATA annret;
	SET annret;
	BY PERMNO DISTCD DCLRDT DESCENDING DATE;
	RETAIN CRET CNT;
	IF FIRST.DCLRDT THEN DO; 
		CRET = 0;
		CNT = 0;
	END;
	CRET = CRET + RET - VWRETD;
	CNT = CNT + 1;
RUN;

DATA annret (KEEP=PERMNO DISTCD DCLRDT CRET);
	SET annret;
	BY PERMNO DISTCD DCLRDT DESCENDING DATE;
	IF LAST.DCLRDT;
	IF CNT = 3;
RUN;

DATA annret;
	MERGE annret lagprice;
	BY PERMNO DISTCD DCLRDT;
RUN;

* Get abnormal volume data ;

PROC SQL;
	CREATE TABLE annvol AS
	SELECT A.PERMNO, A.DISTCD, A.DCLRDT, B.DATE, B.VOL, B.CFACSHR
	FROM dist A, crsp.dsf B
	WHERE A.PERMNO=B.PERMNO AND B.DATE-10<=A.DCLRDT<=B.DATE+90;

PROC SORT DATA=annvol;
	BY PERMNO DISTCD DCLRDT DATE;

DATA annvol;
	SET annvol;
	BY PERMNO DISTCD DCLRDT DATE;
	RETAIN NORMVOL CNT DVOL DCNT;
	IF FIRST.DCLRDT THEN DO;
		NORMVOL = 0;
		CNT = 0;
		DVOL = 0;
		DCNT = 0;
	END;
	IF DATE<DCLRDT THEN DO;
		NORMVOL = NORMVOL + VOL*CFACSHR;
		CNT = CNT + 1;
	END;
	IF DATE>=DCLRDT THEN DO;
		DVOL = DVOL + VOL*CFACSHR;
		DCNT = DCNT + 1;
	END;
RUN;

DATA annvol(KEEP=PERMNO DISTCD DCLRDT ABVOL DCNT NORM CNT);
	SET annvol;
	IF DCNT=3;
	ABVOL = DVOL/DCNT;
	IF CNT>0 THEN NORM = NORMVOL/CNT;
RUN;

* Assemble data on announcement returns, dividends, and abnormal volume ;

PROC SORT DATA=annret;
	BY PERMNO DISTCD DCLRDT;
PROC SORT DATA=annvol;
	BY PERMNO DISTCD DCLRDT;
PROC SORT DATA=dist;
	BY PERMNO DISTCD DCLRDT;

DATA dist;
	MERGE annret annvol dist;
	BY PERMNO DISTCD DCLRDT;
RUN;

* Assemble header information ;

PROC SQL;
	CREATE TABLE div1 AS
	SELECT A.PERMNO, A.DATE, A.PRC, A.CFACPR, A.CFACSHR, A.SHROUT, B.COMNAM, B.SICCD, B.SHRCD
	FROM msf A, names B
	WHERE A.PERMNO=B.PERMNO AND YEAR(A.DATE)*100+MONTH(A.DATE)=YEAR(B.DATE)*100+MONTH(B.DATE);

PROC SORT DATA=div1;
	BY PERMNO DATE;
	
DATA div1;
	SET div1;
	BY PERMNO DATE;
	IF last.DATE;
RUN;

PROC SQL;
	CREATE TABLE div2 AS
	SELECT A.PERMNO, A.DATE, A.PRC, A.CFACPR, A.CFACSHR, A.SHROUT, B.DCLRDT, B.RCRDDT, B.DIVAMT, B.DISTCD, B.CRET, B.LAGPRC, B.ABVOL, B.NORM, B.DCNT, B.CNT
	FROM msf A, dist B
	WHERE A.PERMNO=B.PERMNO AND YEAR(A.DATE)*100+MONTH(A.DATE)=YEAR(B.DATE)*100+MONTH(B.DATE);

PROC SORT DATA=msf;
	BY PERMNO DATE;
PROC SORT DATA=div1;
	BY PERMNO DATE;
PROC SORT DATA=div2;
	BY PERMNO DATE;

DATA dividend;
	MERGE msf div1 div2;
	BY PERMNO DATE;
RUN;

PROC SORT DATA=dividend;
	BY PERMNO DATE;
RUN;

DATA dividend (DROP=COMNAM SICCD SHRCD);
	SET dividend;
	BY PERMNO DATE;
	RETAIN COMNAME SIC SHR;
	IF FIRST.PERMNO THEN DO;
		COMNAME = "                                      ";
		SIC = .;
		SHR = .;
	END;
	IF COMNAM~="" THEN COMNAME = COMNAM;
	IF SICCD~=. THEN SIC = SICCD;
	IF SHRCD~=. THEN SHR = SHRCD;
RUN;

DATA dividend;
	SET dividend;
	BY PERMNO DATE;
	IF DIVAMT~=. OR LAST.PERMNO;
RUN;

PROC PRINT DATA=dividend(OBS=100);

DATA output.dividend;
	SET dividend;
RUN;


