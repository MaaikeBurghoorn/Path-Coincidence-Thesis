#Load file
#Specify path before reading
results <- read.csv("path/results_run1.csv",TRUE)

#Convert factor columns to boolean columns
results$withNodes <- as.logical(results$withNodes)
results$suck.pheromone.from.border <- as.logical(results$suck.pheromone.from.border)

#---------------------------------------------

#Create dataframe
runNr <- mean <- stdDev <- stdErr <- lBound <- rBound <- SA <- RA <- -1
withNodes <- suckPheromone <- TRUE
dataCalc <- data.frame(runNr, withNodes, SA, RA, suckPheromone, mean, stdDev, stdErr, lBound, rBound)

#Sample size
n <- 10

#Calc mean, std, std error and CI
for (i in 1:(length(results$calcoverlap)/n)) {
  subset <- results[((i-1)*n + 1) : (i*n),7]
  av <- mean(subset)
  std <- sd(subset)
  error <- qt(0.95,df=n-1)*std/sqrt(n)
  left <- av - error
  right <- av + error
  row <- (i-1)*n + 1
  dataCalc <- rbind(dataCalc,c(i, results[row,2], results[row,3], results[row,4], results[row,5], av, std, error, left, right))
}

#Remove first row
dataCalc <- dataCalc[dataCalc$runNr != -1,]
dataCalc$withNodes <- as.logical(dataCalc$withNodes)
dataCalc$suckPheromone <- as.logical(dataCalc$suckPheromone)

#Write table to file
write.csv(dataCalc,file="path/file.csv",row.names=FALSE)

#---------------------------------------------

#Create Multiple Regression model

#All variables
allvars <- lm(calcoverlap ~ withNodes + sensor.angle + rotation.angle + suck.pheromone.from.border,data=results)


#Visualize Multiple Regression model
filename <- "c:/users/maaike/skydrive/uu/ki/jaar 3/scriptie/resultaten/run 1/results_run1.csv"
d <- read.csv(filename)

d$withNodes <- factor(d$withNodes)
d$suck.pheromone.from.border <- factor(d$suck.pheromone.from.border)
d$calcoverlap <- d$calcoverlap / 58081

d <- d[,-which(names(d) %in% c("X.run.number.", "X.step."))]
names(d) <- c("withNodes","SA","RA","suckPheromone","Coincidence")

#---------------------------------------------

#Copy d and add extra column 
dCopy <- d
dCopy$SA_RA <- with(dCopy, ifelse(SA==RA, "EQ", ifelse(SA>RA,"GT","LT")))


#op dCopy data

model.pm.copy <- lm(Coincidence ~ withNodes + SA + RA + suckPheromone + SA_RA, data=dCopy)
summary(model.pm.copy)

model.pm.copy <- step(model.pm.copy,
                      direction="backward",
                      trace=0) # Don't print the steps

summary(model.pm.copy)

#---------------------------------------------

model.pm <- lm(Coincidence ~ withNodes + SA + RA + suckPheromone, data=d)
summary(model.pm)

model.pm2 <- step(model.pm,
                 direction="backward",
                 trace=0) # Don't print the steps

summary(model.pm)


#---------------------------------------------
#Coincidence plotted against RA

library(visreg)
par(mfrow=c(1,1))

#withNodes levels
visreg(model.pm2, "RA", by="withNodes", strip.names=TRUE, overlay=TRUE, partial=FALSE)

#no levels
visreg(model.pm2, "RA", overlay=TRUE, partial=FALSE)

#suckPheromone levels
visreg(model.pm, "RA", by="suckPheromone", strip.names=TRUE, overlay=TRUE, partial=FALSE)

#LT/EQ/GT
visreg(model.pm.copy, "RA", by="SA_RA", overlay=TRUE, partial=FALSE)
