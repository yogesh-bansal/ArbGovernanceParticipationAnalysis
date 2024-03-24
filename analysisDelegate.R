## Load Libraries
library(ggplot2)
library(lubridate)
library(hrbrthemes)
library(reshape2)

## Load Data
snap_props <- readRDS("ArbSnapshotData/Proposals.RDS")
snap_votes <- readRDS("ArbSnapshotData/Votes.RDS")
tally_props <- readRDS("ArbTallyData/Proposals.RDS")
tally_votes <- readRDS("ArbTallyData/Votes.RDS")
del_data <- readRDS("ArbTallyData/delegatesdf.RDS")
del_list <- del_data$Address[del_data$delegatorsCount>1 & del_data$votesCount>10^18]

######################################################
## Plot 2
## Unique Voters over time
######################################################
## Snapshot
votes_gdf_sn <- data.frame(
							DateTime = as_datetime(snap_props$created),
							Platform = "Snapshot",
							Votes = sapply(snap_props$id,function(x,tdata,del_list) sum(unique(tdata$voter[tdata$prop_id==x]) %in% del_list),tdata=snap_votes,del_list=del_list)
				)
votes_gdf_tal <- data.frame(
							DateTime = as_datetime(tally_props$block),
							Platform = "Tally",
							Votes = sapply(tally_props$id,function(x,tdata,del_list) sum(unique(tdata$voter[tdata$id==x]) %in% del_list),tdata=tally_votes,del_list=del_list)
				)
votes_gdf_tal <- votes_gdf_tal[order(votes_gdf_tal$DateTime),]
votes_gdf <- rbind(votes_gdf_sn,votes_gdf_tal)
rownames(votes_gdf) <- NULL
p2 <- ggplot(votes_gdf, aes(x=DateTime, y=Votes,group=Platform,color=Platform)) +
		geom_line() + 
		theme_ipsum() +
		xlab("")+
		ylab("Number of Votes")+
		ggtitle("Number of Unique Delegates Votes on Proposals over Time",subtitle = "Delegate is > 1ARB Voting power and minimum 2 delegators ") +
		ylim(0,800)
ggsave("~/Downloads/p2Delegate.jpg",p2,width=10,height=6)
######################################################
######################################################


######################################################
## Plot 3
## New Users over time
######################################################
## Snapshot
snap_prop_chron <- snap_props[order(snap_props$created),c("created","id")]
users_new_sn <- data.frame(
							DateTime = as_datetime(snap_prop_chron$created),
							Proposal = snap_prop_chron$id,
							Platform = "Snapshot",
							PastUsers = NA,
							NewUsers = NA
				)
users_old <- character()
for(idx in 1:nrow(users_new_sn))
{
	cprop <- users_new_sn$Proposal[idx]
	cusers <- unique(snap_votes$voter[snap_votes$prop_id==cprop])
	cdusers <- cusers[cusers %in% del_list]
	users_new_sn$PastUsers[idx] <- sum(cdusers%in%users_old)
	users_new_sn$NewUsers[idx] <- length(cdusers) - users_new_sn$PastUsers[idx]
	users_old <- unique(c(users_old,cdusers))
	message(idx)
}

## Tally
tally_prop_chron <- tally_props[order(as_datetime(tally_props$block)),c("block","id")]
users_new_tal <- data.frame(
							DateTime = as_datetime(tally_prop_chron$block),
							Proposal = tally_prop_chron$id,
							Platform = "Tally",
							PastUsers = NA,
							NewUsers = NA
				)
users_old <- character()
for(idx in 1:nrow(users_new_tal))
{
	cprop <- users_new_tal$Proposal[idx]
	cusers <- unique(tally_votes$voter[tally_votes$id==cprop])
	cdusers <- cusers[cusers %in% del_list]
	users_new_tal$PastUsers[idx] <- sum(cdusers%in%users_old)
	users_new_tal$NewUsers[idx] <- length(cdusers) - users_new_tal$PastUsers[idx]
	users_old <- unique(c(users_old,cdusers))
	message(idx)
}
users_new <- rbind(users_new_sn,users_new_tal)
users_newlong <- rbind(
						cbind(users_new[,1:3],Type="Previous Delegates",Users=users_new$PastUsers),
						cbind(users_new[,1:3],Type="New Delegates",Users=users_new$NewUsers)
					)
p3 <- ggplot(users_newlong, aes(x=DateTime, y=Users, fill=Type)) + 
		geom_area(alpha=0.6 , size=.5, colour="white") +
		theme_ipsum() + 
		xlab("")+
		ylab("Number of Voters")+
		ggtitle("Number of New Delegate Voters vs Existing Delegate Voters over Time",subtitle = "Delegate is > 1ARB Voting power and minimum 2 delegators ")+
		facet_wrap(~Platform)
ggsave("~/Downloads/p3Delegate.jpg",p3,width=12,height=6)
######################################################
######################################################

######################################################
## Plot 4
## Cohort Stickiness
######################################################
## Snapshot
voters_spl_sn <- tapply(snap_votes$voter,snap_votes$prop_id,function(x) unique(x))
users_old <- character()
cohort_mat_sn <- matrix(NA,nrow=length(voters_spl_sn),ncol=length(voters_spl_sn))
for(idx in 1:length(voters_spl_sn))
{
	cusers <- voters_spl_sn[[idx]]
	cdusers <- cusers[cusers %in% del_list]
	nusers <- cdusers[!(cdusers %in% users_old)]
	for(jdx in idx:length(voters_spl_sn))
	{
		cohort_mat_sn[idx,jdx] <- sum(nusers %in% voters_spl_sn[[jdx]][voters_spl_sn[[jdx]] %in% del_list])/length(nusers)
	}
	users_old <- unique(c(users_old,cdusers))
	message(idx)
}
cohort_mat_sn[is.nan(cohort_mat_sn)] <- 0
cohort_mat_sn[is.na(cohort_mat_sn)] <- 0
cohort_mat_sn <- cohort_mat_sn*100
cohort_mat_sn_melted <- melt(cohort_mat_sn)
readr::write_csv(as.data.frame(cohort_mat_sn),"~/Downloads/Cohort Stickiness Matrix Snapshot Delegate.csv")


## Tally
voters_spl_tal <- tapply(tally_votes$voter,tally_votes$id,function(x) unique(x))
users_old <- character()
cohort_mat_tal <- matrix(NA,nrow=length(voters_spl_tal),ncol=length(voters_spl_tal))
for(idx in 1:length(voters_spl_tal))
{
	cusers <- voters_spl_tal[[idx]]
	cdusers <- cusers[cusers %in% del_list]
	nusers <- cdusers[!(cdusers %in% users_old)]
	for(jdx in idx:length(voters_spl_tal))
	{
		cohort_mat_tal[idx,jdx] <- sum(nusers %in% voters_spl_tal[[jdx]][voters_spl_tal[[jdx]] %in% del_list])/length(nusers)
	}
	users_old <- unique(c(users_old,cdusers))
	message(idx)
}
cohort_mat_tal[is.nan(cohort_mat_tal)] <- 0
cohort_mat_tal[is.na(cohort_mat_tal)] <- 0
cohort_mat_tal <- cohort_mat_tal*100
cohort_mat_tal_melted <- melt(cohort_mat_tal)
readr::write_csv(as.data.frame(cohort_mat_tal),"~/Downloads/Cohort Stickiness Matrix Tally Delegate.csv.csv")
p4b <- ggplot(cohort_mat_tal_melted, aes(x=Var1, y=Var2, fill=value)) + 
		geom_tile() +
		scale_alpha(range = c(0.5, 1)) +
		theme_ipsum() + 
		xlab("")+
		xlab("")+
		scale_y_continuous(trans = "reverse")
######################################################
######################################################


######################################################
## Plot 7
## Votes over time
######################################################
vote_times <- c(format(as_datetime(snap_votes$created[snap_votes$voter %in% del_list]),"%H"),format(as_datetime(tally_votes$block[tally_votes$voter %in% del_list]),"%H"))
vote_timesdf <- data.frame(Hour=names(table(vote_times)),Count=as.numeric(table(vote_times)))
p7 <- ggplot(vote_timesdf, aes(x=Hour, y=Count)) + 
  		geom_bar(stat = "identity")+
  		theme_ipsum() +
		xlab("")+
		ylab("Number of Votes")+
		ggtitle("Voting by time of the day") +
		ylim(0,4000)
ggsave("~/Downloads/p7Delegate.jpg",p7,width=8,height=6)
vote_times <- c(format(as_datetime(snap_votes$created[snap_votes$voter %in% del_list]),"%A"),format(as_datetime(tally_votes$block[tally_votes$voter %in% del_list]),"%A"))
vote_timesdf <- data.frame(Weekday=names(table(vote_times)),Count=as.numeric(table(vote_times)))
vote_timesdf$Weekday <- factor(vote_timesdf$Weekday,levels=weekdays(Sys.Date()+1:7))
p7w <- ggplot(vote_timesdf, aes(x=Weekday, y=Count)) + 
  		geom_bar(stat = "identity")+
  		theme_ipsum() +
		xlab("")+
		ylab("Number of Votes")+
		ggtitle("Voting by Weekday") +
		ylim(0,15000)
ggsave("~/Downloads/p7wDelegate.jpg",p7w,width=8,height=6)
######################################################
######################################################







