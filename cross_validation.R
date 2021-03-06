##### code copyright July 2015 
##### written by Oliver Haimson, with Michael Madaio, Xiang Cheng and Wenwen Zhang
##### on behalf of Data Science for Social Good - Atlanta
##### for Atlanta Fire Rescue Department
##### contact: ohaimson@uci.edu

cat("Running...\n\n")

# you only need to install these packages once, but you need to load them every time you run the code
#install required packages 
if ("kernlab" %in% rownames(installed.packages()) == FALSE) {suppressMessages(install.packages("kernlab"))}
if ("ROCR" %in% rownames(installed.packages()) == FALSE) {suppressMessages(install.packages("ROCR"))}

#load required packages
suppressWarnings(suppressMessages(library(kernlab)))
suppressWarnings(suppressMessages(library(ROCR)))



## Create data frame of independent variables for model ########

IV = data.frame(NPU, SiteZip, Submarket1, TAX_DISTR, NBHD, ZONING_NUM, building_c, PROP_CLASS, Existing_p, PropertyTy, secondaryT, LUC, Taxes_Per_, Taxes_Tota, TOT_APPR, VAL_ACRES, For_Sale_P, Last_Sale1, yearbuilt, year_reno, Lot_Condition, Structure_Condition, Sidewalks, Multiple_Violations,  Vacancy_pc, Total_Avai, Percent_Le, LandArea_a, totalbuild, avg_sf, Floorsize, BldgSF, LotSize, Style, stories, STRUCT_FLR, num_units, LIV_UNITS, UNIT_NUM, construct_, Sprinklers, Star_Ratin, Market_Seg, Bedrooms, Bathrooms, Owner_Name, huden10, empden10, entro10, foursqmi10, ViolentCrime_Den, PropertyCrime_Den, Pct_white, pct_blk, owner_distance, owner_public, Multiple_A, Inspection)



################################################################################
## 
## PERFORM 10-FOLD CROSS VALIDATION ON THE MODEL, TO SEE HOW WELL IT DOES AND
## HOW MUCH OVERFITTING IS OCCURRING 
##
################################################################################

# Here you can adjust how many folds you want to run. Cross-validation takes a long time to run, so only run 10 folds if you have some time to spare. 
# Plotting for ROC curve only works if folds is a multiple of 5
folds = 10
accuracyList = c()
truePosList = c()
trueNegList = c()
falsePosList = c()
falseNegList = c()
AUCList = c()
alist = c(); blist = c(); clist = c(); dlist = c()

# Split the data into k folds
testSize = floor((1/folds)*dim(IV)[1])
possibleIndices = c(1:dim(IV)[1])
testIndices = data.frame(matrix(ncol=0, nrow=testSize))

for (i in 1:folds) {
	test_ind = sample(possibleIndices, size=testSize)
	testIndices = data.frame(testIndices, test_ind)
	possibleIndices = possibleIndices[! possibleIndices %in% testIndices[,i]]
}

# Set up the window to plot the ROC curves for each fold
# This only works if folds is a multiple of 5
dev.new(width=11, height=folds/2)
par(mfrow=c(folds/5, 5))

# Run the cross-validation
for (i in 1:folds) {	
	
	# training
	test_ind = testIndices[,i]

	test = IV[test_ind,]
	train = IV[-test_ind,]
	
	testFire = gfire[test_ind]
	trainFire = gfire[-test_ind]
	
	trFit <- ksvm(trainFire~., data=train)

	# testing
	pred <- predict(trFit, test, type="response")

	predictions = pred
	predictions[pred >= .025] <- 1
	predictions[pred < .025] <- 0
	
	# Calculate the AUC and plot the ROC curve (these are some metrics for seeing how well the model did).

	# AUC 
	predScore <- prediction(predictions, testFire)
	auc.tmp <- performance(predScore, "auc")
	auc <- as.numeric(auc.tmp@y.values)
	AUCList = append(AUCList, auc)
		
	#ROC curve
	perf <- performance(predScore, measure = "tpr", x.measure = "fpr")
	plot(perf, lwd=2, main=paste("Fold ", i, ", AUC = ", round(auc,digits=4), sep=""))

	# test set metrics
	t = table(testFire, predictions)
	a = t[1]; b = t[3]; c = t[2]; d = t[4]
	truePos = d/(c+d)
	trueNeg = a/(a+b)
	falsePos = b/(a+b)
	falseNeg = c/(c+d)
	accur = (a+d)/(a+b+c+d)
	cat(paste("\nFOLD ", i, ":\n\n", sep="")); print(t); cat("\n"); cat(paste("accuracy: ", round(accur,digits=2))); cat("\n"); cat(paste("true positive rate: ", round(truePos,digits=4))); cat("\n"); cat(paste("true negative rate: ", round(trueNeg,digits=4))); cat("\n"); cat(paste("AUC: ", round(auc,digits=4))); cat("\n\n");
	
	
	accuracyList = append(accuracyList, accur)
	truePosList = append(truePosList, truePos)
	trueNegList = append(trueNegList, trueNeg)
	falsePosList = append(falsePosList, falsePos)
	falseNegList = append(falseNegList, falseNeg)
	alist = append(alist, a); blist = append(blist, b); clist = append(clist, c); dlist = append(dlist, d)

}

testAvgAccuracy = mean(accuracyList)
testAvgtruePos = mean(truePosList)
testAvgtrueNeg = mean(trueNegList)
testAvgfalsePos = mean(falsePosList)
testAvgfalseNeg = mean(falseNegList)
testAvgAUC = mean(AUCList)
aAvg = mean(alist); bAvg = mean(blist); cAvg = mean(clist); dAvg = mean(dlist)


## Plot the confusion matrix of the average results as a heat map ########
dev.new(width=6, height=6)
par(mar=c(5,5,2,2))

mat = matrix(c(testAvgfalsePos, testAvgtrueNeg, testAvgtruePos, testAvgfalseNeg), ncol=2)
image(mat, axes=F, cex.lab=1.8, ylab="Actual", xlab="Predicted")
mtext(c("0","1"), las=1, side=2, adj=2, outer=F, at=c(0,1), cex=1.8)
mtext(c("0","1"), las=1, side=1, padj=1, outer=F, at=c(0,1), cex=1.8)
text(1,1,paste("true positives\n", "(had fire;\n predicted fire)\n","\n", "n =", round(dAvg,digits=0), "\n", round(testAvgtruePos,digits=4)), cex=1.6, col="white")
text(0,0,paste("true negatives\n", "(no fire;\n predicted no fire)\n","\n", "n =", round(aAvg,digits=0), "\n", round(testAvgtrueNeg,digits=4)), cex=1.6, col="white")
text(0,1,paste("false negatives\n", "(had fire;\n predicted no fire)\n","\n","n =", round(cAvg,digits=0), "\n", round(testAvgfalseNeg,digits=4)), cex=1.6)
text(1,0,paste("false positives\n", "(no fire;\n predicted fire)\n","\n","n =", round(bAvg,digits=0), "\n", round(testAvgfalsePos,digits=4)), cex=1.6)


## See how well the model did on average, and print out a table of the results ########
accuracyList = append(accuracyList, testAvgAccuracy)
truePosList = append(truePosList, testAvgtruePos)
trueNegList = append(trueNegList, testAvgtrueNeg)
falsePosList = append(falsePosList, testAvgfalsePos)
falseNegList = append(falseNegList, testAvgfalseNeg)
AUCList = append(AUCList, testAvgAUC)

results = data.frame((c(1:folds, "TEST AVERAGE:")), accuracyList, AUCList, truePosList, trueNegList, falsePosList, falseNegList)
colnames(results) <- c("fold", "accuracy", "AUC", "true positive rate", "true negative rate", "false positive rate", "false negative rate")
print(results, row.names = FALSE)


cat("\n\nDone")