LIBNAME hw1 'C:\Users\msg170330\Desktop';
dm 'clear log'; dm 'clear output';  /* clear log and output */

libname vehicles "C:\Users\msg170330\Desktop";
title;
proc import out= work.vehicles3 
datafile= "C:\Users\msg170330\Desktop\vehicles.csv" 
dbms=csv replace;
     getnames = yes;
     datarow=2; 
run;
proc contents data=work.vehicles3;
run;
proc sql;
	create table vehicles as select * from work.vehicles3;
	run;
	quit;
DATA data3(DROP = url region_url vin county description id image_url lat long description region model size); 
	SET work.vehicles3;
RUN;
/*Frequency*/
proc freq data = data3;
	tables fuel title_status transmission manufacturer condition cylinders drive type paint_color /missing;
run;
/*Corellation metrix*/
proc corr data=data3;
run;
proc corr data=data3 pearson spearman;


title 'Example correlation calculations using PROC CORR';
run;
/* categorical variables frequency */
proc freq data = data3;
	tables fuel title_status transmission manufacturer condition cylinders drive type;
run;
/*Data preprocessement*/
data data3;
set data3;
if price = 0 then delete;
run;
data data3;
set data3;
if price > 59900 then delete;
run;
data data3;
set data3;
if year = '.' then delete;
run;
data data3;
set data3;
if year = 1900 then delete;
run;
data data3;
set data3;
if year = " " then delete;
run;

data data3;
set data3;
if odometer > 408765 then delete;
run;
data data3;
set data3;
if odometer = '.' then delete;
run;
data data3;
set data3;
if odometer ne . then do; odometer = 1000000-odometer; end;
run;
data data3;
set data3;
if title_status = "parts" then delete;
run;
data data3;
set data3;
if title_status = "missi" then delete;
run;
data data3;
set data3;
if manufacturer = " " then delete;
run;
/* find missing data */
proc format;
 value $missfmt ' '='Missing' other='Not Missing';
 value  missfmt  . ='Missing' other='Not Missing';
proc print data= data3(obs=10);
run;
/* Imputing condition of the car with odometer rating */
proc summary data=data3 QNTLDEF=3 qmethod=OS;
var odometer;
output out=summary MIN=p1= p25=p50= p75=MAX= / autoname;
run;
proc print data=summary; run;
data data3;
set data3;
if odometer = 0 then delete;
run;
data data3;
set data3;
if odometer < 50000 then condition2='excellent';
else if odometer > 50000 and odometer < 95515 then condition2='good';
else if odometer > 95514 and odometer < 139584 then condition2='fair';
else condition2 ='salvage';
run;
data data3;
	set data3;
	age = 2021-year;
	drop year;
run;
data data3;
set data3;
if age = 0 then delete;
run;

/* Implemented Mode for transmission */ 
data data3;
set data3;
if transmission = 'automatic' then transmission=1;
else if transmission = 'manual' then transmission=2;
else transmission= 1;
run;

proc print data= data3(obs=10);
run;
/*Histogram Plot for normal and log values*/
proc univariate data = data3 plots; 
	var price age odometer; 
	histogram; inset n mean std min max; 
run;
data data3;
	set data3;
	log_price = log(price);
	log_age = log(age);
	log_odometer = log(odometer);
run;
proc univariate data = data3;
	var log_price log_age log_odometer; 
	histogram; inset n mean std min max;
run;
/*Importing Unknown for Blanks */
data data3;
set data3;
if cylinders = '' then cylinders='unknown';
if fuel = '' then fuel='unknown';
if title_status = '' then title_status='unknown';
if type = '' then type='unknown';
run;

proc print data=data3 (obs=20);run;

proc contents data=data3; run;
%drive
/*Assiging weights and imputing mode as rwd*/
data data3;
set data3;
if drive = '4wd' then drive=30;
else if drive = 'rwd' then drive=20;
else if drive = 'fwd' then drive=10;
else drive= 20;
run;
proc print data= data(obs=100);
run;

%size
proc print data= data(obs=10);
run;
/*data data3;
set data3;
if cylinders = '10 cylinder' then cylinders=10;
else if cylinders = '12 cylinder' then cylinders=12;
else if cylinders = '3 cylinders' then cylinders=3;
else if cylinders = '4 cylinders' then cylinders=4;
else if cylinders = '5 cylinders' then cylinders=5;
else if cylinders = '6 cylinders' then cylinders=6;
else if cylinders = '8 cylinders' then cylinders=8;
else cylinders= 0;
run;
proc print data= data3(obs=10);
run;*/
/*
data data3;
set data3;
if condition = 'excellent' then condition=7;
else if condition = 'like new' then condition=6;
else if condition = 'Good' then condition=5;
else if condition = 'Fair' then condition=4;
else if condition = 'Salvage' then condition=1;
else if condition = 'New' then condition=8;
else condition= 0;
run; 
data data3;
set data3;
if title_status = 'clean' then title_status=100;
else if title_status = 'lien' then title_status=0;
else if title_status = 'rebuilt' then title_status=30;
else if title_status = 'salvage' then title_status=10;
else if title_status = 'parts only' then title_status=1;
else title_status= 0;
run;*/
proc print data= data3(obs=10);
run;
/*Regression*/
proc glmselect data=data3 outdesign=data4_li;
	class manufacturer fuel transmission type cylinders condition2 title_status drive ;
	linear: model price = manufacturer fuel transmission cylinders type condition2 title_status drive odometer age; 
	title "Linear Regression";
	run;
/*Random Sample*/
proc surveyselect data=data3 out=sample_data method=srs sampsize=10000 seed=987654321;
run;
/* Create training and test datasets 80% of sample in train and 20 in test  */
proc surveyselect data=sample_data out=hwdata_sampled outall samprate=0.8 seed=2;
run;
data train_data test_data;
 set hwdata_sampled;
 if selected then output train_data;
 else output test_data;
run;

/* Forward------------ */
proc glmselect data=train_data testdata=test_data  plots=all;
 class manufacturer fuel transmission type cylinders condition2 title_status drive ;
 model price = age|odometer| manufacturer |fuel| transmission| drive | type| title_status| cylinders| condition2 @2
  /selection=forward(select=cp) hierarchy=single showpvalues ;
 performance buildsscp=incremental;
run;

/* Backward------------ */
proc glmselect data=train_data testdata=test_data  plots=all;
 class manufacturer fuel transmission type cylinders condition2 title_status drive ;
 model price = age|odometer| manufacturer |fuel| transmission| drive | type| title_status| cylinders| condition2 @2
  /selection=backward(select=cp) hierarchy=single showpvalues ;
 performance buildsscp=incremental;
run;

/* Stepwise------------ */
proc glmselect data=train_data testdata=test_data  plots=all;
 class manufacturer fuel transmission type cylinders condition2 title_status drive ;
 model price = age|odometer| manufacturer |fuel| transmission| drive | type| title_status| cylinders| condition2 @2
  /selection=stepwise(select=cp) hierarchy=single showpvalues ;
 performance buildsscp=incremental;
run;
*DATA Visualization;
proc univariate data = data3;
	var log_price log_age;
	histogram / normal kernel;
	qqplot / normal(mu=est sigma=est);
	inset n mean std;
run;
/* price distribution by categories */
proc univariate data = data3; class age; var log_price; histogram; run;
proc univariate data = data3; class condition; var log_price; histogram; run;
proc univariate data = data3; class cylinders; var log_price; histogram; run;
proc univariate data = data3; class drive; var log_price; histogram; run;
proc univariate data = data3; class fuel; var log_price; histogram; run;
proc univariate data = data3; class manufacturer; var log_price; histogram; run;
proc univariate data = data3; class paint_color; var log_price; histogram; run;
proc univariate data = data3; class size; var log_price; histogram; run;
proc univariate data = data3; class title_status; var log_price; histogram; run;
proc univariate data = data3; class transmission; var log_price; histogram; run;
proc univariate data = data3; class type; var log_price; histogram; run;






 










