clear 
clear matrix
clear mata
set more off
set mem 300m
cd "C:\Users\YoonJoung Choi\Dropbox\0 Project\ReproResearch_Inequality_Metdemand "

/* install these if you don't have it yet. 
ssc install libjson
ssc install insheetjson
*/

*******************************************************************
*** 1. Data Access 
*******************************************************************

* 1.1. DEFINE relevant indicators for the study (only three indicators for this study)
/*
List of indicators are here: 
http://api.dhsprogram.com/rest/dhs/indicators?returnFields=IndicatorId,Label,Definition&f=html
*/
	
#delimit;
global indicatorlist " 

	FP_CUSA_W_ANY
	FP_CUSM_W_ANY
	FP_CUSU_W_ANY
	
	FP_CUSA_W_MOD
	FP_CUSM_W_MOD
	FP_CUSU_W_MOD
	
	FP_NADA_W_UNT
	FP_NADM_W_UNT
	FP_NADU_W_UNT
	
	ED_EDAT_W_NED ED_EDAT_W_SPR ED_EDAT_W_CPR ED_EDAT_W_SSC ED_EDAT_W_CSC ED_EDAT_W_HGH ED_EDAT_W_DKM
	";
	#delimit cr		
		
#delimit;
global indicatorlist_minusone " 

	FP_CUSM_W_ANY
	FP_CUSU_W_ANY
	
	FP_CUSA_W_MOD
	FP_CUSM_W_MOD
	FP_CUSU_W_MOD
	
	FP_NADA_W_UNT
	FP_NADM_W_UNT
	FP_NADU_W_UNT	
	
	ED_EDAT_W_NED ED_EDAT_W_SPR ED_EDAT_W_CPR ED_EDAT_W_SSC ED_EDAT_W_CSC ED_EDAT_W_HGH ED_EDAT_W_DKM	
	";
	#delimit cr		

* 1.2. CALL API data for each indicator and save each
/*
Notes about calling DHS API data:   
1. Only one indicator can be accessed at a time. 

2. Since we need the indicator by subgroup, set __breakdown=all__.   

3. Each API call can will provide maximum 1000 observations (unless you become a 
registered user). Thus, it should be compiled via multiple pages __until the last 
survey__ (i.e., latest survey in the last country in alphabetical order - Zimbabwe). 
The required number of pages depends on the number of subgroups, which depends on the 
indicator itself and the survey design/sample size. Typically about 15 pages are sufficient 
to include comprehensive results from over 250 surveys (which is needed for this study	), 
but always check if the latest Zimbabwe data are included. If you are a registered user: 
include your __APIkey__, set __perpage=20000__, exclude __pagenum__ in the request call, 
and have no need to worry about this perpage limit!  

4. Finally, though relatively rare, indicator estimates in DHS API (which shares the 
same base data with DHS STATcompiler) can be updated over time. For example, there was 
a notable update for a few family planning indicators in Mozambique DHS 2003 since the 
time of original analysis (September 2017). Thus, the reproduced dataset may not be 
identical with the original analysis dataset. However, impact of any updates should be
minimal for overall study findings, interpretation, and conclusion.   
*/

foreach indicator in $indicatorlist{

	local num=1
	while `num'<17{

	clear
	insheetjson using "http://api.dhsprogram.com/rest/dhs/data?indicatorIds=`indicator'&breakdown=all&perpage=5000&page=`num'", 

		gen str9  surveyid=""
		gen str30 country=""	
		gen str20 group=""
		gen str20 grouplabel=""
		gen str5  value=""	

	#delimit; 	
	insheetjson surveyid country group grouplabel value 
	using  "http://api.dhsprogram.com/rest/dhs/data?indicatorIds=`indicator'&breakdown=all&perpage=1000&page=`num'", 
	table(Data) 
	col(SurveyId CountryName CharacteristicCategory CharacteristicLabel Value);	
	#delimit cr

		tab surveyid, m
		save temp`num'.dta, replace
		local num = `num' + 1
		}				
	
	use temp1.dta, clear
		local num=2
		while `num'<17{

		appen using temp`num'.dta		 
		local num = `num' + 1
		}		
			
		destring value, replace	
		drop if value==.
		rename value `indicator'
			
		sort surveyid group grouplabel
			egen temp=group(surveyid group grouplabel)
			codebook temp
			sort temp
			drop if temp==temp[_n-1]
			drop temp
	
	sort surveyid group grouplabel
	save API_`indicator'.dta, replace	
	
	}
	
local num=1
	while `num'<17{
	
	erase temp`num'.dta	 
	local num = `num' + 1
	}	
	
* 1.3. merge the three indicator datasets, starting from the first indicator 
	
use API_FP_CUSA_W_ANY.dta, clear	
	sort surveyid group grouplabel
	
	foreach indicator in $indicatorlist_minusone{	
	 
		merge surveyid group grouplabel using API_`indicator'	
			codebook _merge* 
			drop _merge*	
			
		sort surveyid group grouplabel
	}

sort country 	
save DHSAPI_inequality_metdemand, replace	
*/

*******************************************************************
*** 2. Data Management 
*******************************************************************

* 2.1. Tidy the dataset 
* Currently, survey-subgroup specific observations

use DHSAPI_inequality_metdemand, clear	
	
		*rename API variables*

		rename	FP_CUSA_W_ANY cpr_all
		rename	FP_CUSM_W_ANY cpr_married
		rename	FP_CUSU_W_ANY cpr_unmarried
			
		rename	FP_CUSA_W_MOD mcpr_all
		rename	FP_CUSM_W_MOD mcpr_married
		rename	FP_CUSU_W_MOD mcpr_unmarried
			
		rename	FP_NADA_W_UNT unmet_all
		rename	FP_NADM_W_UNT unmet_married
		rename	FP_NADU_W_UNT unmet_unmarried
		
		rename	ED_EDAT_W_NED	edu_none
		rename	ED_EDAT_W_SPR	edu_somepri
		rename	ED_EDAT_W_CPR	edu_comppri
		rename	ED_EDAT_W_SSC	edu_somesec
		rename	ED_EDAT_W_CSC	edu_compsec
		rename	ED_EDAT_W_HGH	edu_high
		rename	ED_EDAT_W_DKM	edu_dkmiss

	gen demandmet_m_all =  100* mcpr_all / (cpr_all + unmet_all)
	gen demandmet_m_married = 100* mcpr_married / (cpr_married + unmet_married) 
	gen demandmet_m_unmarried = 100* mcpr_unmarried / (cpr_unmarried + unmet_unmarried) 
	
	replace group ="Total" if group=="Total 15-49"
	replace grouplabel ="Total" if grouplabel=="Total 15-49"
	
	gen year=substr(surveyid,3,4)  
		destring year, replace	
		label var year "year of survey"
			
	gen type=substr(surveyid,7,3) 	
		label var type "type of survey"
		tab year type, m
		
	egen temp=group(surveyid grouplabel) if group=="Region"
	egen countregion=count(temp), by(surveyid)	
		lab var countregion "Number of regions per survey" 
		drop temp
		
	replace country="DRC" if country=="Congo Democratic Republic"

sort country 	
save temp, replace	

* 2.2 Create regional variables, following UN classification 
* Call WDI API (which has first-level classification)
* Then generate the second level classification https://unstats.un.org/unsd/methodology/m49/

ssc install wbopendata

**Once installed, the wbopendata module offers four possible download options: 
/*
Once installed, to open up the module’s graphical panel type the following:

	db wbopendata

A WDI window will open with options for filtering.  
For the purpose of this paper, only regional classification of coutnries is needed. 
Thus, an indicator "NY.GDP.MKTP.CD" was used
*/

wbopendata, language(en - English) /// 
			indicator(NY.GDP.MKTP.CD) ///
			long clear latest
	
		*keep only country and region name
		keep countryname regionname 
		rename countryname country 
		rename regionname region  	
		drop if region=="Aggregates"
	
		*replace names to be consistent with those in DHS API
		replace country="Bolivia" 		if country=="Bolivia (Plurinational State of)"
		replace country="Congo" 		if country=="Congo, Rep."
		replace country="DRC" 			if country=="Democratic Republic of the Congo"
		replace country="DRC" 			if country=="Congo, Dem. Rep."
		replace country="Egypt" 		if country=="Egypt, Arab Rep."
		replace country="Gambia" 		if country=="Gambia, The"
		replace country="Kyrgyz Republic" if country=="Kyrgyzstan"
		replace country="Moldova" 		if country=="Republic of Moldova"
		replace country="Tanzania" 		if country=="United Republic of Tanzania"
		replace country="Vietnam" 		if country=="Viet Nam"
		replace country="Yemen" 		if country=="Yemen, Rep."

	sort country
	merge country using temp
	
	tab _merge, m
		keep if _merge==3
		drop _merge 
		
	gen region2=""
	replace region2="Eastern Africa" if ///		
		country=="Burundi" | ///
		country=="Comoros" | ///
		country=="Djibouti" | ///
		country=="Eritrea" | ///
		country=="Ethiopia" | ///
		country=="Kenya" | ///
		country=="Madagascar" | ///
		country=="Malawi" | ///
		country=="Mauritius" | ///
		country=="Mayotte" | ///
		country=="Mozambique" | ///
		country=="Réunion" | ///
		country=="Rwanda" | ///		
		country=="Seychelles" | ///
		country=="Somalia" | ///
		country=="South Sudan" | ///
		country=="Uganda" | ///
		country=="Tanzania" | ///
		country=="Zambia" | ///
		country=="Zimbabwe" 
	replace region2="Middle Africa" if /// 	
		country=="Angola" | ///
		country=="Cameroon" | ///
		country=="Central African Republic" | ///
		country=="Chad" | ///
		country=="Congo" | ///
		country=="DRC" | ///
		country=="Equatorial Guinea" | ///
		country=="Gabon" | ///
		country=="Sao Tome and Principe" 
	replace region2="Western Africa" if /// 	
		country=="Benin" | ///
		country=="Burkina Faso" | ///
		country=="Cape Verde" | ///
		country=="Cote d'Ivoire" | ///
		country=="Gambia" | ///
		country=="Ghana" | ///
		country=="Guinea" | ///
		country=="Guinea-Bissau" | ///
		country=="Liberia" | ///
		country=="Mali" | ///
		country=="Mauritania" | ///
		country=="Niger" | ///
		country=="Nigeria" | ///
		country=="Saint Helena" | ///
		country=="Senegal" | ///
		country=="Sierra Leone" | ///
		country=="Togo" 
	replace region2="Southern Africa" if ///
		country=="Botswana" | ///
		country=="Eswatini" | ///
		country=="Lesotho" | ///
		country=="Namibia" | ///
		country=="South Africa"  

* 2.3. gen var to calculate disparity: absolute % difference

	* min & max: by SES order 
	foreach x of varlist demandmet_m_married  {
		gen min_`x'_edu=`x' if group=="Education" & grouplabel=="No education"
		gen max_`x'_edu=`x' if group=="Education (2 groups)" & grouplabel=="Secondary or higher"
		
		gen min_`x'_hhw=`x' if group=="Wealth quintile" & grouplabel=="Lowest"
		gen max_`x'_hhw=`x' if group=="Wealth quintile" & grouplabel=="Highest"
		
		gen min_`x'_rurb=`x' if group=="Residence" & grouplabel=="Rural"
		gen max_`x'_rurb=`x' if group=="Residence" & grouplabel=="Urban"
		}		

	* min & max: without order 
	foreach x of varlist demandmet_m_married  {
		egen min2_`x'_age=min(`x') if group=="Age (5-year groups)", by(surveyid)
		egen max2_`x'_age=max(`x') if group=="Age (5-year groups)", by(surveyid)
				
		egen min2_`x'_reg=min(`x') if group=="Region", by(surveyid)
		egen max2_`x'_reg=max(`x') if group=="Region", by(surveyid)
		}

	* assign survey-subgroup specific measures to each corresponding survey 
	* in order to changes to survey-level data as below.  
	foreach x of varlist min* max* {
		egen temp=mean(`x'), by(surveyid)
		replace `x'=temp if `x'==.
		drop temp
		}
		
	foreach x of varlist demandmet_m_married  {		
		gen gap_`x'_edu		= max_`x'_edu - min_`x'_edu 	
		gen gap_`x'_hhw		= max_`x'_hhw - min_`x'_hhw 
		gen gap_`x'_rurb	= max_`x'_rurb - min_`x'_rurb 
		gen gap2_`x'_age	= max2_`x'_age - min2_`x'_age 
		gen gap2_`x'_reg	= max2_`x'_reg - min2_`x'_reg 
		}		
		
	* absolute % difference by marital status: with and without order  	
		gen gap_demandmet_m_mar 	= demandmet_m_married - demandmet_m_unmarried if group=="Total"
		gen gap2_demandmet_m_mar 	= abs(demandmet_m_married - demandmet_m_unmarried) if group=="Total"
		
* 2.4. collapse to the survey level  
* Now, survey specific observations

	keep if group=="Total"
	drop group* 
	
* 2.5. Keep analysis sample
* countries that have conducted two or more DHS surveys since 1990 

	*Only surveys conducted in or after 1990	
	keep if year>=1990
	
	*Only DHS surveys (e.g., not AIS)
	keep if type=="DHS"
	
	*Only surveys that collected FP demand/unmet need data 
	keep if demandmet_m_married!=.
	
	*Drop newly released surveys since September 2017 to reproduce the results
	*They are likely surveys conducted in 2014, 2015 or later
	*See Supplement 1 for the list of surveys incldued in the study
	*http://www.ghspjournal.org/content/suppl/2018/06/29/GHSP-D-18-00012.DCSupplemental
	drop if year>=2017	
	drop if year==2016 & (surveyid!="AM2016DHS" & surveyid!="ET2016DHS")
	drop if year==2015 & (surveyid!="CO2015DHS" & surveyid!="GU2015DHS" ///
						& surveyid!="MW2015DHS" & surveyid!="RW2015DHS" ///
						& surveyid!="TZ2015DHS" & surveyid!="ZW2015DHS")
	drop if year==2014 & (surveyid!="BD2014DHS" & surveyid!="EG2014DHS" ///
						& surveyid!="GH2014DHS" & surveyid!="KE2014DHS" ///
						& surveyid!="KH2014DHS" & surveyid!="LS2014DHS" ///
						& surveyid!="SN2014DHS" & surveyid!="TD2014DHS")
  
		codebook country surveyid

	*Only surveys from countries that had 2 or more surveys 
	egen count=count(demandmet_m_married), by(country)
		lab var count "Number of DHS with unmet need in each country" 
		tab count, m
	drop if count==1
	
	codebook country surveyid /*SHOULD be "213 surveys from 55 countries <== ANALYSIS SAMPLE"*/

* 2.6. Create summary measure variables 
			
	egen temp=max(year), by(country) 	
	gen byte latest= year==temp
		drop temp
		label var latest "latest survey included in this study (per country)"

	egen yearmin=min(year), by(country)
	egen yearmax=max(year), by(country)
		label var yearmin "first survey included in this study (per country)"
		label var yearmax "latest survey included in this study (per country)"

sort surveyid		
save ReproResearch_Inequality_Metdemand, replace		

erase temp.dta

*******************************************************************
*** 3. Data Analysis 
*******************************************************************

/*
There are five figures and one table in results. 
The following presents code in the order as they appear in the paper. 
*/

*** Figure 1: Level of disparity by subgroup, latest survey in each country  
use ReproResearch_Inequality_Metdemand, clear

keep if latest==1

	#delimit; 		
	global varlist "gap_demandmet_m_married_edu 
					gap_demandmet_m_married_hhw 
					gap_demandmet_m_married_rurb 
					gap_demandmet_m_mar 
					gap2_demandmet_m_married_age 
					gap2_demandmet_m_married_reg";
	#delimit cr 					
				
	#delimit; 		
	graph box $varlist if latest==1, 
		legend(
			col(1) stack pos(3) size(vsmall)
			label(1 "Education""(secondary""or higher""vs. none)")
			label(2 "Household" "wealth" "quintile" "(highest" "vs. lowest)") 
			label(3 "Residence" "(urban" "vs. rural)")
			label(4 "Currently" "married/" "cohabiting" "(yes vs.no)")
			label(5 "Age*")
			label(6 "Region*")
			) 
		yline(0, lcolor(black) lpattern(-))		
		ylabel(-40(20)80, angle(0) labsize(small))
		l1title("Percentage-Point Difference in Met Demand", size(small))
		
		xsize(10) ysize(8)
		;
		#delimit cr
	gr_edit .style.editstyle boxstyle(shadestyle(color(white))) editcopy	
		
	sum	$varlist if latest==1, detail
	sum countregion if latest==1
	
*** Table: trends of disparity  
use ReproResearch_Inequality_Metdemand, clear
	 
	egen countryid=group(country)
	#delimit; 		
	global varlist "gap_demandmet_m_married_edu 
					gap_demandmet_m_married_hhw 
					gap_demandmet_m_married_rurb 
					gap_demandmet_m_mar
					gap2_demandmet_m_married_age 
					gap2_demandmet_m_married_reg";
	#delimit cr 
	
	foreach x of varlist $varlist { 
		xtreg `x' year, i(countryid)
		xtreg `x' year demandmet_m_married, i(countryid)	
		}

*** Figure 2: trends of disparity by country   
use ReproResearch_Inequality_Metdemand, clear		

	sort year
	#delimit;
	twoway scatter gap_demandmet_m_married_hhw demandmet_m_married if (region2=="Middle Africa" | region2=="Western Africa"), 
		by(country, 
			title("Central and Western Africa")
			col(6) note(""))
		connect(l) msize(small) mlabel(year) mlabsize(small)
		xline(75, lpattern(-) lcolor(black))
		yline(0, lpattern(-) lcolor(black))
		ytitle(	"Difference Between Wealth Quintiles (percentage point)", size(small))
		xtitle(	"National Average (%)", size(small))	
		ylab(-20(20)60) xlab(0(20)100)
		xsize(9) ysize(3.5)	
		;
		#delimit cr
	gr_edit .style.editstyle boxstyle(shadestyle(color(white))) editcopy	
	gr_edit .plotregion1.subtitle[1].style.editstyle fillcolor(white) linestyle(color(white)) size(medlarge)  editcopy		
	
	sort year
	#delimit;
	twoway scatter gap_demandmet_m_married_hhw demandmet_m_married if (region2=="Eastern Africa" | region2=="Southern Africa"), 
		by(country, 
			title("Southern and Eastern Africa")
			col(6) note(""))
		connect(l) msize(small) mlabel(year) mlabsize(small)
		xline(75, lpattern(-) lcolor(black))
		yline(0, lpattern(-) lcolor(black))
		ytitle(	"Difference Between Wealth Quintiles (percentage point)", size(small))
		xtitle(	"National Average (%)", size(small))	
		ylab(-20(20)60) xlab(0(20)100)
		xsize(9) ysize(3.5)	
		;
		#delimit cr
	gr_edit .style.editstyle boxstyle(shadestyle(color(white))) editcopy	
	gr_edit .plotregion1.subtitle[1].style.editstyle fillcolor(white) linestyle(color(white)) size(medlarge)  editcopy		
	
	sort year
	#delimit;
	twoway scatter gap_demandmet_m_married_hhw demandmet_m_married if region~="Sub-Saharan Africa", 
		by(country, 
			title("Other Region")
			col(6) note(""))
		connect(l) msize(small) mlabel(year) mlabsize(small)
		xline(75, lpattern(-) lcolor(black))
		yline(0, lpattern(-) lcolor(black))
		ytitle(	"Difference Between Wealth Quintiles (percentage point)", size(small))
		xtitle(	"National Average (%)", size(small))	
		ylab(-20(20)60) xlab(0(20)100)
		xsize(9) ysize(4.5)	
		;
		#delimit cr
	gr_edit .style.editstyle boxstyle(shadestyle(color(white))) editcopy	
	gr_edit .plotregion1.subtitle[1].style.editstyle fillcolor(white) linestyle(color(white)) size(medlarge)  editcopy		
	
*** Figure 3: varying trends of progress by background 
use ReproResearch_Inequality_Metdemand, clear
	
keep if country=="Cameroon" | country=="Ethiopia" | country=="Madagascar" | country=="Nigeria"
	
	tab surveyid country, m	

	gen country3=.
		replace country3=1 if country=="Madagascar"
		replace country3=2 if country=="Ethiopia"
		replace country3=3 if country=="Cameroon"
		replace country3=4 if country=="Nigeria"	
		lab define country3 1"Madagascar" 2"Ethiopia" 3"Cameroon" 4"Nigeria"
		lab values country3 country3
	
	#delimit;	
	twoway scatter demandmet_m_married min_demandmet_m_married_hhw max_demandmet_m_married_hhw year,  
		by(country3, 
			row(1) 
			note("")
			)
		mcolor(black red blue)
		connect(l l l) lcolor(black red blue) lpattern(l - -)  
		yline(75, lpattern(-) lcolor(black))
		ylabel(0 (20) 80, angle(0)	)
		xlabel(1990 (10) 2010, angle(45))		
		xtitle(	"Year", size(medium))
		ytitle(	"Met Demand (%)" , size(medium))
		legend(
			row(1) order(1 2 3)
			label(1 "National")
			label(2 "Lowest wealth quintile" "households" )			
			label(3 "Highest wealth quintile" "households" ) )
		xsize(9.8) ysize(6.1)
		;
		#delimit cr	
	gr_edit .style.editstyle boxstyle(shadestyle(color(white))) editcopy	
	gr_edit .plotregion1.subtitle[1].style.editstyle fillcolor(white) linestyle(color(white)) size(medlarge)  editcopy		
		
*** Figure 4: Correlation Matrix 
use ReproResearch_Inequality_Metdemand, clear

keep if latest==1

	#delimit; 		
	global varlist "gap_demandmet_m_married_edu 
					gap_demandmet_m_married_hhw 
					gap_demandmet_m_married_rurb 
					gap_demandmet_m_mar 
					gap2_demandmet_m_married_age 
					gap2_demandmet_m_married_reg";
	#delimit cr 					
				
	pwcorr	$varlist if latest==1, sig obs
	
	#delimit; 		
	graph matrix $varlist if latest==1, 
		msize(vsmall)
		maxes(xlabel(-40(40)80, labsize(small) angle(45)) ylabel(-40(40)80, labsize(small) ) )
	
		xsize(10) ysize(10)
	
		diag(
			"Disparity by education (secondary+ vs. none) (% point)"
			"Disparity by wealth (highest vs. lowest quintile) (% point)"
			"Disparity by residential area (urban vs. rural) (% point)"
			"Disparity by union status (in-union vs. not in-union) (% point)"
			"Disparity by 5-year age group (% point)"
			"Disparity by administrative unit (% point)"
			, size(small))
			
		;
		#delimit cr			
		
		*half /* why error?*/
		
	graph export Figure4_Matrix.tif, as(tif) width(3900) replace
	
*** Figure 5: 
use ReproResearch_Inequality_Metdemand, clear

	* Data wranging: replace each education variable with cumulative value. 
	replace edu_somepri =edu_somepri + edu_none 
	replace edu_comppri =edu_comppri + edu_somepri 
	replace edu_somesec =edu_somesec + edu_comppri 
	replace edu_compsec =edu_compsec + edu_somesec 
	replace edu_high 	=edu_high + edu_compsec
		
	sort year	
	#delimit;		
 	twoway area edu_high edu_compsec edu_somesec edu_comppri edu_somepri edu_none year,  
		by(country, 
			row(7) iscale(*1.5)
			legend(pos(3))
			note(" ")
			graphregion(color(white)) 
			imargin(b=1 t=1)
			)
		color(dkgreen green midgreen blue midblue cranberry)
		ylabel(0 (50) 100, labsize(medsmall) angle(0)	)
		xlabel(1990 (10) 2010, labsize(medsmall) angle(45))		
		xtitle(	"Survey Year", size(small))
		ytitle(	"Cumulative Distribution of Female Population (%)", size(small))
		xsize(9.85) ysize(6.15)
		legend(col(1) stack size(vsmall)
			label(1 "Completed" "higher than" "secondary")
			label(2 "Completed" "secondary")
			label(3 "Attended" "some secondary")			
			label(4 "Completed" "primary")
			label(5 "Attended" "some primary")
			label(6 "None")			
			) 
		;
		#delimit cr	
	gr_edit .plotregion1.subtitle[1].style.editstyle fillcolor(white) linestyle(color(white)) size(medlarge)  editcopy		
	
	graph export Figure5_EducationCompositionTrends.tif, as(tif) width(3900) replace
