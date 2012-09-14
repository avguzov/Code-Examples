library(network)
library(msm)

final_data <- c()
for (g in c(1:10)){
	msize<-100
	A <- matrix(rbinom(msize*msize,1,1/sqrt(msize)),msize,msize)

	for (i in 1:(msize-1)){
		for(j in (i+1):nrow(A)){
			A[i,j] <- A[j,i]
		}
	}
	diag(A)<-0
	start_degree <- apply(A,1,sum)

	avec <- rtnorm(n=nrow(A),mean=.5,sd=.16, lower=0,upper=1)
	payout<-rtnorm(n=msize,mean=1,sd=.16, lower=.5,upper=1.5)
	salary<-payout
	for (z in c(1:50)){
		dvec <- (apply(A,1,sum))+1
		tvec <- (avec*payout)/dvec
		pom<-c()
		for(i in 1:msize){
			triads<-c()
			weights<-c()
			for(j in 1:(msize-1)){
				for(k in (j+1):msize){
					if((A[i,j]==1)&(A[i,k]==1)&(A[j,k]==1)){
						triads<-rbind(triads,c(i,j,k))
					}			
				}	
			}		 
			for(j in 1:msize){
				if((A[i,j]==1)&(length(triads)>0)){
					count<-0
					for(x in 1:nrow(triads)){
						for(y in 1:ncol(triads)){
							if(triads[x,y]==j){
								count<-count+1
								break
							}			
						}
					}
					weights<-c(weights,1+count)
				}
				else{
					weights<-c(weights,0)
				}	
			}
			pom<-rbind(pom,weights)
		}
		sumpom<-apply(pom,1,sum)
		for(q in 1:msize){	
			if (sumpom[q]==0) sumpom[q]<-1
		}
		pom<-(pom/(sumpom))* (avec * payout)

		for ( i in 1:msize){
			pvec <- c()
			for (j in 1:msize){
				if (A[j,i]==1){
					if(pom[j,i] < .5*tvec[i]){
						A[j,i] <- 0
						A[i,j] <- 0
					}
					else{
						pvec<-c(pvec,j)
					}
				}
			}
			for (j in 1:msize){
				if (A[j,i]==1){
					if(pom[j,i] > (tvec[i]+(.1)*(payout[i]-tvec[i]))){
						newlink <-	j
						while(newlink == j){
							newlink <- sample(pvec,1)
						}
						A[j,newlink] <- 1
						A[newlink,j] <- 1
					}	
				}
			}		
		}
		other<-apply(pom,2,sum)
		self<-c()
		for(n in 1:msize){
			if(other[n]==0){
				self<-c(self,payout[n])
			}
			else{
				self<-c(self,((1-avec[n])*payout[n]))
			}
		}
		payout<-(other+self)

	}

	#net1<- network(A, matrix.type='adjacency', directed = FALSE)

	##Plot the network
	#plot(net1)

	end_degree<-apply(A,1,sum)
	final <- cbind(avec, start_degree, end_degree, salary,payout)
	final_data<-rbind(final_data,final)
}
write.csv(final_data, file='C:\\Users\\Alec\\Documents\\My Work\\10-11\\Spring 2011\\Econ970\\model_4_data.csv')




