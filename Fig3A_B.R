#-----------------------------------------------------------------------------#
# Fig.3A and Fig.3B    Main program                                           #
# Modeling clindamycin and maleic hydrazide (neutral species) concentrations  #
# Bulk pH = 7, NO3- is the N source                                           #
# Lavoie M. 2018                                                              #
#-----------------------------------------------------------------------------#

rm(list=ls())

#------------------------------#
# Load packages                #
#------------------------------#

library(ReacTran)

#---------------------------------------#
# Calculations for clindamycin (Clind)  #
#---------------------------------------#

#--------------------------------------------#
# Calculations of K, kf, kb and D for Clind  #
#--------------------------------------------#
I <- 0.001

# Calculations of K
pKa_Clind <- 7.79   
Ka <- 10^-pKa_Clind      # clindH+ -> ClindH + H+, where ClindH is the neutral species and ClindH+ is protonated
K_Clind <- 1/Ka      # Thermodynamic equilibrium constant for the reaction : ClindH + H+ -> clindaH+
source("func_K_corr2_I.R")  # Loading the function for ionic strength correction of equilibrium constant (K0 to K1)
K_Clind1 <- K_corr2(K0=K_Clind, I=I, chargeA=0, chargeB=1, chargeC=1)$K1
K_Clind1
log10(K_Clind1)

# Calculations of kf and kb
kf_Clind <- 10^10.74 # in L mol-1 s-1 (diffusion controlled, Calculated with the Debye-Smoluchowski equation)
# Increasing or decreasing kf_Mal by up to 1000-fold does not change the results!
kb_Clind <- kf_Clind / K_Clind1         # in s-1
kb_Clind

# Diffusion coefficient (m^2/s)
source("func_D_Stokes_Einstein.R")
D_Clind <- D_coeff(T = 298, n = 0.89004, V = 327.2)$D2    
D_Clind <- D_Clind
# Increasing or decreasing D_Clind by 10-fold change the neutral clindamycin cell surface enrichment by less than 1%

# Converting units in m^3
kf_Clind <- kf_Clind / 1000       # Convert in m^3 mol-1 s-1
kb_Clind <- kb_Clind              # no conversion (s-1)
K_Clind1 <- K_Clind1 / 1000        # Convert in m^3/mol

#------------------------------#
#            MODEL             #
#------------------------------#

#--- Partial derivative equations

boundary_layer <- function(t, state, parms) {
  
  { with( as.list( c(t, state, parms) ), {
    
    # Reshape state variable as a 2D matrix
    S    <- matrix(nrow = X.grid$N, ncol = 7, data = state)
    
    # Initialize dC/dt matrix
    dCdt <- 0*S
    
    # Rate of change for CO2
    tran_1 <- tran.1D(C = S[,1], D = D, flux.up = F1, C.down = C[1], A = A.grid, dx = X.grid, full.output = T)
    prod1 <- (kb[1] * S[,4] + kb[2]) * S[,2]
    loss1 <- (kf[1] + kf[2] * S[,5]) * S[,1]
    dCdt[,1] <- tran_1$dC + prod1 - loss1
    
    # Rate of change for HCO3 
    tran_2 = tran.1D(C = S[,2], D = D, C.down = C[2], flux.up = 0, A = A.grid, dx = X.grid, full.output = T)
    prod2 = (kf[1] * S[,1]) + (kf[2] * S[,1] * S[,5]) + (kf[4] * S[,3] * S[,4]) + (kb[5] * S[,3]) 
    loss2 = (kb[1] * S[,4] * S[,2]) + (kb[2] * S[,2]) + (kb[4] * S[,2]) + (kf[5] * S[,2] * S[,5])
    dCdt[,2] = tran_2$dC + prod2 - loss2
    
    # Rate of change for CO3
    tran_3 = tran.1D(C = S[,3], D = D, C.down = C[3], flux.up = 0, A = A.grid, dx = X.grid, full.output = T)
    prod3 = (kb[4] * S[,2]) + (kf[5] * S[,2] * S[,5]) 
    loss3 = (kf[4] * S[,4] * S[,3]) + (kb[5] * S[,3])
    dCdt[,3] = tran_3$dC + prod3 - loss3
    # flux.up = NO3_H since NO3- is the N source
    # Rate of change for H
    tran_4 = tran.1D(C = S[,4], D = D, C.down = C[4], flux.up = NO3_H, A = A.grid, dx = X.grid, full.output = T)
    prod4 = (kb[4] - kb[1] * S[,4]) * S[,2] + (kf[1] * S[,1]) + kb[6]  
    loss4 = (kf[4] * S[,4] * S[,3]) + (kf[6] * S[,4] * S[,5])
    dCdt[,4] = tran_4$dC + prod4 - loss4
    
    # Rate of change for OH
    tran_5 = tran.1D(C = S[,5], D = D, C.down = C[5], flux.up = 0, A = A.grid, dx = X.grid, full.output = T)
    prod5 = (kb[2] * S[,2]) + (kb[5] * S[,3]) + kb[6]
    loss5 = (kf[2] * S[,1] * S[,5]) + (kf[5] * S[,2] * S[,5]) + (kf[6] * S[,4] * S[,5])
    dCdt[,5] = tran_5$dC + prod5 - loss5
    
    # Rate of change for ClindH
    tran_6 = tran.1D(C = S[,6], D = D_Clind, C.down = C[6], flux.up = 0, A = A.grid, dx = X.grid, full.output = T)
    prod6 = (kb_Clind * S[,7])
    loss6 = (kf_Clind * S[,6] * S[,4])
    dCdt[,6] = tran_6$dC + prod6 - loss6
    
    # Rate of change for ClindHplus
    tran_7 = tran.1D(C = S[,7], D = D_Clind, C.down = C[7], flux.up = F2, A = A.grid, dx = X.grid, full.output = T)
    prod7 = (kf_Clind * S[,6] * S[,4])
    loss7 = (kb_Clind * S[,7])
    dCdt[,7] = tran_7$dC + prod7 - loss7
    
    return(list(dCdt = dCdt))
  } )
  }
}

#------------------------------#
# Model grid definition        #
#------------------------------#

# Number of grid layer
N    <- 100

# Radius of the cell (m)
R    <- 30E-06

# Model grid setup 
X.grid <- setup.grid.1D(x.up = R, L = 20*R, N = N) # x.up = radius of the cell

# Interface area
A.grid <- setup.prop.1D(grid = X.grid, func = function(r) 4*pi*r^2)


#------------------------------#
# Model parameters             #
#------------------------------#
options(digits=15)
I <- I        # Ionic strength (M)

# Calculation of CO2 concentration at I = 0
pCO2 <- 10^-3.51    # CO2 partial presure (atm)
Kh <- 0.034    # Henry's constant (mol atm-1 L-1) at I =0 ; Correction of Kh at higher I can be neglected at low I (See Weiss, 1974)
CO2 <- pCO2 * Kh * 1000     # CO2 concentration (mol m-3)

# Fixed H+ and OH- concentrations at I = I (mol m-3)
source("func_activity_I.R") 
coeff1 <- coeff_act(charge = 1, I = I)$coeff_act
H <- 1E-04 * (1/coeff1)
OH <- 1E-04 * (1/coeff1)

# Calculations of HCO3- concentration at I = I (mol m-3)
K1 <- 10^6.35              # Thermodynamic equilibrium constant of H+ + HCO3- = CO2
source("func_K_corr2_I.R")  # Loading the function for ionic strength correction
K1_corr <- K_corr2(K0=K1, I=I, chargeA=1, chargeB=1, chargeC=0)
K1_corr
HCO3 <- (CO2 * 1000 * (1/K1_corr$K1))/H

# Calculations of CO32- concentration at I = I (mol m-3)
K2 <- 10^10.33             # Thermodynamic equilibrium constant of H+ + CO32- = HCO3-
K2_corr <- K_corr2(K0=K2, I=I, chargeA=1, chargeB=2, chargeC=1)
K2_corr
CO3 <- (HCO3 * 1000 * (1/K2_corr$K1)) / H

# Calculations of the neutral and charged Clind species
# K_Clind1 <- ClindHplus / (ClindH * H)   ----> ClindH * K_Clind1 - (1 / H) * ClindHplus  = 0
# ClindH + ClindHplus <- total_Clind
# System matrix 
total_Clind <- 1E-09 * 1000    # in mol / m^3
mat1 <- matrix(c(K_Clind1, -1/H, 1, 1), nrow=2, ncol=2, byrow = T)
mat2 <- matrix(c(0, total_Clind), nrow=2, ncol=1)
out <- solve(mat1,mat2)
ClindH <- out[1]
ClindHplus <- out[2]

# Concentration of CO2,HCO3,CO3,H,OH, ClindH, ClindHplus in bulk solution (mol m^-3) at I = I, T=25 ?C and a given pH
C <- c(CO2, HCO3, CO3, H, OH, ClindH, ClindHplus)

# Growth rate (u in d-1) Chrysophyte
u <- 1.12 * ((R*1E+06)^-0.75)

# Uptake flux of CO2 by the cell (mol m-^2 s^-1) Chrysophyte
F1 <- -(23230/3) * R * u / 86400

# Permeability of Clind in the boundary layer
P_bound_Clind <- D_Clind/R   # in m s-1
source("func_Pm_Kow.R")  # Loading the function for Pm calculation

# Permeability of Clind in cell membranes
Pm_Clind <- Pm_Xiang(Kow = 10^1.83, V = 327.2, D = D_Clind * 10000)$Pm_a0 # Pm in cm s-1 
Pm_Clind <- Pm_Clind / 100
Papp_Clind <- 1 / ( (1 / P_bound_Clind) + (1 / Pm_Clind) )

# F2 or Clind uptake rate could be divided by 10^6 or increase 100-fold and the MalH concentration profile will not change
F2 <- - Papp_Clind * ClindH
ratioClind <- P_bound_Clind / Pm_Clind

# Acido-basic reactions and NO3- assimilation
# With a Redfield ratio C:N of 106: 16, for each mol C assimilated, 0.15 mol H+ is removed from the medium if NO3- is the N source 
NO3_H <- 0.15 * F1

# Diffusion coefficient of CO2,... (m^2 s^-1)
D  <- 1.18E-09

# Rate constants at I=0
kb_I0 <- c(7.88029840776055E+01, 1.8E-04, NA, 6.13540983937499, 6.54216399387684E+05, 1.4)     # m^3 mol^-1 s^-1; s^-1; ; s^-1; s^-1; mol m^-3 s^-1
kf_I0 <- c(3.52E-02, 8.04030465871734, NA, 1.31172736401427E+08, 3.06E+06, 1.4E+08)           # s-^1; m^3 mol^-1 s^-1; ; m^3 mol^-1 s^-1; m^3 mol^-1 s^-1; m^3 mol^-1 s^-1

source("func_k_rate_cst_corr2_I.R")  # Load the function converting rate constant at a given I
kwat_I0 <- 1E-14       # Ion product of water at T=25 C
kwat <- kwat_I0 / (coeff1 * coeff1)    # Conditional ion product of water
kb1 <- k_corr2(k0 = kb_I0[1], I = I, chargeA = 1, chargeB = 1, chargeC = 0)$k1 # HCO3- + H+ -> CO2
kb1
kf1 <- 1000* kb1/K1_corr$K1   # CO2 + H2O -> HCO3- + H+
kf1
kf2 <- k_corr2(k0 = kf_I0[2], I = I, chargeA = 0, chargeB = 1, chargeC = 1)$k1 # CO2 + OH- -> HCO3-
kf2
kb2 <- kf2 * K1_corr$K1 * kwat * 1000 # HCO3- -> CO2 + OH-
kb2
kf4 <- k_corr2(k0 = kf_I0[4], I = I, chargeA = 2, chargeB = 1, chargeC = 1)$k1 # CO32- + H+ -> HCO3-
kf4
kb4 <- kf4 * (1/(K2_corr$K1 / 1000))    # HCO3- -> CO32- + H+
kb4
kf5 <- k_corr2(k0 = kf_I0[5], I = I, chargeA = 1, chargeB = 1, chargeC = 2)$k1  # HCO3- + OH- <-> CO32- + H2O   
kf5
kb5 <- kf5 * kwat * 1000 * 1000 * K2_corr$K1 / 1000      # CO32- + H2O -> HCO3- + OH-
kb5
kf6 <- k_corr2(k0 = kf_I0[6], I = I, chargeA = 1, chargeB = 1, chargeC = 0)$k1  # H+ + OH- -> H2O    
kf6
kb6 <- kf6 * kwat * 1000 * 1000
kb6

# Rate constants at I = I
kb <- c(kb1, kb2, NA, kb4, kb5, kb6)  
kf <- c(kf1, kf2, NA, kf4, kf5, kf6)

# Define parameters + grid definition vector
parms <- list(NO3_H=NO3_H, C=C, F1=F1, D=D, D_Clind=D_Clind, kb=kb, kf=kf, X.grid=X.grid, A.grid=A.grid)


#------------------------------#
# Model solution               #
#------------------------------#

# Numerical solution at steady state 

Cini <- matrix(C, nrow=N, ncol=7, byrow=T)

boundary <- steady.1D(y = Cini, func = boundary_layer, pos = TRUE, atol=1E-8, parms = parms, nspec = 7, names = c('CO2','HCO3','CO3','H','OH','ClindH','ClindHplus'))


#------------------------------#
# Plotting output              #
#------------------------------#

# Using S3 plot method of package rootSolve'

plot(boundary, grid = X.grid$x.mid, xlab = 'distance from centre, m', ylab = 'mol/m3', main = c('CO2', 'HCO3', 'CO3', 'H', 'OH','ClindH','ClindHplus'), ask = F, mfrow = c(1,1))

#---------------------------------------------------------------------------------------------------------------#
# Plot of the absolute Clind concentrations in the boundry layer overlayed with thermodynamic prediction        #
#---------------------------------------------------------------------------------------------------------------#

bmat <- unlist(boundary$y)
bmat1 <- as.matrix(bmat)
bmat1[,6]      # ClindH concentration
plot(X.grid$x.mid, bmat1[,6], type = "p", lty = 1, xlab = "radial distance", ylab = "Concentration of ClindH")   # Plot of ClindH as a function of radial distance

bmat1[,7]      # ClindH+ concentration
bmat1[,4]      # H+ concentration

# Calculation of neutral ClindH at equilibrium (using K_Clind1, ClindHplus and H+ concentration)
ClindH_mat <- (bmat1[,7] / (K_Clind1 * bmat1[,4]))
lines(X.grid$x.mid, ClindH_mat, type = "l", lty = 1)
# Kclind 1 : ClindH + H+ -> clindaH+
# ClindH+ / (ClindH * H) = KClind1    --> ClindH+ / (KClind1 * H) = ClindH

# Relative enrichment of the neutral clindamycin species as a function of radial distance from the cell center
ClindH_res <- bmat1[,6]   # renaming the matrix
ClindHenrich <- ClindH_res / ClindH

# Equilibrium concentration of the neutral clindamycin species as a function of radial distance from the cell center
ClindH_eq <- ClindH_mat / ClindH

#----------------------------------------------------------------------------------#
# Fig.3B                                                                           #
# Modeling Maleic hydrazide (neutral species) concentrations in the boundary layer #
# bulk pH = 7 , NO3- is the N source                                               #
# Lavoie M. 2018                                                                   #
#----------------------------------------------------------------------------------#

#---------------------------------#
# Calculations of K, kf, kb and D  #
#---------------------------------#
I <- 0.001

# Calculations of K
pKa_Maleic <- 5.64
Ka <- 10^-pKa_Maleic      
K_Mal <- 1/Ka      # Thermodynamic equilibrium constant for the reaction : Mal- + H+ -> MalH, where Mal- is the charged speies and MalH is the neutral species
source("func_K_corr2_I.R")  # Loading the function for ionic strength correction of equilibrium constant (K0 to K1)
K_Mal1 <- K_corr2(K0=K_Mal, I=I, chargeA=1, chargeB=1, chargeC=0)$K1
K_Mal1
log10(K_Mal1)

# Calculations of kf and kb
kf_Mal <- 10^10.53  # in L mol-1 s-1 (calculated with the Debye-Smoluchowski equation) (assumed diffusion controlled)
# Increasing or decreasing kf_Mal by up to 1000-fold does not change the results!
kb_Mal <- kf_Mal / K_Mal1         # in s-1
kb_Mal

# Diffusion coefficient (m^2/s)
source("func_D_Stokes_Einstein.R")
D_Mal <- D_coeff(T = 298, n = 0.89004, V = 98)$D2     # 98
D_Mal <- D_Mal
# Changing D_Mal by 10-fold does not change the MalH profile

# Converting units in m^3
kf_Mal <- kf_Mal / 1000       # Convert in m^3 mol-1 s-1
kb_Mal <- kb_Mal              # no conversion (s-1)
K_Mal1 <- K_Mal1 / 1000        # Convert in m^3/mol

#------------------------------#
#            MODEL             #
#------------------------------#

#--- Partial derivative equations

boundary_layer <- function(t, state, parms) {
  
  { with( as.list( c(t, state, parms) ), {
    
    # Reshape state variable as a 2D matrix
    S    <- matrix(nrow = X.grid$N, ncol = 7, data = state)
    
    # Initialize dC/dt matrix
    dCdt <- 0*S
    
    # Rate of change for CO2
    tran_1 <- tran.1D(C = S[,1], D = D, flux.up = F1, C.down = C[1], A = A.grid, dx = X.grid, full.output = T)
    prod1 <- (kb[1] * S[,4] + kb[2]) * S[,2]
    loss1 <- (kf[1] + kf[2] * S[,5]) * S[,1]
    dCdt[,1] <- tran_1$dC + prod1 - loss1
    
    # Rate of change for HCO3 
    tran_2 = tran.1D(C = S[,2], D = D, C.down = C[2], flux.up = 0, A = A.grid, dx = X.grid, full.output = T)
    prod2 = (kf[1] * S[,1]) + (kf[2] * S[,1] * S[,5]) + (kf[4] * S[,3] * S[,4]) + (kb[5] * S[,3]) 
    loss2 = (kb[1] * S[,4] * S[,2]) + (kb[2] * S[,2]) + (kb[4] * S[,2]) + (kf[5] * S[,2] * S[,5])
    dCdt[,2] = tran_2$dC + prod2 - loss2
    
    # Rate of change for CO3
    tran_3 = tran.1D(C = S[,3], D = D, C.down = C[3], flux.up = 0, A = A.grid, dx = X.grid, full.output = T)
    prod3 = (kb[4] * S[,2]) + (kf[5] * S[,2] * S[,5]) 
    loss3 = (kf[4] * S[,4] * S[,3]) + (kb[5] * S[,3])
    dCdt[,3] = tran_3$dC + prod3 - loss3
    # flux.up = NO3_H since NO3- is the N source
    # Rate of change for H
    tran_4 = tran.1D(C = S[,4], D = D, C.down = C[4], flux.up = NO3_H, A = A.grid, dx = X.grid, full.output = T)
    prod4 = (kb[4] - kb[1] * S[,4]) * S[,2] + (kf[1] * S[,1]) + kb[6]  
    loss4 = (kf[4] * S[,4] * S[,3]) + (kf[6] * S[,4] * S[,5])
    dCdt[,4] = tran_4$dC + prod4 - loss4
    
    # Rate of change for OH
    tran_5 = tran.1D(C = S[,5], D = D, C.down = C[5], flux.up = 0, A = A.grid, dx = X.grid, full.output = T)
    prod5 = (kb[2] * S[,2]) + (kb[5] * S[,3]) + kb[6]
    loss5 = (kf[2] * S[,1] * S[,5]) + (kf[5] * S[,2] * S[,5]) + (kf[6] * S[,4] * S[,5])
    dCdt[,5] = tran_5$dC + prod5 - loss5
    
    # Rate of change for Mal
    tran_6 = tran.1D(C = S[,6], D = D_Mal, C.down = C[6], flux.up = 0, A = A.grid, dx = X.grid, full.output = T)
    prod6 = (kb_Mal * S[,7])
    loss6 = (kf_Mal * S[,6] * S[,4])
    dCdt[,6] = tran_6$dC + prod6 - loss6
    
    # Rate of change for MalH
    tran_7 = tran.1D(C = S[,7], D = D_Mal, C.down = C[7], flux.up = F2, A = A.grid, dx = X.grid, full.output = T)
    prod7 = (kf_Mal * S[,6] * S[,4])
    loss7 = (kb_Mal * S[,7])
    dCdt[,7] = tran_7$dC + prod7 - loss7
    
    return(list(dCdt = dCdt))
  } )
  }
}

#------------------------------#
# Model grid definition        #
#------------------------------#

# Same than for clindamycin

#------------------------------#
# Model parameters             #
#------------------------------#

# I, u, C and N uptake rate and all parameters related to carbonate equilibrium are the same than for clindamycin

# Calculations of the neutral (MalH) and charged species (Mal)
# K_Mal1 <- MalH / (Mal * H)   ----> Mal * K_Mal1 - (1 / H) * MalH  = 0
# Mal + MalH <- total_Mal
# System matrix 
total_Mal <- 1E-09 * 1000    # in mol / m^3
mat1 <- matrix(c(K_Mal1, -1/H, 1, 1), nrow=2, ncol=2, byrow = T)
mat2 <- matrix(c(0, total_Mal), nrow=2, ncol=1)
out <- solve(mat1,mat2)
Mal <- out[1]
MalH <- out[2]

# Maximum diffusive flux of MalH
#F2 <- 1.1 * - (total_Mal * D_Mal) / R     # or Jmax = P_apparent * (delta conc), where 1/P_apparent = 1/Pboundary + 1 /Pm
# where D_Mal is in m^2/s and R is in m and MalH is in m^3
# P_boundary <- D_Mal/R   # P_boundary is equal to 3.6 x 10-3 cm/s for R = 20 um, which is close to the Pm of water (3.4 x 10-3 cm/s, Walter and Gutknecht, 1986). Since the Pm of hydrophobic contaminant is expected to be >> Pm of water, thus, the uptake will be limited by the transport in the boundary layer, which will dictate the uptake rate (i.e., maximum diffusive flux should be close to uptake flux). Note that the increase in molecular volume for some PBDE-OH or large antibiotics, which decreases Pm (Xiang and Andersen, ), should not counteract the increasing trend in Pm as Kow dramatically increases. Moreover, the increases in molecular volume will decrease D in the boundary layer too and hence, would further increase diffusive limitation of uptake.
# Note also that at acidic pH, tighter package in the phospholipid may strongly decrease the uptake rate and , in this case, the uptake rate would not be limited or partially limited by diffusion.

# Uptake flux of MalH (non-diffusion-limited, Pm << Pboundary)
# There is no depletion of MalH at the surface, F2 is negligible

# Maleic hydrazide permeability in the boundary layer
P_bound_Mal <- D_Mal/R   # in m s-1
source("func_Pm_Kow.R")  # Loading the function for Pm calculation

# Membrane permeability
Pm_Mal <- Pm_Xiang(Kow = 0.72, V = 72.7, D = D_Mal * 10000)$Pm_a0 # Pm in cm s-1 
Pm_Mal <- Pm_Mal / 100
Papp_Mal <- 1 / ( (1 / P_bound_Mal) + (1 / Pm_Mal) )

# F2 (uptake flux of Maleic hydrazide) could be divide by 10^6 or increase 100-fold and the MalH concentration profile will not change
# Because Pm << Pbound and [MalH] is buffered by [Mal]-
F2 <- - Papp_Mal * MalH
ratioMal <- P_bound_Mal / Pm_Mal

# Define parameters + grid definition vector
parms <- list(NO3_H=NO3_H, C=C, F1=F1, D=D, D_Mal=D_Mal, kb=kb, kf=kf, X.grid=X.grid, A.grid=A.grid)


#------------------------------#
# Model solution for Mal       #
#------------------------------#

# Numerical solution at steady state 

Cini <- matrix(C, nrow=N, ncol=7, byrow=T)

boundary <- steady.1D(y = Cini, func = boundary_layer, pos = TRUE, atol=1E-8, parms = parms, nspec = 7, names = c('CO2','HCO3','CO3','H','OH','Mal','MalH'))


#-----------------------------------------------#
# Plotting output for Clind and MA (Fig.3)      #
#-----------------------------------------------#

# Using S3 plot method of package rootSolve'

plot(boundary, grid = X.grid$x.mid, xlab = 'distance from centre, m', ylab = 'mol/m3', main = c('CO2', 'HCO3', 'CO3', 'H', 'OH','Mal','MalH'), ask = F, mfrow = c(1,1))

# Plot of the data overlayed with thermodynamic prediction
bmat <- unlist(boundary$y)
bmat1 <- as.matrix(bmat)
bmat1[,7]      # MalH concentration
plot(X.grid$x.mid, bmat1[,7], type = "p", lty = 1, xlab = "radial distance", ylab = "Concentration of MalH")   # Plot of MalH as a function of distance

bmat1[,6]      # Mal concentration
bmat1[,4]      # H+ concentration

# Calculation of MalH at thermodynamic equilibrium (using K_Mal1, Mal and H+ concentration)
MalH_mat <- K_Mal1 * (bmat1[,6] * bmat1[,4])
lines(X.grid$x.mid, MalH_mat, type = "l", lty = 1)
# K_Mal1 = MalH / (Mal * H)
# MalH = K_Mal1 * (Mal * H)

# Calculations of MalH enrichment as a function of radial distance from the cell center
MalH_res <- bmat1[,7]
MalHenrich <- MalH_res / MalH

# Calculations of MalH at equilirbium
MalH_eq <- MalH_mat / MalH

# Plots of the relative enrichment in the neutral Clind (Fig.3A) and MA (Fig3.B) species (r = 30 um, NO3- is the N source)
tiff("Fig3AB.tiff", res = 100)
oldpar <- par(mfrow=c(2,1), mar=c(0,0,0,0), oma = c(4.1,4,4,0.4), las=1) 

# Panel A : Neutral Mal (MalH) concentrations
plot(X.grid$x.mid*1E+06 - 30, MalHenrich, type = "p", pch = 15, lty = 1, xaxt = "n",  xlim = c(0,100), ylim = c(0,1.02))   # Plot of MalH as a function of distance from cell surface
lines(X.grid$x.mid*1E+06 - 30, MalH_eq, type = "l", lty = 1)
mtext(text = "A", side = 3, adj = 0.05, line = -1.4, font = 2)
legend("bottom", legend= c("Neutral Mal", "Neutral Clind"), pch = c(15, 17), cex = 0.9)

# Panel B : Neutral Clind (ClindH) concentrations
plot(X.grid$x.mid*1E+06 - 30, ClindHenrich, type = "p", pch = 17, lty = 1, xlim = c(0,100), ylim = c(0,5.4))   # Plot of ClindH as a function of distance from cell surface
lines(X.grid$x.mid*1E+06 - 30, ClindH_eq, type = "l", lty = 1)
mtext(text = "B", side = 3, adj = 0.05, line = -1.4, font = 2)
mtext(text = "relative change", side = 2, line = 2.6, outer=TRUE, las=0)
mtext(text = expression(paste(" distance from cell surface (", mu, "m)")), side = 1, line = 3, font = 2, outer=TRUE, las=1)


par(oldpar)
dev.off()

#-----------------------------#
# References                  #
#-----------------------------#
# Martell, A. E., Smith, R. M., Motekaitis, R. J. 2004. NIST critical stability constants of metal complexes, version 8. National Institute of Standards and Technology. Gaithersburg, MD. In Gaithersburg, MD, 2004.
# Weiss, R.F. 1974. Carbon dioxide in water and seawater : The solubility of a non-ideal gas. Marine Chemistry 2 : 203-215
