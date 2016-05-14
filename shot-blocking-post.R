## install devtools if you do not already have it
install.packages("devtools")

## factors are the devil
options(stringsAsFactors=FALSE)

## install a dev branch of the package with devtools
devtools::install_github("stattleship/stattleship-r", ref="helpers")

## load the packages
library(stattleshipR)
library(dplyr)
library(plotly)

## set the token
TOKEN <-Sys.getenv("STATTLE_TOKEN")
set_token(TOKEN)

## get the regular season game logs for every team
logs_reg <- ss_team_logs(team_id="")

## and the rest for the playofs
logs_14 <- ss_team_logs(team_id="", interval_type="conferencequarterfinals")
logs_semi <- ss_team_logs(team_id="", interval_type="conferencesemifinals")

## put the data together into one dataframe
gls <- bind_rows(logs_reg, logs_14)
gls <- bind_rows(gls, logs_semi)

## keep just the columns of interest
cols <- c("team_nickname", "team_division_name", "game_interval_type","player_blocked_shots", "player_hits")
gls <- ss_keep_cols(gls, cols)

## create a regular seasons/playoff flag
gls <- transform(gls, game_type = ifelse(game_interval_type=="regularseason", "regular", "playoffs"))

## A look at the data
glimpse(gls)

## summarize the data into 1 row per team
gls_agg <- gls %>% 
  group_by(team_nickname, team_division_name) %>% 
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

## another look
glimpse(gls_agg)

## plot the distributions of blocks per game by regular season and playoffs
plot_ly(x = gls_agg$bpg_reg, opacity = 0.66, type = "histogram", name="Regular Season") %>%
  add_trace(x = gls_agg$bpg_post, type="histogram", opacity=.55, name="Playoffs") %>%
  layout(barmode="overlay", 
         bargap = .25,
         title="2015-16 NHL Shot Blocks Per Game",
         xaxis = list(title="Blocks Per Game"))

## isolate playoff teams and then a simple distribution
gls_post <- filter(gls_agg, games_post > 0)
gls_post %>% plot_ly(x = bpg_diff, opacity=.66, type="histogram", name="Delta") %>% 
  layout(bargap = .25, xaxis = list(title="Difference"), title="Difference in Blocks Per Game")

## normality test
shapiro.test(gls_post$bpg_diff)

## 1-sample t-test
t.test(gls_post$bpg_diff, mu = 0)

## Regular season blocks per game by team dvision
gls_agg %>% 
  plot_ly(y = bpg_reg, color = team_division_name, type="box") %>% 
  layout(title = "2015-16 Regular Season Blocks per Game by Division",
         yaxis = list(title="Blocks per Game"))

