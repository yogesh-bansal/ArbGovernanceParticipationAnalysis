## Load Libraries
library(ggplot2)
library(lubridate)
library(hrbrthemes)
library(reshape2)
library(scales)

## Load Data
snap_props <- readRDS("ArbSnapshotData/Proposals.RDS")
snap_votes <- readRDS("ArbSnapshotData/Votes.RDS")
tally_props <- readRDS("ArbTallyData/Proposals.RDS")
tally_votes <- readRDS("ArbTallyData/Votes.RDS")
del_data <- readRDS("ArbTallyData/delegatesdf.RDS")

######################################################
## Plot 1
## Growth in proposals over time
######################################################
st_dt <- min(min(as_date(as_datetime(snap_props$created))),min(as_date(as_datetime(tally_props$block))))
en_dt <- max(max(as_date(as_datetime(snap_props$created))),max(as_date(as_datetime(tally_props$block))))
dateran <- seq(from=st_dt,to=en_dt,by = "day")
prop_gdf_sn <- data.frame(Date = dateran, Platform="Snapshot", NumProposals = sapply(dateran,function(x,tdata) sum(tdata<=x),tdata=as_date(as_datetime(snap_props$created))))
prop_gdf_tal <- data.frame(Date = dateran, Platform="Tally", NumProposals = sapply(dateran,function(x,tdata) sum(tdata<=x),tdata=as_date(as_datetime(tally_props$block))))
prop_gdf <- rbind(prop_gdf_sn,prop_gdf_tal)
p1 <- ggplot(prop_gdf, aes(x=Date, y=NumProposals,group=Platform,color=Platform)) +
		geom_line() + 
		theme_ipsum() +
		xlab("")+
		ylab("Number of Proposals")+
		ggtitle("Number of Proposals over Time") +
		ylim(0,160)
ggsave("~/Downloads/p1.jpg",p1,width=10,height=6)
######################################################
######################################################

######################################################
## Plot 2
## Unique Voters over time
######################################################
## Snapshot
votes_gdf_sn <- data.frame(
							DateTime = as_datetime(snap_props$created),
							Platform = "Snapshot",
							Votes = snap_props$votes
				)
votes_gdf_tal <- data.frame(
							DateTime = as_datetime(tally_props$block),
							Platform = "Tally",
							Votes = sapply(tally_props$id,function(x,tdata) length(unique(tally_votes$voter[tally_votes$id==x])),tdata=tally_votes)
				)
votes_gdf_tal <- votes_gdf_tal[order(votes_gdf_tal$DateTime),]
votes_gdf <- rbind(votes_gdf_sn,votes_gdf_tal)
rownames(votes_gdf) <- NULL
p2 <- ggplot(votes_gdf, aes(x=DateTime, y=Votes,group=Platform,color=Platform)) +
		geom_line() + 
		theme_ipsum() +
		xlab("")+
		ylab("Number of Voters")+
		ggtitle("Number of Unique Voters on Proposals over Time") +
		ylim(0,60000)
ggsave("~/Downloads/p2.jpg",p2,width=10,height=6)
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
	users_new_sn$PastUsers[idx] <- sum(cusers%in%users_old)
	users_new_sn$NewUsers[idx] <- length(cusers) - users_new_sn$PastUsers[idx]
	users_old <- unique(c(users_old,cusers))
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
	users_new_tal$PastUsers[idx] <- sum(cusers%in%users_old)
	users_new_tal$NewUsers[idx] <- length(cusers) - users_new_tal$PastUsers[idx]
	users_old <- unique(c(users_old,cusers))
	message(idx)
}
users_new <- rbind(users_new_sn,users_new_tal)
users_newlong <- rbind(
						cbind(users_new[,1:3],Type="Previous Voters",Users=users_new$PastUsers),
						cbind(users_new[,1:3],Type="New Voters",Users=users_new$NewUsers)
					)
p3 <- ggplot(users_newlong, aes(x=DateTime, y=Users, fill=Type)) + 
		geom_area(alpha=0.6 , size=.5, colour="white") +
		theme_ipsum() + 
		xlab("")+
		ylab("Number of Voters")+
		ggtitle("Number of New voters vs Existing voters over Time")+
		facet_wrap(~Platform)
ggsave("~/Downloads/p3.jpg",p3,width=12,height=6)
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
	nusers <- cusers[!(cusers %in% users_old)]
	for(jdx in idx:length(voters_spl_sn))
	{
		cohort_mat_sn[idx,jdx] <- sum(nusers %in% voters_spl_sn[[jdx]])/length(nusers)
	}
	users_old <- unique(c(users_old,cusers))
	message(idx)
}
cohort_mat_sn[is.nan(cohort_mat_sn)] <- 0
cohort_mat_sn[is.na(cohort_mat_sn)] <- 0
cohort_mat_sn <- cohort_mat_sn*100
cohort_mat_sn_melted <- melt(cohort_mat_sn)
readr::write_csv(as.data.frame(cohort_mat_sn),"~/Downloads/Cohort Stickiness Matrix Snapshot.csv")


## Tally
voters_spl_tal <- tapply(tally_votes$voter,tally_votes$id,function(x) unique(x))
users_old <- character()
cohort_mat_tal <- matrix(NA,nrow=length(voters_spl_tal),ncol=length(voters_spl_tal))
for(idx in 1:length(voters_spl_tal))
{
	cusers <- voters_spl_tal[[idx]]
	nusers <- cusers[!(cusers %in% users_old)]
	for(jdx in idx:length(voters_spl_tal))
	{
		cohort_mat_tal[idx,jdx] <- sum(nusers %in% voters_spl_tal[[jdx]])/length(nusers)
	}
	users_old <- unique(c(users_old,cusers))
	message(idx)
}
cohort_mat_tal[is.nan(cohort_mat_tal)] <- 0
cohort_mat_tal[is.na(cohort_mat_tal)] <- 0
cohort_mat_tal <- cohort_mat_tal*100
cohort_mat_tal_melted <- melt(cohort_mat_tal)
readr::write_csv(as.data.frame(cohort_mat_tal),"~/Downloads/Cohort Stickiness Matrix Tally.csv")
# p4b <- ggplot(cohort_mat_tal_melted, aes(x=Var1, y=Var2, fill=value)) + 
# 		geom_tile() +
# 		scale_alpha(range = c(0.5, 1)) +
# 		theme_ipsum() + 
# 		xlab("")+
# 		xlab("")+
# 		scale_y_continuous(trans = "reverse")
######################################################
######################################################


######################################################
## Plot 5
## Voting Power over time
######################################################
## Snapshot
vp_gdf_sn <- data.frame(
							DateTime = as_datetime(snap_props$created),
							Platform = "Snapshot",
							Votes = sapply(strsplit(snap_props$scores,"<\\|\\|>"),function(x) sum(as.numeric(x)))
				)
vp_gdf_tal <- data.frame(
							DateTime = as_datetime(tally_props$block),
							Platform = "Tally",
							Votes = sapply(tally_props$id,function(x,tdata) sum(as.numeric(tally_votes$weight[tally_votes$id==x])),tdata=tally_votes)/10^18
				)
vp_gdf_tal <- vp_gdf_tal[order(vp_gdf_tal$DateTime),]
vp_gdf <- rbind(vp_gdf_sn,vp_gdf_tal)
rownames(vp_gdf) <- NULL
p5 <- ggplot(vp_gdf, aes(x=DateTime, y=Votes,group=Platform,color=Platform)) +
		geom_line() + 
		theme_ipsum() +
		xlab("")+
		ylab("Voting Power")+
		ggtitle("Voting Power on proposals over Time") +
		ylim(0,1000000000)+
		scale_y_continuous(labels = unit_format(unit = "M", scale = 1e-6))
ggsave("~/Downloads/p5.jpg",p5,width=10,height=6)
######################################################
######################################################


######################################################
## Plot 6
## Publisher Proposal Count
######################################################
proposer_df <- data.frame(Proposer = unique(c(snap_props$author,tally_props$proposer)))
A_match <- del_data$Name[match(proposer_df$Proposer,del_data$Address)]
proposer_df$Name <- ifelse(is.na(A_match) | A_match=="",proposer_df$Proposer,A_match)
proposer_df$Name <- del_data$Name[match(proposer_df$Proposer,del_data$Address)]
proposer_df$SnapShotProposals = sapply(proposer_df$Proposer,function(x,dat) sum(dat==x),dat=snap_props$author)
proposer_df$TallyProposals = sapply(proposer_df$Proposer,function(x,dat) sum(dat==x),dat=tally_props$proposer)
readr::write_csv(proposer_df,"~/Downloads/proposer_df.csv")
######################################################
######################################################


######################################################
## Plot 7
## Votes over time
######################################################
vote_times <- c(format(as_datetime(snap_votes$created),"%H"),format(as_datetime(tally_votes$block),"%H"))
vote_timesdf <- data.frame(Hour=names(table(vote_times)),Count=as.numeric(table(vote_times)))
p7 <- ggplot(vote_timesdf, aes(x=Hour, y=Count)) + 
  		geom_bar(stat = "identity")+
  		theme_ipsum() +
		xlab("")+
		ylab("Number of Votes")+
		ggtitle("Voting by time of the day") +
		ylim(0,300000)
ggsave("~/Downloads/p7.jpg",p7,width=8,height=6)
vote_times <- c(format(as_datetime(snap_votes$created),"%A"),format(as_datetime(tally_votes$block),"%A"))
vote_timesdf <- data.frame(Weekday=names(table(vote_times)),Count=as.numeric(table(vote_times)))
vote_timesdf$Weekday <- factor(vote_timesdf$Weekday,levels=weekdays(Sys.Date()+1:7))
p7w <- ggplot(vote_timesdf, aes(x=Weekday, y=Count)) + 
  		geom_bar(stat = "identity")+
  		theme_ipsum() +
		xlab("")+
		ylab("Number of Votes")+
		ggtitle("Voting by Weekday") +
		ylim(0,750000)
ggsave("~/Downloads/p7w.jpg",p7w,width=8,height=6)
######################################################
######################################################







