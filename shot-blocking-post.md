
# Hockey Shot Blocking with R and the Stattleship API




The other day, the Yhat blog posted a nice [article](http://blog.yhat.com/posts/hockey-shot-blocking.html) on shot blocking in the NHL, with emphasis on the differences that may occur between the regular season and the playoffs.  The author Ross demonstrated how to collect the data from NHL website by parsing the data using python.

At Stattleship, we have an API that makes it simple to get at the same data.  While we currently only include this season's data for the NHL, the API will consistently and reliably return these data for you; no need to worry about changing webpages!

Below we will use our R package [stattleshipR](https://github.com/stattleship/stattleship-r) to work with the API and replicate the Yhat post.  This post will work through the various code samples, but the full script is included in the Appendix at the end.

## Before you Begin

Before you begin, you will need an API token. If you do not have one already, you can go [here](https://www.stattleship.com/#) to get access.  

Assuming that have you R installed, you will need the `devools` package to install our R package, as it is not currently yet on CRAN.  


```r
install.packages("devtools")
```

That's it!

## Getting Started

Below we are going to setup our R session to ensure we are good to go.


```r
## factors are the devil
options(stringsAsFactors=FALSE)

## install a dev branch of the package with devtools
devtools::install_github("stattleship/stattleship-r", ref="helpers")

## load the packages
library(stattleshipR)
library(dplyr)
library(plotly)
```

Above, we disable the default behavior of R to treat strings as factors.  Beyond that, we are installing a development version our package. This is using a sneak peak at a number of functions that make it even easier to use the API.  Lastly, because the Yhat used [plotly](https://plot.ly/), we are loading up the equivalent R package.

Now initalize your API token. I am using an environment variable on my machine, but you could just as easily set it via `TOKEN <- "your_token_here"`.


```r
TOKEN <-Sys.getenv("STATTLE_TOKEN") 
set_token(TOKEN)
```

From here, the call below will get the game logs for each team in the __regular season__ using the `team_game_logs` endpoint.  For more information on how to use the API and to get a sense of what is available, check out our [developers reference](http://developers.stattleship.com/).

The call below will automatically page through the results of the API.






```r
logs_reg <- ss_team_logs(team_id="")
```

It will take a minute or so to get the results, but yes, it's that easy.  To understand the defaults used in the function above, take a look at our documentation using `?ss_team_logs`.  

The object `logs_reg` is a data.frame and has 2460 rows and 146 of data!  

Below we will get the data from the first two rounds of the playoffs to round out the data that we need.


```r
logs_14 <- ss_team_logs(team_id="", interval_type="conferencequarterfinals")
logs_semi <- ss_team_logs(team_id="", interval_type="conferencesemifinals")
```

Above we needed to specifiy an additional parameter in our call to the API.  For more information on how the API uses `interval_type`, check out the [documentation here](http://developers.stattleship.com/#interval-types).

We now have the core data that we need to analyze blocked shots, but like any data analysis project, we need to do some simple cleanup.



```r
## put the data together into one dataframe
gls <- bind_rows(logs_reg, logs_14)
gls <- bind_rows(gls, logs_semi)

## keep just the columns of interest
cols <- c("team_nickname", "team_division_name", "game_interval_type","player_blocked_shots", "player_hits")
gls <- ss_keep_cols(gls, cols)
```

Last but not least, to mirror the Yhat post, I am going to segment the data by regular season and the playoffs, instead of itemizing the post season by `interval_type`.


```r
## create a regular seasons/playoff flag
gls <- transform(gls, game_type = ifelse(game_interval_type=="regularseason", "regular", "playoffs"))
```

A quick look into what we have to ensure it's what we need to dive into the analysis


```r
glimpse(gls)
```

```
Observations: 2,604
Variables: 6
$ team_nickname        (chr) "Sharks", "Flames", "Senators", "Panthers...
$ team_division_name   (chr) "Pacific", "Pacific", "Atlantic", "Atlant...
$ game_interval_type   (chr) "regularseason", "regularseason", "regula...
$ player_blocked_shots (int) 16, 15, 14, 25, 6, 15, 17, 5, 16, 18, 7, ...
$ player_hits          (int) 8, 14, 30, 30, 35, 26, 9, 16, 21, 25, 22,...
$ game_type            (chr) "regular", "regular", "regular", "regular...
```

Looks good, but right now the there is one row for every team by `interval_type`, and in the Yhat post, the data were captured as 1 row per team.  Aggregating the data using `dplyr` is a breeze.


```r
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
```

Above we grouping the data by team info, isolating games played, hits, and blocks for both the regular season and postseason. 

Another quick look look at the data


```r
glimpse(gls_agg)
```

```
Observations: 30
Variables: 14
$ team_nickname      (chr) "Avalanche", "Blackhawks", "Blue Jackets", ...
$ team_division_name (chr) "Central", "Central", "Metropolitan", "Cent...
$ games_reg          (dbl) 82, 82, 82, 82, 82, 82, 82, 82, 82, 82, 82,...
$ hits_reg           (dbl) 1848, 1389, 2145, 1937, 2164, 1932, 1533, 1...
$ blocks_reg         (dbl) 1401, 1133, 1260, 1127, 1184, 1144, 1058, 1...
$ games_post         (dbl) 0, 7, 0, 14, 0, 0, 0, 12, 0, 0, 7, 0, 6, 0,...
$ hits_post          (dbl) 0, 206, 0, 493, 0, 0, 0, 432, 0, 0, 223, 0,...
$ blocks_post        (dbl) 0, 109, 0, 224, 0, 0, 0, 194, 0, 0, 104, 0,...
$ bpg_reg            (dbl) 17.08537, 13.81707, 15.36585, 13.74390, 14....
$ hpg_reg            (dbl) 22.53659, 16.93902, 26.15854, 23.62195, 26....
$ bpg_post           (dbl) NA, 15.57143, NA, 16.00000, NaN, NaN, NaN, ...
$ hpg_post           (dbl) NA, 29.42857, NA, 35.21429, NaN, NaN, NaN, ...
$ bpg_diff           (dbl) NA, 1.7543554, NA, 2.2560976, NaN, NaN, NaN...
$ hpg_diff           (dbl) NA, 12.489547, NA, 11.592334, NaN, NaN, NaN...
```

We can see that some team's have `NaN` for some of columns.  This is because they didn't make the posteason.

## Plotting

In the post, the author compares the distributions of blocks per game in the regular season and the playoffs. 


```r
plot_ly(x = gls_agg$bpg_reg, opacity = 0.66, type = "histogram", name="Regular Season") %>%
  add_trace(x = gls_agg$bpg_post, type="histogram", opacity=.55, name="Playoffs") %>%
  layout(barmode="overlay", 
         bargap = .25,
         title="2015-16 NHL Shot Blocks Per Game",
         xaxis = list(title="Blocks Per Game"))
```

<!--html_preserve--><div id="htmlwidget-2199" style="width:672px;height:480px;" class="plotly"></div>
<script type="application/json" data-for="htmlwidget-2199">{"x":{"data":[{"type":"histogram","inherit":false,"x":[17.0853658536585,13.8170731707317,15.3658536585366,13.7439024390244,14.4390243902439,13.9512195121951,12.9024390243902,15.4390243902439,14.0243902439024,12.8536585365854,14.3658536585366,16.0975609756098,15.9634146341463,11.9512195121951,16.1219512195122,13.8170731707317,12.5243902439024,12.5243902439024,12.6219512195122,15.0365853658537,11.4878048780488,13.3048780487805,15.0243902439024,16.0243902439024,11.0853658536585,13.3536585365854,14.5853658536585,15.7560975609756,14.9268292682927,14.7439024390244],"opacity":0.66,"name":"Regular Season"},{"x":[null,15.5714285714286,null,16,null,null,null,16.1666666666667,null,null,14.8571428571429,null,20.8333333333333,null,17.0909090909091,null,16.6,14.2,null,null,13.6666666666667,18.2727272727273,18.4285714285714,14.2,12.4,null,null,22.6666666666667,14.8461538461538,22.8333333333333],"type":"histogram","opacity":0.55,"name":"Playoffs"}],"layout":{"barmode":"overlay","bargap":0.25,"title":"2015-16 NHL Shot Blocks Per Game","xaxis":{"title":"Blocks Per Game"},"margin":{"b":40,"l":60,"t":25,"r":10}},"url":null,"width":null,"height":null,"source":"A","config":{"modeBarButtonsToRemove":["sendDataToCloud"]},"base_url":"https://plot.ly"},"evals":[]}</script><!--/html_preserve-->

We can see that the data for just the 2015-16 season mirror that shot blocking appears to go in the playoffs.

And the distribution of the difference in blocks per game for teams that are currently in the playoffs.


```r
## isolate playoff teams and then a simple distribution
gls_post <- filter(gls_agg, games_post > 0)
gls_post %>% plot_ly(x = bpg_diff, opacity=.66, type="histogram", name="Delta") %>% 
  layout(bargap = .25, xaxis = list(title="Difference"), title="Difference in Blocks Per Game")
```

<!--html_preserve--><div id="htmlwidget-8674" style="width:672px;height:480px;" class="plotly"></div>
<script type="application/json" data-for="htmlwidget-8674">{"x":{"data":[{"type":"histogram","inherit":false,"x":[1.75435540069686,2.25609756097561,0.727642276422765,0.491289198606273,4.86991869918699,0.968957871396896,4.07560975609756,1.67560975609756,2.17886178861789,4.96784922394679,3.40418118466899,-1.82439024390244,1.31463414634146,6.91056910569106,-0.080675422138837,8.08943089430894],"opacity":0.66,"name":"Delta"}],"layout":{"bargap":0.25,"xaxis":{"title":"Difference"},"title":"Difference in Blocks Per Game","margin":{"b":40,"l":60,"t":25,"r":10}},"url":null,"width":null,"height":null,"source":"A","config":{"modeBarButtonsToRemove":["sendDataToCloud"]},"base_url":"https://plot.ly"},"evals":[]}</script><!--/html_preserve-->


A test for normality and 1-sample t-test ...


```r
## normality test
shapiro.test(gls_post$bpg_diff)
```

```

	Shapiro-Wilk normality test

data:  gls_post$bpg_diff
W = 0.95895, p-value = 0.6428
```

```r
## 1-sample t-test
t.test(gls_post$bpg_diff, mu = 0)
```

```

	One Sample t-test

data:  gls_post$bpg_diff
t = 3.9824, df = 15, p-value = 0.001202
alternative hypothesis: true mean is not equal to 0
95 percent confidence interval:
 1.213646 4.008847
sample estimates:
mean of x 
 2.611246 
```

Last but not least, because we only have the current season available, instead of using boxplots to look at the distribution of blocks per game over a set of seasons, below we are isolating the differences by division instead.


```r
gls_agg %>% 
  plot_ly(y = bpg_reg, color = team_division_name, type="box") %>% 
  layout(title = "2015-16 Regular Season Blocks per Game by Division",
         yaxis = list(title="Blocks per Game"))
```

<!--html_preserve--><div id="htmlwidget-6683" style="width:672px;height:480px;" class="plotly"></div>
<script type="application/json" data-for="htmlwidget-6683">{"x":{"data":[{"type":"box","inherit":false,"y":[17.0853658536585,13.8170731707317,13.7439024390244,13.8170731707317,15.0243902439024,14.9268292682927,14.7439024390244],"name":"Central","marker":{"color":"#66C2A5"}},{"type":"box","inherit":false,"y":[15.3658536585366,15.4390243902439,12.8536585365854,15.9634146341463,11.9512195121951,16.1219512195122,13.3048780487805,16.0243902439024],"name":"Metropolitan","marker":{"color":"#FC8D62"}},{"type":"box","inherit":false,"y":[14.4390243902439,13.9512195121951,12.5243902439024,12.6219512195122,11.4878048780488,11.0853658536585,13.3536585365854,14.5853658536585],"name":"Atlantic","marker":{"color":"#8DA0CB"}},{"type":"box","inherit":false,"y":[12.9024390243902,14.0243902439024,14.3658536585366,16.0975609756098,12.5243902439024,15.0365853658537,15.7560975609756],"name":"Pacific","marker":{"color":"#E78AC3"}}],"layout":{"title":"2015-16 Regular Season Blocks per Game by Division","yaxis":{"title":"Blocks per Game"},"margin":{"b":40,"l":60,"t":25,"r":10}},"url":null,"width":null,"height":null,"source":"A","config":{"modeBarButtonsToRemove":["sendDataToCloud"]},"base_url":"https://plot.ly"},"evals":[]}</script><!--/html_preserve-->


## Appendix

The code as one script


```r
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
```

