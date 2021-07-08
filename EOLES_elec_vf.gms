*-------------------------------------------------------------------------------
*                                Defining the sets
*-------------------------------------------------------------------------------
sets     i                                               /0*8759/
         h(i)                                            /0*8735/
         first(h)        'first hour'
         last(h)         'last hour'
         m               'month'                         /1*12/
         tec             'technology'                    /offshore_f, offshore_g, onshore, pv_g, pv_c, river, lake, biogas1, biogas2, ocgt, ccgt, nuc, h2_ccgt, phs,  battery1, battery4, electrolysis, hydrogen, SC/
         gen(tec)        'power plants'                  /offshore_f, offshore_g, onshore, pv_g, pv_c, river, lake, ocgt, ccgt, nuc/
         vre(tec)        'variable tecs'                 /offshore_f, offshore_g, onshore, pv_g, pv_c, river/
         balance(tec)    'non-combustible generation'    /offshore_f, offshore_g, onshore, pv_g, pv_c, river, lake, nuc, phs, battery1, battery4, h2_ccgt,ocgt,ccgt/
         str(tec)        'storage technologies'          /phs, battery1, battery4, hydrogen/
         str_noH2(str)   'storage technologies'          /phs, battery1, battery4/
         battery(str)    'battery storage'               /battery1, battery4/
         frr(tec)        'technologies for upward FRR'   /lake, phs, ocgt, ccgt, nuc, h2_ccgt, SC/
;
first(h) = ord(h)=1;
last(h) = ord(h)=card(h);
alias(h,hh);
*-------------------------------------------------------------------------------
*                                Inputs
*-------------------------------------------------------------------------------
parameter month(i)  /0*743 1, 744*1439 2, 1440*2183 3, 2184*2903 4
                    2904*3647 5, 3648*4367 6, 4368*5111 7, 5112*5855 8
                    5856*6575 9, 6576*7319 10, 7320*8039 11, 8040*8759 12/
$Offlisting
parameter load_factor(vre,i) 'Production profiles of VRE'
/
$ondelim
$include  inputs/vre_profiles2006new.csv
$offdelim
/;
parameter demand(h) 'demand profile in each hour in GW'
/
$ondelim
$include inputs/demand2050_RTE.csv
$offdelim
/;
Parameter lake_inflows(m) 'monthly lake inflows in GWh'
/
$ondelim
$include  inputs/lake2006.csv
$offdelim
/ ;
parameter epsilon(vre) 'additional FRR requirement for variable renewable energies because of forecast errors'
/
$ondelim
$include  inputs/reserve_requirements_new.csv
$offdelim
/ ;
parameter capa_ex(tec) 'existing capacities of the technologies by December 2017 in GW'
/
$ondelim
$include  inputs/existing_capas_elec_new.csv
$offdelim
/ ;
parameter capa_max(vre) 'maximum capacities of the technologies in GW'
/
$ondelim
$include  inputs/max_capas_elec_new.csv
$offdelim
/ ;
parameter capex(tec) 'annualized power capex cost in M€/GW/year'
/
$ondelim
$include  inputs/annuities_elec_new.csv
$offdelim
/ ;
parameter capex_en(str) 'annualized energy capex cost of storage technologies in M€/GWh/year'
/
$ondelim
$include  inputs/str_annuities_elec_new.csv
$offdelim
/ ;
parameter fOM(tec) 'annualized fixed operation and maintenance costs M€/GW/year'
/
$ondelim
$include  inputs/fO&M_elec_new.csv
$offdelim
/ ;
Parameter vOM(tec) 'Variable operation and maintenance costs in M€/GWh'
/
$ondelim
$include  inputs/vO&M_elec_new.csv
$offdelim
/ ;

parameter fixed_costs(tec) 'yearly fixed cost of each tec in M€/GW/year' ;
fixed_costs(tec) = capex(tec) + fOM(tec);
parameter s_capex(str) 'charging related annuity of storage in M€/GW/year' /PHS 26.66765, battery1 0, battery4 0, hydrogen 0/;
parameter s_opex(str)    'charging related fOM of storage in M€/GW/year'   /PHS 7.5, battery1 0, battery4 0, hydrogen 0/;
parameter eta_in(str) 'charging efifciency of storage technologies' /PHS 0.9, battery1 0.9, battery4 0.9, hydrogen 1/;
parameter eta_out(str) 'discharging efficiency of storage technolgoies' /PHS 0.9, battery1 0.95, battery4 0.95, hydrogen 0.97/;
scalar eta_ocgt 'efficiency of OCGT power plants' /0.40/;
scalar eta_ccgt 'efifciency of CCGT power plants with CCS' /0.57/;
scalar cf_nuc 'maximum capacity factor of nuclear power plants' /0.90/;
scalar ramp_rate 'maximum ramp up/down rate for nuclear power plant' /0.5/;
scalar cf_ccgt 'maximum capaity factor of CCGT plant for a year' /0.85/;
scalar max_biogas 'maxium energy can be generated by biogas in TWh' /15/;
scalar load_uncertainty 'uncertainty coefficient for hourly demand' /0.01/;
scalar delta 'load variation factor'     /0.1/;
parameter capacity_ex(str) 'existing storage capacity in GWh' /PHS 101.1, battery1 0, battery4 0, hydrogen 3000/;
parameter s_ex(str) 'existing storage capacity in GWh' /PHS 4.2, battery1 0, battery4 0, hydrogen 0/;
parameter H2_demand(h)'hourly hydrogen demand on top of the storage';
H2_demand(h) = 4.56621;
*-------------------------------------------------------------------------------
*                                Model
*-------------------------------------------------------------------------------
variables        GENE(tec,h)     'hourly energy generation in TWh'
                 CAPA(tec)       'overal yearly installed capacity in GW'
                 STORAGE(str,h)  'hourly electricity input of battery storage GW'
                 S(str)          'charging power capacity of each storage technology'
                 STORED(str,h)   'energy stored in each storage technology in GWh'
                 CAPACITY(str)   'energy volume of storage technologies in GWh'
                 RSV(frr,h)      'required upward frequency restoration reserve in GW'
                 COST            'final investment cost in b€'

positive variables GENE(tec,h),CAPA(tec),STORAGE(str,h), S(str),STORED(str,h),CAPACITY(str),RSV(frr,h);

equations        gene_vre        'variables renewable profiles generation'
                 gene_capa       'capacity and genration relation for technologies'
                 batt_cap1
                 batt_cap4
                 combustion1     'the relationship of combustible technologies'
                 combustion2     'the relationship of combustible technologies'
                 capa_frr        'capacity needed for the secondary reserve requirements'
                 storing         'the definition of stored energy in the storage options'
                 storage_const   'storage in the first hour is equal to the storage in the last hour'
                 battery_capa
                 lake_res        'constraint on water for lake reservoirs'
                 stored_cap      'maximum energy that is stored in storage units'
                 storage_capa1   'the capacity with hourly charging relationship of storage'
                 biogas_const    'maximum energy can be produced by biogas'
*                 nuc_cf          'the yearly capacity factor of nuclear power plants should not pass 80%'
*                 nuc_up          'Nuclear power plant upward flexibility flexibility'
*                 nuc_down        'Nuclear power plant downward flexibility flexibility'
                 hydrogen_balance
*                 ccgt_cf         'the yearly capacity factor of CCGT'
                 reserves        'FRR requirement'
                 adequacy        'supply/demand relation'
                 obj             'the final objective function which is COST';

gene_vre(vre,h)..                GENE(vre,h)             =e=     CAPA(vre)*load_factor(vre,h);
gene_capa(tec,h)..               CAPA(tec)               =g=     GENE(tec,h);
batt_cap1..                      CAPA('battery1')        =e=     CAPACITY('battery1');
batt_cap4..                      CAPA('battery4')        =e=     CAPACITY('battery4')/4;
combustion1(h)..                 GENE('ocgt',h)          =e=     GENE('biogas1',h)*eta_ocgt;
combustion2(h)..                 GENE('ccgt',h)          =e=     GENE('biogas2',h)*eta_ccgt;
capa_frr(frr,h)..                CAPA(frr)               =g=     GENE(frr,h) + RSV(frr,h);
storing(h,h+1,str)..             STORED(str,h+1)         =e=     STORED(str,h) + STORAGE(str,h)*eta_in(str) - GENE(str,h)/eta_out(str);
storage_const(str,first,last)..  STORED(str,first)       =e=     STORED(str,last) + STORAGE(str,last)*eta_in(str) - GENE(str,last)/eta_out(str);
lake_res(m)..                    lake_inflows(m)         =g=     sum(h$(month(h) = ord(m)),GENE('lake',h))/1000;
stored_cap(str,h)..              STORED(str,h)           =l=     CAPACITY(str);
storage_capa1(str,h)..           S(str)                  =g=     STORAGE(str,h);
battery_capa(battery)..          S(battery)              =e=     CAPA(battery);
biogas_const..                   sum(h,GENE('biogas1',h)*eta_ocgt+GENE('biogas2',h)*eta_ccgt) =l=  max_biogas*1000;
*nuc_cf..                         sum(h,GENE('nuc',h))    =l=     CAPA('nuc')*cf_nuc*8760;
*nuc_up(h,h+1)..                  GENE('nuc',h+1) + RSV('nuc',h+1) =l= GENE('nuc',h) + ramp_rate*(CAPA('nuc')-GENE('nuc',h))   ;
*nuc_down(h,h+1)..                GENE('nuc',h+1) =g= GENE('nuc',h)*(1 - ramp_rate)   ;
hydrogen_balance(h)..            GENE('electrolysis',h)+GENE('hydrogen',h)=e= GENE('h2_ccgt',h)/eta_ccgt + H2_demand(h) + STORAGE('hydrogen',h);
*ccgt_cf..                        sum(h,GENE('ccgt',h)) =l=    CAPA('ccgt')*cf_ccgt*8760;
reserves(h)..                    sum(frr, RSV(frr,h))    =e=     sum(vre,epsilon(vre)*CAPA(vre))+ demand(h)*load_uncertainty*(1+delta);
adequacy(h)..                    sum(balance,GENE(balance,h))  =g=     demand(h) + sum(str_noH2,STORAGE(str_noH2,h))+GENE('electrolysis',h)/0.75;
obj..                            COST                    =e=     (sum(tec,(CAPA(tec)-capa_ex(tec))*capex(tec))+ sum(str,(CAPACITY(str)-capacity_ex(str))*capex_en(str))+sum(tec,CAPA(tec)*fOM(tec))+ sum(str,(S(str)-s_ex(str))*s_capex(str)+S(str)*s_opex(str)) + sum((tec,h),GENE(tec,h)*vOM(tec)))/1000;
*-------------------------------------------------------------------------------
*                                Initial and fixed values
*-------------------------------------------------------------------------------
CAPA.lo('phs') = capa_ex('phs');
CAPA.up('phs') = 7.2;
S.lo('phs') = s_ex('PHS');
S.up('phs') = 6.2;
CAPACITY.up('phs') = 135.5;
CAPA.up(vre) = capa_max(vre);
CAPA.fx('river')= capa_ex('river');
CAPA.fx('lake') = capa_ex('lake');
CAPACITY.lo('hydrogen') = capacity_ex('hydrogen');
*-------------------------------------------------------------------------------
*                                Model options
*-------------------------------------------------------------------------------
model EOLES_elec /all/;
*-------------------------------------------------------------------------------
option solvelink=0;
option RESLIM = 1000000;
option lp=CPLEX;
option Savepoint=1;
option solveopt = replace;
option limcol = 0;
option limrow = 0;
option SOLPRINT = OFF;
option solvelink=0;
$onecho > cplex.opt
$offecho
EOLES_elec.optfile=1; EOLES_elec.dictfile=2;
*-------------------------------------------------------------------------------
*                                Solve statement
*-------------------------------------------------------------------------------
$If exist EOLES_elec_p.gdx execute_loadpoint 'EOLES_elec_p';
parameter sumdemand      'the whole demand per year in TWh';
parameter dem_hydrogen;
parameter gene_tec(tec) 'Overall yearly energy generated by the technology in TWh';
parameter sumgene        'the whole generation per year in TWh';
parameter sum_FRR 'the whole yearly energy budgeted for reserves in TWh';
parameter reserve(frr) 'capacity allocated for reserve from each FRR tech in GW';
parameter nSTORAGE(str,h);
*Parameter lcoe(gen);
*parameter lcos(str);
parameter lcoe_sys1;
parameter lcoe_sys2;
parameter lcoh;
parameter str_loss 'yearly storage related loss in % of power production';
parameter lc 'load curtailment of the network';
parameter spot_price(h) 'marginal cost'    ;
parameter marginal_cost 'average value over the year of spot price in €/MWh';
parameter h2_price(h) ;
parameter h2_market;
parameter gas_price1(h) ; parameter gas_price2(h) ;
*parameter cf(gen) 'load factor of generation technologies';
parameter technical_cost 'the overall real cost of the system without considering carbon tax or remunerations in b€';
file hourly_generation1 /'outputs/EOLES_elecH2.csv' / ;
file summary1 /'outputs/EOLES_elecH2.csv' / ;
put hourly_generation1;
hourly_generation1.pc=5;
hourly_generation1.pw=32767;
put 'hour'; loop(tec, put tec.tl;) put 'demand', 'ElecStr1','ElecStr4','Pump','hydrogen','elec_market','gas_market1','gas_market2','h2_market'; put 'OK'/ ;
put summary1;
summary1.pc=5;
summary1.pw=32767;
put 'cost'; loop(tec, put tec.tl;) loop(tec,put tec.tl;)put 'LCOE1','LCOE2','LCOH','spot_elec','spot_hydrogen','str_loss','LC'/;
Solve EOLES_elec using lp minimizing COST;
sumdemand =  sum(h,demand(h))/1000;
dem_hydrogen = sum(h,H2_demand(h))/1000;
gene_tec(tec) = sum(h,GENE.l(tec,h))/1000;
sumgene = sum((gen,h),GENE.l(gen,h))/1000;
sum_FRR = sum((h,frr),RSV.l(frr,h))/1000;
reserve(frr) = smax(h,RSV.l(frr,h));
nSTORAGE(str,h) = 0 - STORAGE.l(str,h);
*lcoe(gen) = (CAPA.l(gen)*(fOM(gen)+capex(gen))+ gene_tec(gen)*vOM(gen)*1000)/gene_tec(gen);
*lcos(str) = (CAPA.l(str)*(fOM(str)+capex(str))+ gene_tec(str)*vOM(str)*1000 + S.l(str)*(s_capex(str)+s_opex(str))+ CAPACITY.l(str)*capex_en(str))/gene_tec(str);
lcoe_sys1 = cost.l*1000/sumgene;
*cf(gen) = gene_tec(gen)*1000/(8760*CAPA.l(gen));
str_loss = (sum((str,h),STORAGE.l(str,h))-sum(str,gene_tec(str)*1000))/(sumgene*10);
lc = ((sumgene - sumdemand - dem_hydrogen/0.75)*100/sumgene) - str_loss;
spot_price(h) = 1000000*adequacy.m(h);
gas_price1(h) = -1000000*combustion1.m(h);
gas_price2(h) = -1000000*combustion2.m(h);
h2_price(h) = 1000000*hydrogen_balance.m(h);
marginal_cost = sum(h,spot_price(h))/8760;
h2_market = sum(h,h2_price(h))/8760;
lcoh = (CAPA.l('electrolysis')*(capex('electrolysis')+fOM('electrolysis'))+sum(h,GENE.l('electrolysis',h)*(vOM('electrolysis')+spot_price(h)/1000))+capex_en('hydrogen')*CAPACITY.l('hydrogen'))*33.33/sum(h,GENE.l('electrolysis',h));
lcoe_sys2 = (cost.l-(lcoh*dem_hydrogen/33.33))*1000/sumdemand;
*-------------------------------------------------------------------------------
*                                Display statement
*-------------------------------------------------------------------------------
display cost.l;
display capa.l;
display gene_tec;
display sumdemand; display sumgene;
display lcoe_sys1; display lcoe_sys2; display lcoh;
display CAPACITY.l;
display lc; display str_loss; display marginal_cost;
*-------------------------------------------------------------------------------
*                                Output
*-------------------------------------------------------------------------------
put summary1;
summary1.pc=5;
put COST.l, loop(tec, put CAPA.l(tec);) loop(tec,put gene_tec(tec);)put lcoe_sys1,lcoe_sys2,lcoh, marginal_cost, h2_market,str_loss,LC /;
put hourly_generation1;
hourly_generation1.pc=5;
loop (h,
put h.tl; loop(tec, put GENE.l(tec,h);) put demand(h); put nSTORAGE('battery1',h),nSTORAGE('battery4',h), nSTORAGE('PHS',h), nSTORAGE('hydrogen',h), spot_price(h),gas_price1(h),gas_price2(h), h2_price(h); put 'OK'/
;);
*-------------------------------------------------------------------------------
*                                The End :D
*-------------------------------------------------------------------------------
