mTADA <- function(geneName = NULL,
                  ntrio1 = NULL,
                  ntrio2 = NULL,
                  p1 = NULL,
                  p2 = NULL,
                  dataDN1 = NULL, #data.matrix(sDN[, 1:2]), #array(sDN, dim = c(NN, NCdn)), ##De novo data
                  dataDN2 = NULL, #data.matrix(sDN[, 3:4]), #array(sDN, dim = c(NN, NCdn)), ##De novo data
                      mutRate1 = NULL, #data.matrix(muAll[, 1:2]), ##Mutation rate data
                      mutRate2 = NULL, #data.matrix(muAll[, 3:4]), ##Mutation rate data
                  hyperGammaMeanDN1 = NULL, #c(gDN1),
                      hyperGammaMeanDN2 = NULL, #c(gDN2),
                  beta.dn = NULL,
                       adjustHyperBeta = 0, #adjustHyperBeta0,
                        betaPars = c(6.7771073, -1.7950864, -0.2168248),
                        upperPi0 = 0.5, lowerPi0 = 0,
                        lowerHyperGamma = 1,
                        lowerGamma = 1,
                        lowerBeta = 1,
                        hyperBetaDN01 = NULL, #array(c(1, 1)),
                        hyperBetaDN02 = NULL, #array(c(1, 1)),
                  nIteration = 5000,
                  outSample = 1000,
                  nChain = 1,
                  printMessage = TRUE,
                  useMCMC = FALSE,
                  iSeed = NULL
    ){

    NCdn1 <- dim(dataDN1)[2]
    NCdn2 <- dim(dataDN2)[2]
    Ndn1 <- rep(ntrio1, NCdn1)
    Ndn2 <- rep(ntrio2, NCdn2)

    if (is.null(hyperBetaDN01))
        hyperBetaDN01 <- rep(1, NCdn1)
    if (is.null(hyperBetaDN02))
        hyperBetaDN02 <- rep(1, NCdn2)
                   
    mixDataKclasses <- list(NN = dim(dataDN1)[1], #Number of genes
                        NCdn1 = NCdn1, NCdn2 = NCdn2, 
                        Ndn1 = Ndn1, Ndn2 = Ndn2, 
                        dataDN1 = data.matrix(dataDN1),
                        dataDN2 = data.matrix(dataDN2),
                        hyperGammaMeanDN1 = hyperGammaMeanDN1,
                      hyperGammaMeanDN2 = hyperGammaMeanDN2, 
                      mutRate1 = data.matrix(mutRate1), 
                      mutRate2 = data.matrix(mutRate2), 
                        adjustHyperBeta = adjustHyperBeta,
                        betaPars = betaPars,
                        upperPi0 = upperPi0, lowerPi0 = lowerPi0,
                        lowerHyperGamma = lowerHyperGamma,
                        lowerGamma = lowerGamma,
                        lowerBeta = lowerBeta,
                        hyperBetaDN01 = hyperBetaDN01,
                        hyperBetaDN02 = hyperBetaDN02,
                        pi01 = p1,
                        pi02 = p2                      )

    library("rstan")
    library("locfit")
    if (is.null(iSeed))
      iSeed <- sample.int(.Machine$integer.max, 1)
    t1M <- min(p1, p2)

    initList = NULL
    for (ii in 1:nChain) {
        tempB <- runif(1, 0.01*t1M, 0.9*t1M)
        initList[[ii]] <- list(p12 = tempB) #alpha0 = log(tempB/(1 - tempB)))
        }
    initList

    message("===================\nBuilding the model\n=================\n")

    m1 = stan_model(model_code = DN2traits)
    message("===================\nRunning VB\n========================\n")
    if (useMCMC){
        message("\n=======Use MCMC===========\n")
        vb1 <- stan(model_code=DN2traits, data = mixDataKclasses,
                init = initList, iter = nIteration, chains = nChain, pars = c('p12', 'gammaMeanDN1'), 
                seed = iSeed)
    } else {
        message("\n=======Not use MCMC===========\n")        
    vb1 <- vb(object = m1, data = mixDataKclasses, pars = c('p12', 'gammaMeanDN1'),
          init = initList[[1]], iter = nIteration, seed = iSeed)

    }

    par2 = estimatePars(pars = c("p12", "gammaMeanDN1[1]"),
             mcmcResult = vb1)

    if (printMessage)
        print(par2)
 ########################Calculate PP
    g0 = rbind(rep(1, NCdn1 + NCdn2),
               c(hyperGammaMeanDN1, hyperGammaMeanDN2),
               c(hyperGammaMeanDN1, rep(1, NCdn2)),
               c(rep(1, NCdn1), hyperGammaMeanDN2))

    gamma.mean.dn = g0

    dnData = data.frame(dataDN1, dataDN2)
    muAll = data.frame(mutRate1, mutRate2)
    Ndn = c(Ndn1, Ndn2)

    if (is.null(beta.dn))
        beta.dn = matrix(rep(1, 4*(NCdn1 + NCdn2)), nrow = 4)
    par1 = par2[, 1]
    pBoth = par1['p12']
    p00 = c(1 -(p1 + p2 - pBoth), pBoth, p1 - pBoth, p2 - pBoth)
    prob0 = p00

    if (!(identical(g0, beta.dn))){
        message("\nMean gammas and betas have different dimension\n")
        print(g0)
        print(beta.dn)
    }
    
#    geneName = data[, 1]
    if (is.null(geneName))
        geneName = paste0("Gene", 1:dim(dnData)[1])
    x1 <- posProb.dn(dnData = dnData, muAll = muAll,
              gamma.mean.dn = gamma.mean.dn, Ndn = Ndn,
              prob0 = prob0, beta.dn = beta.dn)
#    xGroup <- apply(x1$PP[, c("NO", "FIRST", "SECOND", "BOTH")], 1,
 #                   function(x) which(x == max(x)) - 1)
    d11 <- data.frame(geneName = geneName, dnData, x1$PP) #, xGroup)

    pOut = p00[c(1, 3, 4, 2)]
    names(pOut) <- c("pNO", "pFIRST", "pSECOND", "pBOTH")
    return(list(probModel = pOut,
                pars = par2, data = d11, mcmcData = vb1))
    
}
