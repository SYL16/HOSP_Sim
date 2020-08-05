

/*This program attempts to evaluate COVID-19 hospitalization census as a function of cases.*/

**************************************************************************************************************************************************************************
* Set up parameters of the Erlang distribution for length of hospital stay, x = beta*RAND('ERLANG',alpha)                                                   
**************************************************************************************************************************************************************************;
%let alpha=2;  
%let beta=4;

**************************************************************************************************************************************************************************
* Macro name:  hosp_sim                                                             
*
* Description:                                                                      
*              This macro simulates number of hospital bed census as a function of daily new cases, 
*              based on a fixed probablity of hospitalization and a random length of hospital stay.                                        
*
* Parameters:                                                                       
*              nSim      : number of simulations  (default=100).                    
*              dMoni     : the monitoring period in days (default=120).              
*              inc       : raw daily new cases (default=200).                        
*              incSF     : a scale factor for daily new cases (default=1.22). E.g., Memphis metro area cases=1.22*Shelby cases
*              pHosp     : probability of hospitalization (default=0.1).             
*              dInf2Hosp : days from infection to hospitalization (default=14).      
*                                                                                   
* Output:                                                                           
*             Sim_hosp_cases : a dataset that contains simulated cases being hospitalized during the monitering period.                      
*             Sim_beds       : a dataset that contains simulated hospital bed census for each day during the monitering period.  
**************************************************************************************************************************************************************************;

%macro hosp_sim(nSim=100, dMoni=120, inc=200, incSF=1.22, pHosp=0.1, dInf2Hosp=14);  
options nonotes;
  data sim_hosp_cases;
  	   nSim=&nSim; dMoni=&dMoni; daily_cases=&inc; daily_cases_scaled=&inc * &incSF; pHosp=&pHosp; dInf2Hosp=&dInf2Hosp;
       do SimID = 1 to &nSim;  
		  do SubjectID=1 to &inc * &incSF * (&dMoni+1-&dInf2Hosp); * To keep the probability of hospitalization as specified;
			    Hosp=(uniform(0)<&pHosp); 
				if Hosp=1 then do;                    
                     InfStart=ceil(uniform(0)*(&dMoni+1-&dInf2Hosp)); 
                     HospStart=InfStart+&dInf2Hosp-1;              
                     HospEnd=HospStart+ceil(&beta*rand('ERLANG',&alpha))-1;                   
                     if HospEnd>&dMoni then HospEnd=&dMoni;
                     dHosp=HospEnd-HospStart+1;
                     output;
				end;
		  end;
	   end;
  run;
  data temp; set sim_hosp_cases(keep=SimID HospStart HospEnd);
       do day=1 to &dMoni;
       if HospStart<=day<=HospEnd then do; y=1; output; end;
	   end;
  run;
  proc summary data=temp;
       by SimID; 
       class day; 
       var y;
       output out=temp(where=(_TYPE_=1)) sum=;
  run;
  data Sim_beds; 
       format nSim dMoni daily_cases daily_cases_scaled pHosp dInf2Hosp Day; 
       set temp(drop=_TYPE_ _FREQ_ rename=(y=Beds));
       nSim=&nSim; dMoni=&dMoni; daily_cases=&inc; daily_cases_scaled=&inc * &incSF; pHosp=&pHosp; dInf2Hosp=&dInf2Hosp;
  run;
  proc sql; drop table temp; quit;
options notes;
%put NOTE: Datasets have been successfully created.;
%mend;


* Simulate data with different values of daily new cases;
%hosp_sim(inc=200, incSF=1.22, pHosp=0.1); data beds_200; set Sim_beds; run;  * actual daily cases=200*1.22=244; 
%hosp_sim(inc=300, incSF=1.22, pHosp=0.1); data beds_300; set Sim_beds; run;  * actual daily cases=300*1.22=366; 
%hosp_sim(inc=400, incSF=1.22, pHosp=0.1); data beds_400; set Sim_beds; run;  * actual daily cases=400*1.22=488;
%hosp_sim(inc=600, incSF=1.22, pHosp=0.1); data beds_600; set Sim_beds; run;  * actual daily cases=600*1.22=732;
%hosp_sim(inc=800, incSF=1.22, pHosp=0.1); data beds_800; set Sim_beds; run;  * actual daily cases=800*1.22=976;

data beds_comp; set beds_200 beds_300 beds_400 beds_600 beds_800;
	 plotID=compress(put(daily_cases,best8.)||"-"||put(SimID,best8.));
	 linetype=1;
run;


* Show number of hospital bed census as a function of daily new cases;
ods graphics / ANTIALIAS=off;       /* anti-aliasing off */
proc sgplot data=beds_comp; 
	 series x=day y=beds/group=plotID grouplc=daily_cases grouplp=linetype name='groups';
	 keylegend 'groups' / type=linecolor position=top title="Daily new cases";
	 xaxis values=(0 to 120 by 10);
	 yaxis label="Beds" grid minor;
run;


* Calculate stats for hospital bed census;
proc summary data=beds_comp;
     by daily_cases ;  
	 class Day;
     var beds;
     output out=stats(where=(_TYPE_=1)) MEAN=means STD=stds;
run;
data stats; set stats; lowers=means-2*stds; uppers=means+2*stds; run; 
* plot mean +/- 2SD;
ods graphics / ANTIALIAS=on;       /* anti-aliasing on */
proc sgplot data=stats; 
     band x=day lower=lowers upper=uppers/group=daily_cases transparency=0.5;
	 series x=day y=means/group=daily_cases;
	 keylegend / type=fillcolor position=top title="Daily new cases";
	 xaxis values=(0 to 120 by 10);
	 yaxis label="Beds" grid minor;
run;








