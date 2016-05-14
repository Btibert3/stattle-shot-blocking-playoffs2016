###############################################################################
## Mirror the data in the post below using the Stattleship API
## http://blog.yhat.com/posts/hockey-shot-blocking.html
##
## @brocktibert
###############################################################################

## factors are the devil
options(stringsAsFactors=FALSE)

## install a dev branch of the package with devtools
devtools::install_github("stattleship/stattleship-r", ref="helpers")

## load the packages
library(stattleshipR)
library(dplyr)
library(plotly)

## set the token for the API
## get yours here: https://www.stattleship.com/
TOKEN <-Sys.getenv("STATTLE_TOKEN") ## I am using an environment variable
set_token(TOKEN)

## get the regular season gamelogs: check the defaults: this will grab all teams
logs_reg <- ss_team_logs(team_id="")

## get the postseason logs
logs_14 <- ss_team_logs(team_id="", interval_type="conferencequarterfinals")
logs_semi <- ss_team_logs(team_id="", interval_type="conferencesemifinals")

## put the data together
gls <- bind_rows(logs_reg, logs_14)
gls <- bind_rows(gls, logs_semi)

## keep the columns of interest
# cols <- c("team_nickname","team_outcome","team_score","opponent_score","is_home_team",
#          "player_blocked_shots", "player_hits","game_interval_type","game_attendance",
#          "game_venue_capacity")
cols <- c("team_nickname","game_interval_type","player_blocked_shots", "player_hits")
gls <- ss_keep_cols(gls, cols)

## create a regular seasons/playoff flag
gls <- transform(gls, game_type = ifelse(game_interval_type=="regularseason", "regular", "playoffs"))

## rollup the data by team ans season
# gls_agg <- gls %>% 
#   group_by(team_nickname, game_type) %>% 
#   summarise(num_games = n(),
#             hits = sum(player_hits),
#             blocks = sum(player_blocked_shots)) %>% 
#   mutate(blocks_game = blocks/num_games,
#          hits_game = hits/num_games)
# 

## rollup the data into 1 row per team with columns by season type
gls_agg <- gls %>% 
  group_by(team_nickname) %>% 
  summarise(games_reg = sum(ifelse(game_type=="regular", 1, 0)),
            hits_reg = sum(ifelse(game_type=="regular", player_hits, 0)),
            blocks_reg = sum(ifelse(game_type=="regular", player_blocked_shots, 0)),
            games_post = sum(ifelse(game_type=="playoffs", 1, 0)),
            hits_post = sum(ifelse(game_type=="playoffs", player_hits, 0)),
            blocks_post = sum(ifelse(game_type=="playoffs", player_blocked_shots, 0))) %>% 
  mutate(bpg_reg = blocks_reg/games_reg,
         hpg_reg = hits_reg/games_reg,
         bpg_post = blocks_post/games_post,
         hpg_post = hits_post/games_post,
         bpg_diff = bpg_post - bpg_reg,
         hpg_diff = hpg_post - hpg_reg)

## save the data
rm(TOKEN)  ## dont want to publish my token
save.image(file="shot-blocking-post.Rdata")


############################ just playing around with plotly for the first time

## keep just the teams in the playoffs (at least one round)
gls_post <- filter(gls_agg, games_post > 0)

## plot the scatter plot of hit and block differences
plot_ly(gls_post, x=hpg_diff, y=bpg_diff, mode="markers", text=team_nickname)

## ^^ isn't great (I am new)  2d histogram
plot_ly(x = gls_post$hpg_diff, y = gls_post$bpg_diff, type = "histogram2d")

## start of overlay historgram
plot_ly(x = gls_agg$bpg_reg, opacity = 0.66, type = "histogram") %>%
  add_trace(x = gls_agg$bpg_post, type="histogram", opacity=.66) %>%
  layout(barmode="overlay")


  